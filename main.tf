provider "aws" {
  region = "eu-west-1" # Change as needed
}

# Create VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "eks-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# IAM Role for EKS
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.34" # Updated to the latest valid version
  cluster_name    = "my-eks-cluster"
  cluster_version = "1.27" # Updated to the newest version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  enable_irsa = true
}

# Create an IAM role for the EKS node group
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach policies to the IAM role
resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Update the EKS node group to use the new IAM role
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "eks-nodes"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = module.vpc.public_subnets // Updated to use public subnets

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"

  launch_template {
    id      = aws_launch_template.eks_launch_template.id
    version = "$Latest"
  }
}

resource "aws_launch_template" "eks_launch_template" {
  name = "eks-launch-template"

  network_interfaces {
    associate_public_ip_address = true
  }

  key_name = "server_key" // Ensure this is your valid SSH key name
}

# Add a security group rule to allow SSH access
resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = module.vpc.default_security_group_id // Use the default security group or specify the correct one
  cidr_blocks       = ["0.0.0.0/0"] // Restrict this to your IP range for better security
}

# Use the aws_eks_cluster data source to retrieve kubeconfig
data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

resource "kubernetes_service" "lib_web_loadbalancer" {
  metadata {
    name      = "lib-web-loadbalancer"
    namespace = "library-site"
  }

  spec {
    selector = {
      app = "lib-web"
    }

    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 5000
    }
  }
}

# Outputs
output "cluster_id" {
  value = module.eks.cluster_id
}

# Update the kubeconfig output
output "kubeconfig" {
  value = data.aws_eks_cluster.eks.endpoint
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}