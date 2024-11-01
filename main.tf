# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

#Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "Webserver"
  }
}

#Deploy the private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_cidr
  availability_zone = tolist(data.aws_availability_zones.available.names)[0]
}

#Deploy secondary private subnet
resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_cidr2
  availability_zone = tolist(data.aws_availability_zones.available.names)[1]
}

#Deploy the public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_cidr
  availability_zone       = tolist(data.aws_availability_zones.available.names)[0]
  map_public_ip_on_launch = true
}

#Deploy secondary public subnet
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_cidr2
  availability_zone       = tolist(data.aws_availability_zones.available.names)[1]
  map_public_ip_on_launch = true
}

#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  route {
    cidr_block = var.vpc_cidr
    gateway_id = "local"
  }
  tags = {
    Name = "public_rtb"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.vpc_cidr
    gateway_id = "local"
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "private_rtb"
  }
}

#Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnet]
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

# Create route table association for the second public subnet
resource "aws_route_table_association" "public_subnet2" {
  depends_on     = [aws_subnet.public_subnet2]
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet2.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnet]
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "igw_eip"
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.public_subnet]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "nat_gateway"
  }
}

# Terraform Data Block - To Lookup Wordpress AMI Image
data "aws_ami" "wordpress" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-wordpresspro-6.6.2-5-r05-linux-debian-12-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"]
}

# code to generate RSA key using the  TLS provider
resource "tls_private_key" "generated" {
  algorithm = "RSA"
}

# Code to copy whatever the resource "tls_private_key.generated" generated then copy it to a file locally on the machine
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "WebserverKey.pem"
}

# To generate a key pair in AWS and generate the public key using the private key above
resource "aws_key_pair" "generated" {
  key_name   = "WebserverKey.pem"
  public_key = tls_private_key.generated.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]
  }
}

# ALB security group
resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "Allow traffic to ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB Security Group"
  }
}


# Webserver security group
resource "aws_security_group" "webserver" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  depends_on  = [aws_security_group.alb-sg]
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #security_groups = [aws_security_group.alb.id]
  }
  tags = {
    Name = "Webserver Security Group"
  }
}


#Wordpress Webserver
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.wordpress.id
  count                       = 2 #to create 2 instances
  instance_type               = "t3.small"
  subnet_id                   = count.index == 0 ? aws_subnet.private_subnet.id : aws_subnet.private_subnet2.id
  security_groups             = [aws_security_group.webserver.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.generated.key_name

  tags = {
    Name = "Webserver ${count.index + 1}"
  }

  lifecycle {
    ignore_changes = [security_groups]
  }

}

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "app-lb-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets = [aws_subnet.public_subnet.id,
  aws_subnet.public_subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "Application Load Balancer"
  }
}

# Target Group
resource "aws_lb_target_group" "alb_tg" {
  name     = "app-tg-${terraform.workspace}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "App Target Group"
  }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

# Target Group Attachment (for each instance)
resource "aws_lb_target_group_attachment" "alb_attachment" {
  count            = length(aws_instance.web_server)
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.web_server[count.index].id
  port             = 80
}
