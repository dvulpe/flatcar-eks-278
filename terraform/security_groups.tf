resource "aws_security_group" "cluster_sg" {
  name   = "${var.name}-cluster-sg"
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "${var.name}-cluster-sg"
  }
}

resource "aws_security_group_rule" "cluster" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "cluster_self" {
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster_sg.id
  to_port                  = 0
  type                     = "ingress"
  source_security_group_id = aws_security_group.cluster_sg.id
}

resource "aws_security_group_rule" "ingress_from_nodes" {
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster_sg.id
  to_port           = 443
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  type              = "ingress"
}

resource "aws_security_group_rule" "ingress_workers" {
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster_sg.id
  to_port                  = 443
  source_security_group_id = aws_security_group.worker_sg.id
  type                     = "ingress"
}

resource "aws_security_group" "worker_sg" {
  name   = "${var.name}-worker-sg"
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "${var.name}-worker-sg"
  }
}

resource "aws_security_group_rule" "egress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.worker_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

resource "aws_security_group_rule" "self" {
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_sg.id
  to_port                  = 0
  type                     = "ingress"
  source_security_group_id = aws_security_group.worker_sg.id
}

resource "aws_security_group_rule" "from_cluster" {
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  type                     = "ingress"
  security_group_id        = aws_security_group.worker_sg.id
  source_security_group_id = aws_security_group.cluster_sg.id
}
