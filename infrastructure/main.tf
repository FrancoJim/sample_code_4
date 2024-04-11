provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_subnet" "eks_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name                                       = "eks_subnet_1"
    "kubernetes.io/cluster/sample-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "eks_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name                                       = "eks_subnet_2"
    "kubernetes.io/cluster/sample-eks-cluster" = "shared"
  }
}

resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "eks_route_table"
  }
}

resource "aws_route_table_association" "eks_subnet_1_association" {
  subnet_id      = aws_subnet.eks_subnet_1.id
  route_table_id = aws_route_table.eks_route_table.id
}

resource "aws_route_table_association" "eks_subnet_2_association" {
  subnet_id      = aws_subnet.eks_subnet_2.id
  route_table_id = aws_route_table.eks_route_table.id
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

resource "aws_iam_role" "eks_worker_nodes" {
  name = "eks_worker_nodes_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_nodes_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_worker_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_worker_nodes_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_worker_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_worker_nodes_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_worker_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_policy" "eks_ebs_policy" {
  name        = "eksEbsPolicy"
  description = "EKS EBS policy for worker nodes"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:ModifyVolume",
          "ec2:CreateTags"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_ebs_attachment" {
  role       = aws_iam_role.eks_worker_nodes.name
  policy_arn = aws_iam_policy.eks_ebs_policy.arn
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "sample-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController
  ]
}

resource "aws_security_group" "eks_nodes_sg" {
  name        = "eks-nodes-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.eks_vpc.id

  # Allow outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-nodes-sg"
  }
}

resource "aws_eks_node_group" "sample" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "sample-node-group"
  node_role_arn   = aws_iam_role.eks_worker_nodes.arn
  subnet_ids      = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Use the describe-instance-types command to filter instance types based on instance attributes. For example, you can use the following command to display only current generation instance types with 64 GiB (65536 MiB) of memory.
  # `aws ec2 describe-instance-types --filters "Name=current-generation,Values=true" "Name=memory-info.size-in-mib,Values=65536" --query "InstanceTypes[*].[InstanceType]" --output text | sort`
  #
  # Use the describe-instance-type-offerings command to filter instance types offered by location (Region or Zone). For example, you can use the following command to display the instance types offered in the specified Zone.
  # `aws ec2 describe-instance-type-offerings --location-type "availability-zone" --filters Name=location,Values=us-east-2a --region us-east-2 --query "InstanceTypeOfferings[*].[InstanceType]" --output text | sort`
  instance_types = ["t3.large"]

  update_config {
    max_unavailable = 1
  }

  # Associate security groups with EKS Node Group
  # remote_access {
  #   ec2_ssh_key               = "your-ssh-key-name-here"
  #   source_security_group_ids = [aws_security_group.eks_nodes_sg.id]
  # }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_worker_nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_worker_nodes_AmazonEC2ContainerRegistryReadOnly,
    aws_security_group.eks_nodes_sg
  ]

}
