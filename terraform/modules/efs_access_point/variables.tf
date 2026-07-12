variable "file_system_id" {
  description = "ID of the EFS file system to attach the access point to"
  type        = string
  nullable    = false
}

variable "path" {
  description = "Directory path created for the access point root"
  type        = string
  nullable    = false
}

variable "group_id" {
  description = "POSIX group ID assigned to the access point owner"
  type        = number
  default     = 1000
}

variable "user_id" {
  description = "POSIX user ID assigned to the access point owner"
  type        = number
  default     = 1000
}

variable "permissions" {
  description = "File system permissions for the root directory"
  type        = string
  default     = "0755"
}

variable "tags" {
  description = "Tags applied to the access point"
  type        = map(string)
  default     = {}
}
