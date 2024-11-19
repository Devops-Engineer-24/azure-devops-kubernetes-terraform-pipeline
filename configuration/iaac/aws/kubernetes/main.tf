terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
  }
}

resource "aws_default_vpc" "default" {

}

### Uncomment this section after cluster creation line numbers 25 to 31 ###
data "aws_eks_cluster" "example" {
   name = "in28minutes-cluster"
 }

data "aws_eks_cluster_auth" "example" {
  name = "in28minutes-cluster"
}
### Uncomment this section after cluster creation ###

provider "kubernetes" {
### Uncomment this section after cluster creation line numbers 36 to 38###
  host                   = data.aws_eks_cluster.example.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.example.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.example.token
### Uncomment this section after cluster creation ###
}



module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.30"

  subnet_ids = [
    "subnet-021a248222a3bba9e",  # Replace with your actual subnet ID
    "subnet-0821207f4733cbaee",  # Replace with your actual subnet ID
    "subnet-0350135772a072e36"   # Replace with your actual subnet ID
  ]
  
  vpc_id = aws_default_vpc.default.id

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

### Uncomment this section after cluster creation line numbers 88 to 115###
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
   name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
 }

resource "kubernetes_secret" "example" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "default"
    }

    generate_name = "terraform-default-"
  }
  type  = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
 }
### Uncomment this section after cluster creation ###

# Needed to set the default region

resource "kubernetes_service_account" "terraform_service_account" {
  metadata {
    name      = "terraform-admin-for-azure-devops"  # Corrected to lowercase
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
}

# Provider configuration for AWS
provider "aws" {
  region = "us-east-1"
}
