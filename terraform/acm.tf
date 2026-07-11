resource "aws_acm_certificate" "app" {
  domain_name       = "alamos.fw-binzen.de"
  validation_method = "EMAIL"

  subject_alternative_names = [
    "alamos.fw-binzen.de",
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn = aws_acm_certificate.app.arn
}
