#------------------------------------------------
# Cloudfront
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
#------------------------------------------------

resource "aws_cloudfront_origin_access_identity" "cf" {
  comment = "${var.common_name}-cf"
}

resource "aws_cloudfront_distribution" "cf" {
  comment          = "${var.common_name}-cf"
  price_class      = var.cf_config["price_class"]
  retain_on_delete = true
  enabled          = true

  origin {
    origin_id   = aws_lb.app.name
    domain_name = aws_lb.app.dns_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }

    custom_header {
      name  = var.origin_header_name
      value = var.origin_header_key
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.app.name

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern           = "images/*.png" #cache logo
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_lb.app.name
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
