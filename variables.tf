variable "environment" {}

variable "name" {}

variable "vpc_id" {}

variable "key_name" {}

variable "master_subnet_ids" {
  type = "list"
}

variable "workers_subnet_ids" {
  type = "list"
}

variable "workers_tags" {
  type    = "map"
  default = {}
}

variable "workers_desired_capacity" {
  default = 1
}

variable "workers_min_capacity" {
  default = 1
}

variable "workers_max_capacity" {
  default = 1
}

variable "master_iam_policies" {
  type = "list"

  default = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
  ]
}

variable "workers_iam_policies" {
  type = "list"

  default = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}
