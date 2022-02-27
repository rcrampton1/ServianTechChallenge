output "application_url" {
  value = "https://${aws_cloudfront_distribution.cf.domain_name}"
}
