variable "aws_region" {
  description = "AWS region to use for the study planner cluster."
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "study-planner-eks"
}

variable "environment" {
  description = "Environment label applied to infrastructure."
  type        = string
  default     = "dev"
}
