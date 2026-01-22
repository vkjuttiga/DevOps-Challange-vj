terraform {
  backend "s3" {
    bucket       = "devops-challenge-vj"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
