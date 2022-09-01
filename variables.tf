variable "service_account_file_name" {
  type        = string
  description = "File with the service account key"
  default     = "key.json"
}

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "europe-west4"
}

variable "zone" {
  type        = string
  description = "Default GCP zone"
  default     = "europe-west4-a"
}

variable "bucket_region" {
  type        = string
  description = "Default GCP bucket region"
  default     = "EUROPE-WEST4"
}

variable "snowflake_region" {
  type        = string
  description = "Snowflake region"
  default     = "europe-west4.gcp"
}

variable "snowflake_username" {
  type        = string
  description = "Snowflake username"
}

variable "snowflake_account" {
  type        = string
  description = "Snowflake account name. https://docs.snowflake.com/en/user-guide/admin-account-identifier.html"
  sensitive   = true
}

variable "snowflake_password" {
  type        = string
  description = "Snowflake password"
  sensitive   = true
}