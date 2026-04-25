# Create s3 bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-bucket--688600819246"

  tags = {
    Name        = "s3 website bucket"
    Environment = var.environment
  }
}
# Block public access of s3 bucket
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
#Cloudfront OAC
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "This cloudfront OAC is managed by terraform"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
#Cloudfront distribution 
resource "aws_cloudfront_distribution" "main" {
  enabled = true
  default_root_object = "index.html"

  # WHERE to fetch content from — S3 bucket
  origin {
    domain_name              = aws_s3_bucket.main.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = "s3-${var.project_name}-${var.environment}"
  }

  # HOW to handle incoming requests
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.project_name}-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # WHO can access — no country restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # HTTPS certificate (custom domain not allowed because of CF default certificate)
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
#s3 Bucket policy
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.main.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}