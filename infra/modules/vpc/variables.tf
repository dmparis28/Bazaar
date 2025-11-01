variable "name_prefix" {
  description = "The prefix for all resource names."
  type        = string
}

variable "region" {
  description = "The AWS region."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

