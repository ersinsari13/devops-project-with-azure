terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.24.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
resource "aws_instance" "tf-jenkins-server" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.mykey
  vpc_security_group_ids = [aws_security_group.tf-jenkins-sec-gr.id]
  iam_instance_profile = aws_iam_instance_profile.tf-jenkins-server-profile.name
  root_block_device {
    volume_size = 16
  }
  tags = {
    Name = var.jenkins-server-tag
    server = "Jenkins"
  }
  user_data = file("jenkinsdata.sh")
}

resource "aws_security_group" "tf-jenkins-sec-gr" {
  name = var.jenkins_server_secgr
  tags = {
    Name = var.jenkins_server_secgr
  }

  dynamic "ingress" {
    for_each = [80,22,8080]
    iterator = port
    content {
    from_port   = port.value
    protocol    = "tcp"
    to_port     = port.value
    cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_iam_role" "tf-jenkins-server-role" {
  name = var.jenkins-role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess", "arn:aws:iam::aws:policy/AdministratorAccess"]
}

resource "aws_iam_instance_profile" "tf-jenkins-server-profile" {
  name = var.jenkins-profile
  role = aws_iam_role.tf-jenkins-server-role.name
}
output "JenkinsDNS" {
    value = aws_instance.tf-jenkins-server.public_dns
}
output "JenkinsURL" {
  value = "http://${aws_instance.tf-jenkins-server.public_dns}:8080"
}