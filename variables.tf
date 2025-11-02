variable "aws_region" {
  default = "my-region"
}

variable "bucket_name" {
  default = "my-bucket"
}

variable "sender_email" {
  description = "SES verified sender email"
  default     = "yaswanth1655@gmail.com"
}

variable "recipient_emails" {
  type        = list(string)
  description = "List of recipient emails"
  default     = ["beingyaswanth27@gmail.com"]
}
