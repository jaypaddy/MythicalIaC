output "website_url" {
  description = "URL for Insoshi"
  value       = "http://${aws_lb.insoshi_lb.dns_name}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created for content storage"
  value       = aws_s3_bucket.s3_content.bucket
}

output "rds_endpoint" {
  description = "The endpoint URL of the RDS instance"
  value       = aws_db_instance.db_instance.address
}

output "s3_user_access_key" {
  description = "Access key for the S3 user"
  value       = aws_iam_access_key.s3_keys.id
  sensitive   = true
}

output "s3_user_secret_key" {
  description = "Secret key for the S3 user"
  value       = aws_iam_access_key.s3_keys.secret
  sensitive   = true
}
