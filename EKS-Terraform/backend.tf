terraform {
  backend "s3" {
    bucket       = "supjjggrojikkknayak34ff"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
