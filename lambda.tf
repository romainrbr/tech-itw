locals {
  # Path where the python script is located
  lambda_src_path = "./src/"
}
# bucket creation to store the gbfs files
resource "aws_s3_bucket" "gbfs_bucket" {
  bucket        = "gbfsdata"
  acl           = "private"
  force_destroy = var.wipe_bucket_on_destroy
}

# Create a hash to see if source files changed
resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(local.lambda_src_path, "*.py"),
      fileset(local.lambda_src_path, "requirements.txt"),
      fileset(local.lambda_src_path, "core/**/*.py")
    ) :
    filename => filemd5("${local.lambda_src_path}/${filename}")
  }
}

# Install python dependencies using local pip
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ${local.lambda_src_path}/requirements.txt -t ${local.lambda_src_path}/ --upgrade"
  }
  triggers = {
    dependencies_versions = filemd5("${local.lambda_src_path}/requirements.txt")
  }
}

# Zip all files for Lambda upload
data "archive_file" "lambda_source_package" {
  type        = "zip"
  source_dir  = local.lambda_src_path
  output_path = "${path.module}/.tmp/${random_uuid.lambda_src_hash.result}.zip"
  excludes = [
    "__pycache__",
    "core/__pycache__",
    "tests.py",
    "testFiles/",
    "requirements-tests.txt"
  ]
  depends_on = [null_resource.install_dependencies]
}

# Create an IAM execution role for the Lambda function.
resource "aws_iam_role" "execution_role" {
  name = "lambda-execution-role-ingest_gbfs_data-${var.aws_region}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    provisioner = "terraform"
  }
}

# Allows Lambda to stream logs to Cloudwatch Logs.
resource "aws_iam_role_policy" "log_writer" {
  name = "lambda-log-writer-ingest_gbfs_data"
  role = aws_iam_role.execution_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# Allows our Lambda script to write to S3
resource "aws_iam_role_policy" "s3_put" {
  name = "lambda-s3put-ingest_gbfs_data"
  role = aws_iam_role.execution_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:ListBucket"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::gbfsdata"
        ]
      }
    ]
  })
}


# Deploy the Lambda function to AWS
resource "aws_lambda_function" "ingestGBFSData" {
  for_each         = var.GBFS_endpoints
  function_name    = "ingestGBFSData_${each.key}"
  description      = "Ingest GBFS data from ${each.value.url} and store it on s3"
  role             = aws_iam_role.execution_role.arn
  filename         = data.archive_file.lambda_source_package.output_path
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  memory_size      = 128
  timeout          = 30
  source_code_hash = data.archive_file.lambda_source_package.output_base64sha256

  tags = {
    provisioner = "terraform"
  }

  environment {
    variables = {
      bucketName   = var.GBFS_bucket
      endpointUrl  = "${each.value.url}"
      endpointName = "${each.key}"
    }
  }
}

# Create a rule that fires every minute
resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "every_minute"
  description         = "Fires every minute"
  schedule_expression = "rate(1 minute)"
}


# Triggers the lambda script 
resource "aws_cloudwatch_event_target" "gbfstrigger" {
  for_each  = var.GBFS_endpoints
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = each.key
  arn       = aws_lambda_function.ingestGBFSData[each.key].arn
}

# Gives cloudwatch the permissions to invoke the lambda script
resource "aws_lambda_permission" "allow_cloudwatch_to_call_ingestGBFSData" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  for_each      = var.GBFS_endpoints
  function_name = "ingestGBFSData_${each.key}"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}


# Alerts when we have errors on gbfs parsing
resource "aws_cloudwatch_metric_alarm" "ingestGBFSDataFailing" {
  for_each            = var.GBFS_endpoints
  alarm_name          = "ingestGBFSDataFailing_${each.key}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  period              = "60"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Check if ingestGBFSData_${each.key} function is failing"
  dimensions = {
    FunctionName = "ingestGBFSData_${each.key}"
  }
  tags = {
    provisioner = "terraform"
  }
}