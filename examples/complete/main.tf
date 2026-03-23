// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "resource_names" {
  source  = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version = "~> 2.0"

  for_each = var.resource_names_map

  logical_product_family  = var.logical_product_family
  logical_product_service = var.logical_product_service
  class_env               = var.class_env
  instance_env            = var.instance_env
  instance_resource       = var.instance_resource
  cloud_resource_type     = each.value.name
  maximum_length          = each.value.max_length

  region = join("", split("-", data.aws_region.current.name))
}

resource "random_string" "kms_alias_suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "EnableAccountRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSQS"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.resource_names["main"].standard}",
        "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.resource_names["dlq"].standard}",
      ]
    }
  }
}

resource "aws_kms_key" "sqs" {
  description             = "CMK for SQS queues (example for ${module.resource_names["main"].standard})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json

  tags = var.tags
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/sqs-rp-${random_string.kms_alias_suffix.result}"
  target_key_id = aws_kms_key.sqs.key_id
}

resource "aws_sqs_queue" "dlq" {
  name                              = module.resource_names["dlq"].standard
  kms_master_key_id                 = aws_kms_key.sqs.arn
  kms_data_key_reuse_period_seconds = 300

  tags = var.tags
}

resource "aws_sqs_queue" "main" {
  name                              = module.resource_names["main"].standard
  kms_master_key_id                 = aws_kms_key.sqs.arn
  kms_data_key_reuse_period_seconds = 300
  visibility_timeout_seconds        = var.visibility_timeout_seconds

  tags = var.tags
}

module "sqs_queue_redrive_policy" {
  source = "../.."

  queue_url = aws_sqs_queue.main.url
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}
