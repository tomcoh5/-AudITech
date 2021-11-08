
pipeline {
    environment {
        registryCredential = 'jenkins_user_in_aws'
        registry_master = "" 
        registry_slave = "" 
        dockerImageMaster = "${registry_master}:$BUILD_NUMBER"  
        dockerImageSlave = "${registry_slave}:$BUILD_NUMBER" 

    }
    agent any
    stages {
        stage('Git clone') {
            steps {
                git branch: 'main', credentialsId: 'github_user', url: 'git-repo'
            }
        } 
        stage('Building dockerfile') {
            steps {
                echo "Building docker images"
                    script {
                        dockerImageMaster = docker.build registry_master + ":$BUILD_NUMBER" 
                }
            }
        }
        stage('running dockerimage in a container') {
            steps {
                echo "docker run -d -p 80:80 $registry_slave:$BUILD_NUMBER"
                echo "sleep for 10 seconds (waiting untill docker containers are built)"
                sh 'sleep 10'
            }
        }
        stage ('Testing Connection to websites') {
            steps {
                echo "Testing connection for app"
                sh 'curl localhost:80'"
                sh 'docker rm -f $registry_slave:$BUILD_NUMBER'
            }
        } 
        stage('Uploading to ECR (AWS)') {
            steps {
                script{
                    docker.withRegistry("https://" + registry_master, "ecr:eu-west-2:" + registryCredential) {
                        dockerImageMaster.push()
                    }
                }
            }
        }
        stage ("Deployment to ECS (AWS)") {
            steps {
                sh """aws ecs update-service --cluster <your-cluster-name> --service <your-service-name> --force-new-deployment --region eu-west-2 """
            }
        }
    }
    post {
        always {
            sh 'docker-compose down'
            sh 'docker rm -fr $registry_slave:$BUILD_NUMBER'
            sh "docker rmi $registry_slave:$BUILD_NUMBER"
            sh "docker rmi $registry_master:$BUILD_NUMBER"
        }
    }
