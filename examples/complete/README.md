# Complete example: SQS queue redrive policy

Creates a customer-managed KMS key, two encrypted SQS queues (main and dead-letter), and attaches a redrive policy to the main queue using this module.

## Usage

The following matches [`main.tf`](./main.tf):

```hcl
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
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_names"></a> [resource\_names](#module\_resource\_names) | terraform.registry.launch.nttdata.com/module_library/resource_name/launch | ~> 2.0 |
| <a name="module_sqs_queue_redrive_policy"></a> [sqs\_queue\_redrive\_policy](#module\_sqs\_queue\_redrive\_policy) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [random_string.kms_alias_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for all resources in this example. | `string` | n/a | yes |
| <a name="input_class_env"></a> [class\_env](#input\_class\_env) | Class environment segment for resource naming. | `string` | n/a | yes |
| <a name="input_instance_env"></a> [instance\_env](#input\_instance\_env) | Instance environment number (0–999) for resource naming. | `number` | n/a | yes |
| <a name="input_instance_resource"></a> [instance\_resource](#input\_instance\_resource) | Instance resource number (0–100) for resource naming. | `number` | n/a | yes |
| <a name="input_logical_product_family"></a> [logical\_product\_family](#input\_logical\_product\_family) | Logical product family for resource naming. | `string` | n/a | yes |
| <a name="input_logical_product_service"></a> [logical\_product\_service](#input\_logical\_product\_service) | Logical product service for resource naming. | `string` | n/a | yes |
| <a name="input_max_receive_count"></a> [max\_receive\_count](#input\_max\_receive\_count) | Maximum receives before messages move to the dead-letter queue (passed through the module redrive policy). | `number` | `2` | no |
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | Map of resource naming module instances (keys used as for\_each keys). | <pre>map(object({<br/>    name       = string<br/>    max_length = number<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to taggable resources. | `map(string)` | `{}` | no |
| <a name="input_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#input\_visibility\_timeout\_seconds) | Visibility timeout for the main queue (lower values speed up functional tests). | `number` | `5` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_region"></a> [aws\_region](#output\_aws\_region) | AWS region used for the example. |
| <a name="output_dlq_arn"></a> [dlq\_arn](#output\_dlq\_arn) | ARN of the dead-letter queue. |
| <a name="output_dlq_queue_url"></a> [dlq\_queue\_url](#output\_dlq\_queue\_url) | URL of the dead-letter queue. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the customer managed key encrypting the queues. |
| <a name="output_main_queue_url"></a> [main\_queue\_url](#output\_main\_queue\_url) | URL of the main SQS queue. |
| <a name="output_max_receive_count"></a> [max\_receive\_count](#output\_max\_receive\_count) | Configured maxReceiveCount in the redrive policy. |
| <a name="output_redrive_policy_id"></a> [redrive\_policy\_id](#output\_redrive\_policy\_id) | Redrive policy resource id from the primitive module. |
| <a name="output_redrive_policy_json"></a> [redrive\_policy\_json](#output\_redrive\_policy\_json) | Redrive policy JSON from the primitive module. |
| <a name="output_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#output\_visibility\_timeout\_seconds) | Main queue visibility timeout. |
<!-- END_TF_DOCS -->
