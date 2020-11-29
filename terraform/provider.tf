provider "aws" {
  region = var.region
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
  depends_on = [
    aws_eks_cluster.eks,
  ]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}
