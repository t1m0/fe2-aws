variable "file_system_id" {
  type = string
}

variable "path" {
  type = string
}

variable "group_id" {
  type    = number
  default = 1000
}

variable "user_id" {
  type    = number
  default = 1000
}

variable "permissions" {
  type    = string
  default = "0755"
}
