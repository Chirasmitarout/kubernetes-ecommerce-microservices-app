terraform {
  backend "s3" {
    bucket       = "chikutaaaaaa"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
