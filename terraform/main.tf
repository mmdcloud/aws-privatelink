# -----------------------------------------------------------------------------------------
# Producer Configuration
# -----------------------------------------------------------------------------------------
module "producer_vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "producer-vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "producer-vpc-igw"
}

# Producer Security Group
module "producer_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.producer_vpc.vpc_id
  name   = "producer-sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTP traffic"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Producer Public Subnets
module "producer_public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "producer-public-subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.producer_vpc.vpc_id
  map_public_ip_on_launch = true
}

# Producer Private Subnets
module "producer_private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "producer-private-subnet"
  subnets = [
    {
      subnet = "10.0.4.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.6.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.producer_vpc.vpc_id
  map_public_ip_on_launch = false
}

# Producer Public Route Table
module "producer_public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "producer-public-route-table"
  subnets = module.producer_public_subnets.subnets[*]
  routes = [
    {
      cidr_block     = "0.0.0.0/0"
      gateway_id     = module.producer_vpc.igw_id
      nat_gateway_id = ""
    }
  ]
  vpc_id = module.producer_vpc.vpc_id
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "my-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.producer_public_subnets.subnets[*].id
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
  source                = "./modules/vpc/vpc"
  vpc_name              = "consumer-vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "consumer-vpc-igw"
}

# Security Group
module "consumer_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.consumer_vpc.vpc_id
  name   = "consumer-sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTP traffic"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Public Subnets
module "consumer_public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "consumer-public-subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.consumer_vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "consumer_private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "consumer-private-subnet"
  subnets = [
    {
      subnet = "10.0.4.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.6.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.consumer_vpc.vpc_id
  map_public_ip_on_launch = false
}

# Consumer Public Route Table
module "consumer_public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "consumer-public-route-table"
  subnets = module.consumer_public_subnets.subnets[*]
  routes = [
    {
      cidr_block     = "0.0.0.0/0"
      gateway_id     = module.consumer_vpc.igw_id
      nat_gateway_id = ""
    }
  ]
  vpc_id = module.consumer_vpc.vpc_id
}

resource "aws_vpc_endpoint" "consumer_endpoint" {
  vpc_id              = module.consumer_vpc.vpc_id
  service_name        = aws_vpc_endpoint_service.vpc_endpoint_service.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.consumer_public_subnets.subnets[0].id]
  security_group_ids  = [module.consumer_sg.id]
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
  subnet_id                   = module.producer_public_subnets.subnets[0].id
  security_groups             = [module.producer_sg.id]
  user_data                   = filebase64("${path.module}/scripts/user_data.sh")
}

module "consumer_instance" {
  source                      = "./modules/ec2"
  name                        = "consumer-instance"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.key_pair.key_name
  subnet_id                   = module.consumer_public_subnets.subnets[0].id
  security_groups             = [module.consumer_sg.id]
  user_data                   = filebase64("${path.module}/scripts/user_data.sh")
}