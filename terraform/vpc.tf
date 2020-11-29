data "aws_availability_zones" "azs" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"
  name    = var.name
  cidr    = var.cidr

  azs = data.aws_availability_zones.azs.names
  private_subnets = [
    for index, az in data.aws_availability_zones.azs.names :
    cidrsubnet(var.cidr, 4, index)
  ]

  public_subnets = [
    for index, az in data.aws_availability_zones.azs.names :
    cidrsubnet(var.cidr, 4, index + 3)
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared",
    Tier                                = "private"
  }
}

resource "aws_security_group" "bastion" {
  name   = "bastion"
  vpc_id = module.vpc.vpc_id
  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    from_port = 22
    protocol  = "tcp"
    to_port   = 22
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_security_group_rule" "allow_from_bastion" {
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.worker_sg.id
  to_port                  = 22
  type                     = "ingress"
  source_security_group_id = aws_security_group.bastion.id
}

data "aws_ami" "flatcar_latest" {
  most_recent = true
  owners      = ["075585003325"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["Flatcar-${var.flatcar_channel}-*"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.flatcar_latest.image_id
  instance_type = "t3.small"
  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  key_name = aws_key_pair.ssh.key_name

  tags = {
    Name = "bastion"
  }
  subnet_id = module.vpc.public_subnets[0]
}
