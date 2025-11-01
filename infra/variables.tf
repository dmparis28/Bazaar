variable "aws_region" {
  description = "The AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "The prefix for all resource names (e.g., 'bazaar')"
  type        = string
  default     = "bazaar"
}

