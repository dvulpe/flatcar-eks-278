resource "aws_iam_instance_profile" "worker" {
  name = aws_iam_role.worker_role.name
  role = aws_iam_role.worker_role.name
}

data "aws_ami" "flatcar" {
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
    values = ["Flatcar-${var.flatcar_channel}-${var.flatcar_version}-*"]
  }
}

resource "aws_key_pair" "ssh" {
  key_name   = var.name
  public_key = var.ssh_public_key
}


resource "aws_launch_configuration" "node" {
  instance_type        = var.instance_type
  name_prefix          = "${var.name}-"
  iam_instance_profile = aws_iam_instance_profile.worker.name
  image_id             = data.aws_ami.flatcar.image_id
  security_groups      = [aws_security_group.worker_sg.id]
  spot_price           = "0.5"
  user_data            = data.ignition_config.ignition.rendered

  key_name = var.name

  root_block_device {
    delete_on_termination = true
    volume_size           = 20
    volume_type           = "gp2"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nodegroup" {
  max_size             = 3
  min_size             = 2
  desired_capacity     = 2
  vpc_zone_identifier  = module.vpc.private_subnets
  launch_configuration = aws_launch_configuration.node.id

  name = var.name

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
    create_before_destroy = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.eks.name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster/${aws_eks_cluster.eks.name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  depends_on = [
    aws_eks_cluster.eks,
    kubernetes_config_map.aws_auth,
  ]
}
