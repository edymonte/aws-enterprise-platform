variable "postgres_version" {
  type    = string
  default = "16"
}

variable "db_instance_class" {
  description = "db.t4g.micro is free-tier eligible."
  type        = string
  default     = "db.t4g.micro"
}
