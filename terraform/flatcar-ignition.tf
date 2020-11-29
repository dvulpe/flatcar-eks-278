data "ignition_directory" "scripts" {
  filesystem = "root"
  path       = "/scripts"
}

data "ignition_file" "download_kubelet" {
  filesystem = "root"
  path       = "/scripts/download-kubelet.sh"
  mode       = 493
  # 755 in octal
  content {
    content = file("${path.module}/files/download-kubelet.sh")
  }
}

data "ignition_file" "docker_daemon" {
  filesystem = "root"
  path       = "/etc/docker/daemon.json"
  content {
    content = file("${path.module}/files/docker-daemon.json")
  }
}

data "ignition_directory" "etc_kubernetes" {
  filesystem = "root"
  path       = "/etc/kubernetes"
}

data "ignition_file" "kubelet_conf" {
  filesystem = "root"
  path       = "/etc/kubernetes/kubelet-conf.yaml"
  content {
    content = file("${path.module}/files/kubelet-conf.yaml")
  }
}

data "ignition_file" "kubelet_kubeconfig" {
  filesystem = "root"
  path       = "/etc/kubernetes/kubelet-kubeconfig"
  content {
    content = templatefile("${path.module}/files/kubelet-kubeconfig", {
      cluster_endpoint = aws_eks_cluster.eks.endpoint
      cluster_name     = aws_eks_cluster.eks.name
      aws_region       = var.region
    })
  }
}

data "ignition_file" "kubernetes_ca" {
  filesystem = "root"
  path       = "/etc/kubernetes/ca.crt"
  content {
    content = base64decode(aws_eks_cluster.eks.certificate_authority.0.data)
  }
}

data "ignition_systemd_unit" "kubelet" {
  name    = "kubelet.service"
  enabled = true
  content = file("${path.module}/files/kubelet.service")
}

data "ignition_systemd_unit" "update_service" {
  name = "update-engine.service"
  mask = true
}

data "ignition_systemd_unit" "locksmithd" {
  name = "locksmithd.service"
  mask = true
}

data "ignition_config" "ignition" {
  directories = [
    data.ignition_directory.scripts.rendered,
    data.ignition_directory.etc_kubernetes.rendered,
  ]
  files = [
    data.ignition_file.kubernetes_ca.rendered,
    data.ignition_file.download_kubelet.rendered,
    data.ignition_file.kubelet_conf.rendered,
    data.ignition_file.kubelet_kubeconfig.rendered,
    data.ignition_file.docker_daemon.rendered,
  ]
  systemd = [
    data.ignition_systemd_unit.kubelet.rendered,
    data.ignition_systemd_unit.update_service.rendered,
    data.ignition_systemd_unit.locksmithd.rendered,
  ]
}
