# -----------------------------------------------------------------------------------------
# Producer Configuration
# -----------------------------------------------------------------------------------------
module "producer_vpc" {
  source                  = "./modules/vpc"
  vpc_name                = "producer-vpc"
  vpc_cidr                = "10.0.0.0/16"
  azs                     = var.azs
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = true
  map_public_ip_on_launch = true
  enable_nat_gateway      = false
  single_nat_gateway      = false
  one_nat_gateway_per_az  = false
  tags = {
    Name = "producer-vpc"
  }
}

# Producer Security Group
resource "aws_security_group" "producer_sg" {
  name   = "producer-sg"
  vpc_id = module.producer_vpc.vpc_id

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "producer-sg"
  }
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.producer_vpc.public_subnets
}

resource "aws_lb_target_group" "nlb_tg" {
  name     = "nlb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = module.producer_vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "web_a" {
  target_group_arn = aws_lb_target_group.nlb_tg.arn
  target_id        = module.provider_instance.id
  port             = 80
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

# VPC Endpoint Service
resource "aws_vpc_endpoint_service" "vpc_endpoint_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn]
}

# -----------------------------------------------------------------------------------------
# Consumer Configuration
# -----------------------------------------------------------------------------------------
module "consumer_vpc" {
  source                  = "./modules/vpc"
  vpc_name                = "consumer-vpc"
  vpc_cidr                = "10.0.0.0/16"
  azs                     = var.azs
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = true
  map_public_ip_on_launch = true
  enable_nat_gateway      = false
  single_nat_gateway      = false
  one_nat_gateway_per_az  = false
  tags = {
    Name = "consumer-vpc"
  }
}

# Security Group
resource "aws_security_group" "consumer_sg" {
  name   = "consumer-sg"
  vpc_id = module.consumer_vpc.vpc_id

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "consumer-sg"
  }
}

resource "aws_vpc_endpoint" "consumer_endpoint" {
  vpc_id              = module.consumer_vpc.vpc_id
  service_name        = aws_vpc_endpoint_service.vpc_endpoint_service.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.consumer_vpc.public_subnets
  security_group_ids  = [aws_security_group.consumer_sg.id]
  private_dns_enabled = false
}

# -----------------------------------------------------------------------------------------
# EC2 Instances
# -----------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_key_pair" "key_pair" {
  key_name = "madmaxkeypair"
}

module "provider_instance" {
  source                      = "./modules/ec2"
  name                        = "provider-instance"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.key_pair.key_name
  subnet_id                   = module.producer_vpc.public_subnets[0]
  security_groups             = [aws_security_group.producer_sg.id]
  user_data                   = filebase64("${path.module}/scripts/user_data.sh")
}

module "consumer_instance" {
  source                      = "./modules/ec2"
  name                        = "consumer-instance"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.key_pair.key_name
  subnet_id                   = module.consumer_vpc.public_subnets[0]
  security_groups             = [aws_security_group.consumer_sg.id]
}