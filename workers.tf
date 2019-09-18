data "aws_ami" "workers" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-v*"]
  }

  most_recent = true
  owners      = ["602401143452"]
}

resource "aws_iam_role" "workers" {
  name = "EKSWorkersRole-${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "workers" {
  name = "EKSWorkersPolicy-${var.name}"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_instance_profile" "workers" {
  name = "EKSWorkersInstanceProfile-${aws_eks_cluster.master.name}"
  role = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_default" {
  role       = "${aws_iam_role.workers.name}"
  policy_arn = "${aws_iam_policy.workers.arn}"
}

resource "aws_iam_role_policy_attachment" "workers" {
  count      = "${length(var.workers_iam_policies)}"
  role       = "${aws_iam_role.workers.name}"
  policy_arn = "${element(var.workers_iam_policies, count.index)}"
}

resource "aws_security_group" "workers" {
  name   = "eksworkers-${var.name}"
  vpc_id = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
      "Environment", "${var.environment}",
      "Name", "eksworkers-${var.name}",
      "kubernetes.io/cluster/${var.name}", "owned",
      "Terraform", true,
    )
  }"
}

resource "aws_security_group_rule" "workers_ingress_self" {
  description              = "Allow node to communicate with each other."
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_master" {
  description              = "Allow workers Kubelets and pods to receive communication from the cluster control plane."
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.master.id}"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_master_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.master.id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

locals {
  userdata_workers = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint "${aws_eks_cluster.master.endpoint}" --b64-cluster-ca "${aws_eks_cluster.master.certificate_authority.0.data}" "${var.name}"
USERDATA

  configmap_awsauth = <<CONFIGMAPAWSAUTH

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.workers.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}

resource "aws_launch_configuration" "workers" {
  name_prefix                 = "EKSWorker-${aws_eks_cluster.master.name}"
  image_id                    = "${data.aws_ami.workers.id}"
  instance_type               = "t3.small"
  security_groups             = ["${aws_security_group.workers.id}"]
  associate_public_ip_address = true
  user_data_base64            = "${base64encode(local.userdata_workers)}"
  iam_instance_profile        = "${aws_iam_instance_profile.workers.name}"
  key_name                    = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  name                 = "EKSWorker-${aws_eks_cluster.master.name}"
  desired_capacity     = "${var.workers_desired_capacity}"
  min_size             = "${var.workers_min_capacity}"
  max_size             = "${var.workers_max_capacity}"
  launch_configuration = "${aws_launch_configuration.workers.id}"
  force_delete         = true
  vpc_zone_identifier  = ["${var.workers_subnet_ids}"]

  tags = ["${concat(
    list(
      map("key", "Environment", "value", "${var.environment}", "propagate_at_launch", true),
      map("key", "Name", "value", "EKSWorker-${var.name}", "propagate_at_launch", true),
      map("key", "kubernetes.io/cluster/${var.name}", "value", "owned", "propagate_at_launch", true),
      map("key", "k8s.io/cluster-autoscaler/enabled", "value", "true", "propagate_at_launch", true),
      map("key", "k8s.io/cluster-autoscaler/${var.name}", "value", "true", "propagate_at_launch", true),
      map("key", "Terraform", "value", true, "propagate_at_launch", true)
    )
  )}"]

  lifecycle {
    create_before_destroy = true
  }
}
