variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "tags" {
  description = "The Azure resource tags which should be used for the example"
  type        = map(string)
  default = {
    Name = "my resource"
  }
}

variable "subscription_id" {
  description = "The Azure subscription id which should be used for the example"
}

variable "client_id" {
  description = "The Azure client id which should be used for the example"
}

variable "client_secret" {
  description = "The Azure client secret which should be used for the example"
}

variable "tenant_id" {
  description = "The Azure tenant id which should be used for the example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "Korea Central"
}

variable "instance_count" {
  description = "The count of VMs to be created"
  type = number
  default = 2
}