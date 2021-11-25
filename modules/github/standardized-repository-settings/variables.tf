variable "github_token" {
  description = "Token used to access GitHub"
  type        = string
  sensitive   = true
}

variable "repository_name" {
  description = "Name of the repository"
  type        = string
}

variable "repository_description" {
  description = "Description for this repository"
  type        = string
  default     = "No description"
}

variable "repository_visibility" {
  description = "The visibility of the repository ('private' or 'public')"
  type        = string
  default     = "private"
}

variable "required_status_checks" {
  description = "Status checks that need to pass to merge a PR to the main branch"
  type        = list(string)
  default     = ["test"]
}

variable "vulnerability_alerts" {
  description = "Whether to enable GitHub's default vulnerability checks via Dependabot"
  type        = bool
  default     = true
}
