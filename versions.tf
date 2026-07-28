terraform {
  # optional() in object types requires 1.3; multiple validation blocks 1.x.
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
