variable "aws_region" {
  default = "us-east-1"
}

variable "proxy_class" {
  default = "t3.micro"
}

variable "upstream_ip" {
  default = "104.16.184.241"
}

variable "upstream_port" {
  default = 443
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet1_cidr" {
  default = "10.0.1.0/24"
}

variable "subnet2_cidr" {
  default = "10.0.2.0/24"
}