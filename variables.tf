variable "aws_region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "public_cidr" {
  type = string
}

variable "public_cidr2" {
  type = string
}

variable "private_cidr" {
  type = string
}

variable "private_cidr2" {
  type = string
}

variable "certificate_arn" {
  type      = string
  sensitive = true
}

variable "aws_account_id" {
  type      = string
  sensitive = true
}

variable "public_zone_id" {
  type      = string
  sensitive = true
}