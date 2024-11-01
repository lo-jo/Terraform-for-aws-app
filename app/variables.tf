variable "db_username" {
  description = "database user name"
  type        = string
  sensitive   = true
}

variable "db_pw" {
  description = "database user password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "database name"
  type        = string
  sensitive   = true
}