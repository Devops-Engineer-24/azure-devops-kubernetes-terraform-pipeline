terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
  }
}

# AWS Provider Configuration
provider "aws" {
  region = "us-east-1"
}

# Kubernetes Provider Configuration (after EKS cluster creation)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.example.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.example.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.example.token
}

# EKS Cluster Creation
module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.30"
  
  subnet_ids         = ["subnet-021a248222a3bba9e", "subnet-0821207f4733cbaee", "subnet-0350135772a072e36"] # Specify correct subnets
  vpc_id            = aws_default_vpc.default.id
  
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

# AWS Default VPC
resource "aws_default_vpc" "default" {}

# Fetch the EKS cluster details after creation
data "aws_eks_cluster" "example" {
  name = module.in28minutes-cluster.cluster_name
}

data "aws_eks_cluster_auth" "example" {
  name = module.in28minutes-cluster.cluster_name
}

# Kubernetes Service Account (For Terraform Automation)
resource "kubernetes_service_account" "terraform_service_account" {
  metadata {
    name      = "terraform-admin-for-Azure-Devops"
    namespace = "default"
  }
}

# ClusterRoleBinding for Admin Access to Service Account
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

# Kubernetes Secret for Service Account Token
resource "kubernetes_secret" "terraform_secret" {
  metadata {
    name      = "terraform-service-account-token"
    namespace = "default"
  }

  data = {
    token = base64encode(data.aws_eks_cluster_auth.example.token)
  }
}

# Backend Configuration for Terraform State (Azure Storage example)
terraform {
  backend "azurerm" {
    resource_group_name   = "myResourceGroup"
    storage_account_name = "myterraformstate"
    container_name       = "tfstate"
    key                  = "path/to/my/key"
  }
}

# To initialize the backend and apply configuration
output "cluster_name" {
  value = module.in28minutes-cluster.cluster_name
}

output "cluster_endpoint" {
  value = data.aws_eks_cluster.example.endpoint
}

output "cluster_certificate_authority" {
  value = data.aws_eks_cluster.example.certificate_authority[0].data
}
