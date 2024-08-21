// Name of the S3 bucket that will store our raw logs
variable "bucket_name" {
    type = string
    default = "raw-s3-logs-telemetry-1211"
}
// Name of the ~/.aws/credentials profile that Terraform will use to create AWS infrastructure
variable "tf_iam_profile" {
    type = string
    default = "production-iamadmin"
}