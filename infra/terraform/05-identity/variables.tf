variable "state_bucket" {
  type = string
}

variable "github_repository" {
  description = "owner/repo allowed to federate."
  type        = string
  default     = "edymonte/aws-enterprise-platform"
}

variable "ado_organization_id" {
  description = "Azure DevOps organization GUID (empty = no ADO identity yet)."
  type        = string
  default     = ""
}

variable "ado_service_connection_subject" {
  description = "sc://<org-name>/<project>/<service-connection-name>"
  type        = string
  default     = ""
}
