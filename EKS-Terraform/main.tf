```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

############################
# VARIABLES
############################

variable "cluster_version" {
  default = "1.35"
}

############################
# VPC
############################

resource "aws_vpc" "eks_vpc" {

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
  }
}

############################
# INTERNET GATEWAY
############################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

############################
# PUBLIC SUBNET 1
############################

resource "aws_subnet" "public1" {

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-1"
  }
}

############################
# PUBLIC SUBNET 2
############################

resource "aws_subnet" "public2" {

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-2"
  }
}

############################
# PRIVATE SUBNET 1
############################

resource "aws_subnet" "private1" {

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "eks-private-1"
  }
}

############################
# PRIVATE SUBNET 2
############################

resource "aws_subnet" "private2" {

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "eks-private-2"
  }
}

############################
# ELASTIC IP FOR NAT
############################

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = {
    Name = "eks-nat-eip"
  }
}

############################
# NAT GATEWAY
############################

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name = "eks-nat-gateway"
  }
}

############################
# PUBLIC ROUTE TABLE
############################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "eks-public-route-table"
  }
}

############################
# PUBLIC SUBNET ASSOCIATIONS
############################

resource "aws_route_table_association" "pub1" {

  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub2" {

  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

############################
# PRIVATE ROUTE TABLE
############################

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "eks-private-route-table"
  }
}

############################
# PRIVATE SUBNET ASSOCIATIONS
############################

resource "aws_route_table_association" "priv1" {

  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "priv2" {

  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

############################
# SECURITY GROUP
############################

resource "aws_security_group" "allow_all" {

  name        = "allow-all-sg"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "Allow all inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "allow-all-sg"
  }
}

############################################################
# EXISTING IAM ROLE - EKS CLUSTER
############################################################

data "aws_iam_role" "cluster_role" {

  name = "eks-cluster-role"
}

############################
# EKS CLUSTER POLICY
############################

resource "aws_iam_role_policy_attachment" "cluster_policy" {

  role       = data.aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

############################################################
# EXISTING IAM ROLE - EKS WORKER NODE
############################################################

data "aws_iam_role" "worker_role" {

  name = "eks-worker-role"
}

############################
# WORKER NODE POLICY
############################

resource "aws_iam_role_policy_attachment" "worker_node" {

  role       = data.aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

############################
# CNI POLICY
############################

resource "aws_iam_role_policy_attachment" "cni" {

  role       = data.aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

############################
# ECR POLICY
############################

resource "aws_iam_role_policy_attachment" "ecr" {

  role       = data.aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

############################
# EKS CLUSTER
############################

resource "aws_eks_cluster" "eks" {

  name     = "naresh56"
  role_arn = data.aws_iam_role.cluster_role.arn
  version  = var.cluster_version

  vpc_config {

    subnet_ids = [
      aws_subnet.private1.id,
      aws_subnet.private2.id
    ]

    endpoint_public_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Name        = "naresh56"
    Environment = "dev"
    Project     = "eks-project"
  }
}

############################
# EKS NODE GROUP
############################

resource "aws_eks_node_group" "node_group" {

  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-node-group"

  node_role_arn = data.aws_iam_role.worker_role.arn
  version       = var.cluster_version

  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  instance_types = [
    "t3.medium"
  ]

  scaling_config {

    desired_size = 4
    max_size     = 6
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_iam_role_policy_attachment.cni,
    aws_iam_role_policy_attachment.ecr
  ]

  tags = {
    Name        = "eks-node"
    Environment = "dev"
    Project     = "eks-project"
    Owner       = "veeraops"
  }
}

############################
# EC2 INSTANCE
############################

resource "aws_instance" "eks" {

  ami           = "ami-02dfbd4ff395f2a1b"
  instance_type = "t2.medium"

  subnet_id = aws_subnet.public1.id

  vpc_security_group_ids = [
    aws_security_group.allow_all.id
  ]

  root_block_device {
    volume_size = 30
  }

  tags = {
    Name = "eks"
  }

  user_data = <<-EOF
    #!/bin/bash

    yum update -y

    # ------------------------------------
    # Install kubectl
    # ------------------------------------

    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    chmod +x kubectl

    mv kubectl /usr/local/bin/kubectl

    kubectl version --client || true

    # ------------------------------------
    # Install eksctl
    # ------------------------------------

    curl --silent --location \
      "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
      | tar xz -C /tmp

    mv /tmp/eksctl /usr/local/bin/eksctl

    eksctl version || true

  EOF
}

############################################################
# EKS ADDON - VPC CNI
############################################################

resource "aws_eks_addon" "vpc_cni" {

  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node_group
  ]
}

############################################################
# EKS ADDON - CORE DNS
############################################################

resource "aws_eks_addon" "coredns" {

  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "coredns"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node_group
  ]
}

############################################################
# EKS ADDON - KUBE PROXY
############################################################

resource "aws_eks_addon" "kube_proxy" {

  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node_group
  ]
}

############################################################
# EKS ADDON - POD IDENTITY AGENT
############################################################

resource "aws_eks_addon" "pod_identity" {

  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node_group
  ]
}

############################################################
# EXISTING EBS CSI IAM ROLE
############################################################

data "aws_iam_role" "ebs_csi_role" {

  name = "AmazonEKS_EBS_CSI_DriverRole"
}

############################
# EBS CSI IAM POLICY
############################

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {

  role = data.aws_iam_role.ebs_csi_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

############################
# EBS CSI POD IDENTITY
############################

resource "aws_eks_pod_identity_association" "ebs_csi" {

  cluster_name = aws_eks_cluster.eks.name

  namespace = "kube-system"

  service_account = "ebs-csi-controller-sa"

  role_arn = data.aws_iam_role.ebs_csi_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_policy,
    aws_eks_addon.pod_identity
  ]
}

############################################################
# EBS CSI DRIVER ADDON
############################################################

resource "aws_eks_addon" "ebs_csi" {

  cluster_name = aws_eks_cluster.eks.name

  addon_name = "aws-ebs-csi-driver"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_pod_identity_association.ebs_csi
  ]
}

############################################################
# EXISTING RDS DB SUBNET GROUP
############################################################
#
# IMPORTANT:
# 'main' DB subnet group already exists in AWS.
#
# Therefore DO NOT create:
#
# resource "aws_db_subnet_group" "sub-grp"
#
# Instead, read the existing subnet group using DATA.
############################################################

data "aws_db_subnet_group" "main" {

  name = "main"
}
```

