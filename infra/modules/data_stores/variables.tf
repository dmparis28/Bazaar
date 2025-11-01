variable "name_prefix" {
  description = "The prefix for all resource names."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs."
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "The security group ID for the EKS nodes."
  type        = string
}

