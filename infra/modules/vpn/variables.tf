variable "name_prefix" {
  description = "The prefix for all resource names."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR of the VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs."
  type        = list(string)
}

