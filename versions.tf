# Example configuration of terraform providers

terraform {
  required_version = ">= 0.13.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.15.0"
    }
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.29.0"
    }
  }
}
