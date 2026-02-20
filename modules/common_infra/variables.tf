variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "nsg_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "management_port" {
  type = number
}

variable "management_rule_name" {
  type = string
}

variable "management_source_prefix" {
  type    = string
  default = "VirtualNetwork"
}

variable "management_rule_priority" {
  type    = number
  default = 110
}

variable "enable_https_inbound" {
  type    = bool
  default = false
}

variable "https_inbound_priority" {
  type    = number
  default = 120
}
