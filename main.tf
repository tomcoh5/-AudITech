provider "aws" {
    region = var.region
}

locals {
  name = "${var.name}-ecs"
}


#IAM

resource "aws_ecs_cluster" "ecs-cluster" {
    name = "${local.name}"
}

data "template_file" "task_definition" {
    file = "./resources.yml"
}

resource "aws_ecs_task_definition" "task_definition" {
  family                = "worker"
  container_definitions = data.template_file.task_definition_template.rendered
}

resource "aws_ecs_service" "mesh-ecs-service" {
  	name            = "${var.ecs-service-name}"
  	iam_role        = "${var.ecs-service-role-arn}"
  	cluster         = "${aws_ecs_cluster.ecs-cluster.id}"
  	task_definition = "${aws_ecs_task_definition.sample-definition.arn}"
  	desired_count   = 1

  	load_balancer {
    	target_group_arn  = "${var.ecs-target-group-arn}"
    	container_port    = 80
    	container_name    = "app"
	}
}




#VPC 
resource "aws_vpc" "ecs-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"
  
  tags {
    Name = "ecs-vpc"
  }
}

resource "aws_subnet" "ecs-subnet1" {
    vpc_id     = "${aws_vpc.ecs-vpc.id}"
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"

    tags {
        Name = "vpc-subnet-ecs-1"
    }
}

resource "aws_subnet" "ecs-subnet2" {
    vpc_id     = "${aws_vpc.ecs.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"

    tags {
        Name = "vpc-subnet-ecs-2"
    }
}

resource "aws_security_group" "ecs" {
    name        = "ecs-security-group"
    description = "Allow HTTP and SSH"
    vpc_id = "${aws_vpc.ecs.id}"

    // HTTP
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}



resource "aws_security_group" "lb" {
    name        = "lb-sg"
    description = "Allow HTTP, HTTPS"
    vpc_id = "${aws_vpc.ecs.id}"

    // HTTP
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#LOAD BALANCER

resource "aws_alb" "ecs-load-balancer" {
    name                = local.name
    security_groups     = [aws_security_group.lb.id]
    subnets             = [aws_subnet.ecs-subnet1.id, aws_subnet.ecs-subnet2.id,]
}

resource "aws_alb_target_group" "ecs-target_group" {
    name                = "${var.target-group-name}"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = "${var.vpc-id}"

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }
}

resource "aws_alb_listener" "alb-listener" {
    load_balancer_arn = "${aws_alb.ecs-load-balancer.arn}"
    port              = "80"
    protocol          = "HTTP"
    
    default_action {
        target_group_arn = "${aws_alb_target_group.ecs-target_group.arn}"
        type             = "forward"
    }
}



data "aws_ami" "latest_amazon_image" {
most_recent = true
owners = ["amazon"] # AWS

  filter {
      name   = "name"
      values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }  
}


resource "aws_launch_configuration" "ecs-launch-configuration" {
    name                        = local.name
    image_id                    = data.aws_ami.latest_amazon_image.id
    instance_type               = "${var.instance-type}"
    iam_instance_profile        = "${var.ecs-instance-profile-name}" 
    security_groups             = [aws_security.ecs.id]
    associate_public_ip_address = "true"
    key_name                    = "${var.ecs-key-pair-name}"
      user_data = <<EOF
    #!/bin/bash
    # The cluster this agent should check into.
    echo 'ECS_CLUSTER=${aws_ecs_cluster.main.name}' >> /etc/ecs/ecs.config
    # Disable privileged containers.
    echo 'ECS_DISABLE_PRIVILEGED=true' >> /etc/ecs/ecs.config
    EOF
}



resource "aws_autoscaling_group" "failure_analysis_ecs_asg" {
    name                      = "asg-ecs"
    vpc_zone_identifier       = [aws_subnet.ecs-subnet1.id, aws_subnet.ecs-subnet2.id,]
    launch_configuration      = aws_launch_configuration.ecs_launch_config.name

    desired_capacity          = 2
    min_size                  = 1
    max_size                  = 10
    health_check_grace_period = 300
    health_check_type         = "EC2"
}


resource "aws_ecr_repository" "app" {
    name  = "${local.name}"
}

resource "aws_ecs_cluster" "ecs-cluster" {
    name = "${local.name}"
}

resource "aws_ecs_service" "ecs-service" {
  	name            = "${local.name}"
  	iam_role        = "${var.ecs-service-role-arn}"
  	cluster         = "${aws_ecs_cluster.ecs-cluster.id}"
  	task_definition = "${aws_ecs_task_definition.sample-definition.arn}"
  	desired_count   = 1

  	load_balancer {
    	target_group_arn  = "${var.ecs-target-group-arn}"
    	container_port    = 80
    	container_name    = "app"
	}
}

