terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "assets_bucket" {
  bucket = var.bucket_name
}


# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_s3_ses_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_s3_ses_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}

# --- Bucket policy to allow Lambda read access to all objects ---
resource "aws_s3_bucket_policy" "allow_lambda_read" {
  bucket = aws_s3_bucket.assets_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowLambdaRead"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_exec.arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.assets_bucket.arn}/*"
      }
    ]
  })
}


# --- Package Lambda code ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "email_sender" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "send_s3_asset_email"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "send_email.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 1024 
  timeout       = 30
  
  environment {
    variables = {
      SENDER_EMAIL     = var.sender_email
      RECIPIENT_EMAILS = join(",", var.recipient_emails)
    }
  }
}


# --- Trigger Lambda on S3 Object Create ---
resource "aws_s3_bucket_notification" "notify_lambda" {
  bucket = aws_s3_bucket.assets_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.email_sender.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}


resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_sender.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets_bucket.arn
}

