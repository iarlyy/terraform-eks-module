resource "aws_iam_role" "master" {
  name = "EKSMasterRole-${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "master" {
  count = "${length(var.master_iam_policies)}"
  role = "${aws_iam_role.master.name}"
  policy_arn = "${element(var.master_iam_policies, count.index)}"
}

resource "aws_security_group" "master" {
  name = "eksmaster-${var.name}"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 443
    to_port = 443
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment = "${var.environment}"
    Name = "eksmaster-${var.name}"
    Terraform = true
  }
}

resource "aws_eks_cluster" "master" {
  name = "${var.name}"
  role_arn = "${aws_iam_role.master.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.master.id}"]
    subnet_ids = ["${var.master_subnet_ids}"]
  }

  depends_on = ["aws_iam_role.master", "aws_iam_role_policy_attachment.master"]
}

locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.master.endpoint}
    certificate-authority-data: ${aws_eks_cluster.master.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.name}"
KUBECONFIG
}
