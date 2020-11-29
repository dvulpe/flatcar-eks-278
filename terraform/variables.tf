variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.17"
}

variable "instance_type" {
  type    = string
  default = "m5.large"
}

variable "flatcar_channel" {
  type = string
}

variable "flatcar_version" {
  type = string
}

variable "ssh_public_key" {
  type = string
}
