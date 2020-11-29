data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
    ]
  }
}


resource "aws_iam_role" "worker_role" {
  name               = "${var.name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}


locals {
  worker_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
  ]
}

resource "aws_iam_role_policy_attachment" "worker_attach" {
  for_each   = toset(local.worker_policies)
  role       = aws_iam_role.worker_role.name
  policy_arn = each.value
}

locals {
  worker_roles = [
    {
      rolearn  = aws_iam_role.worker_role.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:nodes",
        "system:bootstrappers",
      ]
    }
  ]
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles    = yamlencode(local.worker_roles)
    mapUsers    = yamlencode([])
    mapAccounts = yamlencode([])
  }
}

resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 1
}

data "aws_iam_policy_document" "eks_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
    ]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_trust.json
}

locals {
  policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
  ]
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each   = toset(local.policies)
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "eks" {
  name     = var.name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version
  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids = [
      aws_security_group.cluster_sg.id,
    ]
    public_access_cidrs = [
      "0.0.0.0/0",
    ]
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach,
    aws_cloudwatch_log_group.eks_logs,
  ]

  enabled_cluster_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler",
  ]
}
