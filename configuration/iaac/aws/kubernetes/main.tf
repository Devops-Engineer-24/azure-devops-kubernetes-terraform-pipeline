terraform {
  backend "s3" {
    bucket = "mybucket" # Overridden during build
    key    = "path/to/my/key" # Overridden during build
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.example.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.example.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.example.token
}

# Create EKS Cluster
module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.30"

  subnet_ids       = ["subnet-021a248222a3bba9e", "subnet-0821207f4733cbaee", "subnet-0350135772a072e36"]
  vpc_id           = aws_default_vpc.default.id
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
    two = {
      name           = "node-group-2"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
}

resource "aws_default_vpc" "default" {}

# Fetch EKS Cluster Data
data "aws_eks_cluster" "example" {
  name = module.in28minutes-cluster.cluster_name
}

data "aws_eks_cluster_auth" "example" {
  name = module.in28minutes-cluster.cluster_name
}

# Create Kubernetes Service Account
resource "kubernetes_service_account" "terraform_service_account" {
  metadata {
    name      = "terraform-admin-for-azure-devops"
    namespace = "default"
  }
}

# Bind the Service Account to Cluster Admin Role
resource "kubernetes_cluster_role_binding" "terraform_admin_binding" {
  metadata {
    name = "terraform-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.terraform_service_account.metadata[0].name
    namespace = kubernetes_service_account.terraform_service_account.metadata[0].namespace
  }
}

# Grant Full Admin Access to Your IAM Role/User
resource "kubernetes_cluster_role_binding" "iam_admin_binding" {
  metadata {
    name = "iam-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "User"
    name      = "your-iam-user-or-role-name" # Replace with your IAM user or role name
    api_group = "rbac.authorization.k8s.io"
  }
}

# Outputs
output "cluster_name" {
  value = module.in28minutes-cluster.cluster_name
}

output "cluster_endpoint" {
  value = data.aws_eks_cluster.example.endpoint
}

output "service_account_name" {
  value = kubernetes_service_account.terraform_service_account.metadata[0].name
}
