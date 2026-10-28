variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "student_name" {
  type        = string
  description = "Used for the Student tag"
}

variable "my_ip_cidr" {
  type        = string
  description = "Your current public IPv4 as /32, e.g. 203.0.113.7/32 (curl checkip.amazonaws.com)"
  validation {
    condition     = can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}/32$", var.my_ip_cidr)) && var.my_ip_cidr != "0.0.0.0/32"
    error_message = "Provide a single IPv4 address as /32. Never expose SSH to 0.0.0.0/0."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "enable_peering" {
  type        = bool
  default     = true
  description = "false = baseline (no peering, no peer routes). true = peering + routes on both sides."
}

variable "enable_app_b_icmp_rule" {
  type        = bool
  default     = true
  description = "Set false for the workbook's controlled failure (removes App-B ICMP echo rule from App-A)."
}

variable "enable_app_ports" {
  type        = bool
  default     = true
  description = "Extra rules for the full-stack demo: bastion->App-A:8080 and App-A->App-B:9000 (scoped /32)."
}

# Address plan (workbook page 4)
variable "vpc_a_cidr" {
  default = "10.10.0.0/16"
}
variable "a_public_cidr" {
  default = "10.10.1.0/24"
}
variable "a_private_cidr" {
  default = "10.10.2.0/24"
}
variable "vpc_b_cidr" {
  default = "10.20.0.0/16"
}
variable "b_private_cidr" {
  default = "10.20.1.0/24"
}
variable "bastion_ip" {
  default = "10.10.1.10"
}
variable "app_a_ip" {
  default = "10.10.2.10"
}
variable "app_b_ip" {
  default = "10.20.1.10"
}
