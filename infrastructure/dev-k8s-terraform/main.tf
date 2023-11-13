terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "instance_type" {
  default     = "t3a.medium"
  description = "This is for instance type"
}

data "aws_vpc" "name" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] 
}
resource "aws_instance" "kube-master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.petclinic-master-server-profile.name
  key_name = "clarus"
  subnet_id = "subnet-0fbab223bdb5a3190"
  availability_zone = "us-east-1a"
  vpc_security_group_id = [aws_security_group.master-sec-grp.id, aws_security_group.mutual-grp.id]

  tags = {
        Name = "kube-master"
        Project = "tera-kube-ans"
        Role = "master"
        Id = "1"
        environment = "dev"
  }
}

resource "aws_instance" "worker-1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = "clarus"
  subnet_id = "subnet-0fbab223bdb5a3190"
  availability_zone = "us-east-1a"
  vpc_security_group_id = [aws_security_group.mutual-grp.id, aws_security_group.worker-sec-grp.id ]
  tags = {
        Name = "worker-1"
        Project = "tera-kube-ans"
        Role = "worker"
        Id = "1"
        environment = "dev"
  }
}

resource "aws_instance" "worker-2" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.mutual-grp.id, aws_security_group.worker-sec-grp.id ]
    key_name = "clarus"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    availability_zone = "us-east-1a"
    tags = {
        Name = "worker-2"
        Project = "tera-kube-ans"
        Role = "worker"
        Id = "2"
        environment = "dev"
    }
}

resource "aws_security_group" "mutual-grp{
  name        = "mutual_sec_grp"
  description = "kubernetes master node security group"
  vpc_id      = data.aws_vpc.name.id

  ingress {
    protocol = "tcp"
    from_port = 10250
    to_port = 10250
    self = true
  }
  ingress {
    protocol = "udp"
    from_port = 8472
    to_port = 8472
    self = true
  }
  ingress {
    protocol = "tcp"
    from_port = 2379
    to_port = 2380
    self = true
  }
}
resource "aws_security_group" "worker-sec-grp{
  name        = "worker_node_sec_grp"
  description = "kubernetes master node security group"
  vpc_id      = data.aws_vpc.name.id

  ingress {
    protocol = "tcp"
    from_port = 30000
    to_port = 32767
    self = true
  }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    self = true
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "kube-worker-sec-grp"
  }  
}

resource "aws_security_group" "master-sec-grp{
  name        = "master_node_sec_grp"
  description = "kubernetes master node security group"
  vpc_id      = data.aws_vpc.name.id

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 6443
    to_port = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 10257
    to_port = 10257
    self = true
  }

  ingress {
    protocol = "tcp"
    from_port = 10259
    to_port = 10259
    self = true
  }
  ingress {
    protocol = "tcp"
    from_port = 30000
    to_port = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kube-master-secgroup"
  }    
}

resource "aws_iam_role" "petclinic-master-server-s3-role" {
  name = "petclinic-master-server-role"

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

  tags = {
    tag-key = "tag-value"
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}

resource "aws_iam_instance_profile" "petclinic-master-server-profile" {
  name = "petclinic-master-server-profile"
  role = aws_iam_role.petclinic-master-server-s3-role.name
}

output kube-master-ip {
  value       = aws_instance.kube-master.public_ip
  sensitive   = false
  description = "public ip of the kube-master"
}

output worker-1-ip {
  value       = aws_instance.worker-1.public_ip
  sensitive   = false
  description = "public ip of the worker-1"
}

output worker-2-ip {
  value       = aws_instance.worker-2.public_ip
  sensitive   = false
  description = "public ip of the worker-2"
}