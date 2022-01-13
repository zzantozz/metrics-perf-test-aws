terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    User = "Ryan"
    Environment = "Metrics playground"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.0.0/24"
  tags = {
    User = "Ryan"
    Environment = "Metrics playground"
  }
}

resource "aws_internet_gateway" "main_vpc_internet_gateway" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    User = "Ryan"
    Environment = "Metrics playground"
  }
}

resource "aws_default_route_table" "main_vpc_route_table" {
  default_route_table_id = aws_vpc.main_vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_vpc_internet_gateway.id
  }
  tags = {
    User = "Ryan"
    Environment = "Metrics playground"
  }
}

resource "aws_security_group" "main_vpc_security_group" {
  description = "Main security group for test metrics playground"
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    User = "Ryan"
    Environment = "Metrics playground"
  }
}

# According to https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group the security
# group resource supports nested ingress and egress blocks, but when I tried, terraform said it created them, but they
# didn't show up in AWS.
resource "aws_security_group_rule" "main_sg_icmp_from_home" {
  description = "ICMP from home"
  type = "ingress"
  security_group_id = aws_security_group.main_vpc_security_group.id
  protocol = "icmp"
  from_port = -1
  to_port = -1
  cidr_blocks = [
    "70.123.226.90/32"
  ]
}

resource "aws_security_group_rule" "main_sg_ssh_from_home" {
  description = "SSH from home"
  type = "ingress"
  security_group_id = aws_security_group.main_vpc_security_group.id
  protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_blocks = [
    "70.123.226.90/32"
  ]
}

data "aws_ami" "amazon-linux-ami" {
  most_recent = true
  filter {
    name = "name"
    values = [
      "amzn2-ami-hvm-*-x86_64-gp2"
    ]
  }
  owners = [
    "137112412989"
  ]
}

resource "aws_instance" "first_instance" {
  ami = data.aws_ami.amazon-linux-ami.id
  instance_type = "t2.micro"
  key_name = "ryan-metrics-playground-keypair"
  subnet_id = aws_subnet.main_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.main_vpc_security_group.id
  ]
  tags = {
    User = "Ryan"
    Environment = "Metrics playground"
  }
}

output "instance_public_ip" {
  value = aws_instance.first_instance.public_ip
}
