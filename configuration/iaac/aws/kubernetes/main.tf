terraform {
  backend "s3" {
    bucket = "mybucket" # Replace with your bucket
    key    = "path/to/my/key" # Replace with your backend key
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = module.in28minutes-cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.in28minutes-cluster.cluster_certificate_authority_data)
  token                  = module.in28minutes-cluster.cluster_auth_token
}

# Create EKS Cluster
module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.30"

  vpc_id     = aws_default_vpc.default.id
  subnet_ids = ["subnet-021a248222a3bba9e", "subnet-0821207f4733cbaee", "subnet-0350135772a072e36"]

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

# Create a Token Secret for the Service Account
resource "kubernetes_secret" "terraform_service_account_token" {
  metadata {
    name      = "terraform-service-account-token"
    namespace = kubernetes_service_account.terraform_service_account.metadata[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.terraform_service_account.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

# Outputs
output "cluster_name" {
  value = module.in28minutes-cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.in28minutes-cluster.cluster_endpoint
}

output "service_account_name" {
  value = kubernetes_service_account.terraform_service_account.metadata[0].name
}

output "service_account_token_name" {
  value = kubernetes_secret.terraform_service_account_token.metadata[0].name
}
