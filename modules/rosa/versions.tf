terraform {
  required_providers {
    rhcs = {
      source = "terraform-redhat/rhcs"
    }
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
