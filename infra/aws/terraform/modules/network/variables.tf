variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "nat_gateway_mode" {
  type = string
}

variable "container_port" {
  type = number
}
