provider "aws" {
  region     = "eu-west-3"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
provider "talos" {}
