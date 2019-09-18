provider "aws" {
  region = "eu-west-1"
}

module "test" {
  source             = "../"
  environment        = "test"
  name               = "test"
  key_name           = "test"
  vpc_id             = "vpc-x"
  master_subnet_ids  = ["subnet-1", "subnet-2", "subnet-3"]
  workers_subnet_ids = ["subnet-1", "subnet-2", "subnet-3"]
}

output "kubeconfig" {
  value = "${module.test.kubeconfig}"
}

output "awsauth" {
  value = "${module.test.configmap_awsauth}"
}
