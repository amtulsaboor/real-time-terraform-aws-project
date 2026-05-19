terraform {
  backend "s3" {
    bucket = "terraform-aws-project-as"
    key    = "terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}

