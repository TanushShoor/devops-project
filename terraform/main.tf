locals {
  kubernetes_version = "1.35"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name               = "study-planner-vpc"
  cidr               = "10.20.0.0/16"
  azs                = ["ap-southeast-2a", "ap-southeast-2b"]
  private_subnets    = ["10.20.1.0/24", "10.20.2.0/24"]
  public_subnets     = ["10.20.101.0/24", "10.20.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
  tags = {
    Environment = var.environment
    Project     = "StudySpace"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name                             = var.cluster_name
  cluster_version                          = local.kubernetes_version
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  # The student AWS account's Organizations policy denies OIDC provider creation.
  # Workloads in this capstone do not need IRSA, so keep the cluster deployable
  # with the permissions available in the Free Plan account.
  enable_irsa = false

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    main = {
      # t3.medium is rejected by Free Plan accounts; t3.small is Free Tier eligible.
      instance_types = ["t3.small"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
    }
  }

  tags = {
    Environment = var.environment
    Project     = "StudySpace"
  }
}
