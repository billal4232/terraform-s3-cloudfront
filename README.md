# Terraform S3 + CloudFront Static Site

A static website hosted on a private S3 bucket, served through CloudFront using Origin Access Control (OAC). Built entirely with Terraform.

## Architecture
User → CloudFront (edge location) → S3 (private bucket)

## Resources Created

- S3 bucket (private, no public access)
- S3 bucket policy (allows only this CloudFront distribution)
- CloudFront Origin Access Control (OAC)
- CloudFront distribution

## Key Decisions

**Why OAC instead of making S3 public?**
OAC allows CloudFront to authenticate with S3 privately. Nobody can access the S3 bucket directly — all traffic must go through CloudFront. This means HTTPS only, caching at edge locations, and no direct S3 exposure.

**Why bucket endpoint instead of website endpoint?**
S3 has two endpoints — bucket endpoint and website endpoint. The website endpoint handles index.html routing automatically but does not support OAC, meaning the bucket must be public. The bucket endpoint supports OAC and keeps the bucket private. We use the bucket endpoint and let CloudFront handle index.html routing via `default_root_object`.

## Issues Encountered

**AccessDenied from CloudFront**
After apply, CloudFront returned 403 AccessDenied. Debugging steps:
- Checked curl headers — `server: AmazonS3` confirmed S3 was rejecting the request, not CloudFront
- Verified bucket policy was correct
- Found root cause: missing `default_root_object = "index.html"` in CloudFront distribution
- Without it, CloudFront requests `/` from S3, S3 finds no file named `/`, returns 403

**Website configuration conflict**
Initially had `aws_s3_bucket_website_configuration` enabled alongside OAC. These two conflict — website endpoint does not support OAC authentication. Removed website configuration and let CloudFront handle routing instead.

## What I Learned

- `default_root_object` is mandatory for static sites with CloudFront + private S3
- Reading curl response headers tells you exactly where in the chain a failure happens
- `server: AmazonS3` in headers means S3 responded — useful for pinpointing errors
- `x-cache: Miss` means fetched from S3 fresh, `x-cache: Hit` means served from edge cache
- CloudFront invalidation clears cached content at edge locations after updates
- Website endpoint and bucket endpoint serve different purposes and cannot be mixed with OAC