### Aapke `rds.tf` mein kya change karna hai

**Ye old code hata do:**

```hcl
resource "aws_db_subnet_group" "sub-grp" {

  name = "main"

  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  tags = {
    Name = "main"
  }
}
```

Aur isko use karo:

```hcl
data "aws_db_subnet_group" "main" {
  name = "main"
}
```

### Agar `aws_db_instance` bhi hai

Agar aapke `rds.tf` mein RDS instance kuch aisa hai:

```hcl
resource "aws_db_instance" "mysql" {

  # ...

  db_subnet_group_name = aws_db_subnet_group.sub-grp.name
}
```

to usko bhi change karna hoga:

```hcl
db_subnet_group_name = data.aws_db_subnet_group.main.name
```

**Simple difference:**

```text
resource "aws_db_subnet_group"
        ↓
Terraform AWS mein NEW subnet group banayega
        ↓
Already "main" exists
        ↓
ERROR ❌
```

Correct:

```text
data "aws_db_subnet_group"
        ↓
Terraform existing "main" ko read karega
        ↓
NEW subnet group create nahi karega
        ↓
ERROR solved ✅
```

### Ab commands

Old `aws_db_subnet_group.sub-grp` resource ko code se remove karne ke baad:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

**Ek important point:** Agar aapka existing `main` DB subnet group **old/different VPC ke subnets** ko point karta hai, to RDS ke liye woh automatically correct nahi hoga. Us case mein existing `main` ko import/manage karna ya naya uniquely named subnet group banana better hoga. Lekin **sirf `DBSubnetGroupAlreadyExists` error ke according**, `data "aws_db_subnet_group"` wala change sahi hai.
