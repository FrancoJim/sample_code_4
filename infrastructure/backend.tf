# Uncomment to enable S3 remote state.
# The S3 bucket and DynamoDB table must exist before running `terraform init`.
#
# terraform {
#   backend "s3" {
#     bucket         = "your-tfstate-bucket"
#     key            = "sample-eks/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
