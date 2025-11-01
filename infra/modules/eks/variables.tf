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

variable "cde_subnet_ids" {
  description = "List of CDE private subnet IDs."
  type        = list(string)
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
}

