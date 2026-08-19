# tf-aws-module_primitive-sqs_queue_redrive_policy

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC_BY--NC--ND_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

## Overview

Terraform primitive module for the [`aws_sqs_queue_redrive_policy`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_policy) resource. Use it to attach a redrive (dead-letter) policy to an existing SQS queue after the dead-letter queue already exists.

## Usage

```hcl
module "sqs_queue_redrive_policy" {
  source = "path/to/module"

  queue_url = aws_sqs_queue.main.url
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}
```

See [`examples/complete`](./examples/complete) for a full example with customer-managed KMS encryption on the queues.

## Development

- Run `make configure` to sync shared automation components (requires [repo](https://gerrit.googlesource.com/git-repo/) and git identity).
- Override Makefile variables via [`.lcafenv`](./.lcafenv) if needed.
- Post-deploy tests live under [`tests/`](./tests) and target `examples/complete` with `test.tfvars`.

Pull request checks use [launch-workflows](https://github.com/launchbynttdata/launch-workflows/tree/main/docs) reusable workflows; configure AWS OIDC secrets and variables for your organization if you run them outside `launchbynttdata`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_sqs_queue_redrive_policy.sqs_queue_redrive_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_queue_url"></a> [queue\_url](#input\_queue\_url) | The URL of the SQS queue to which the redrive policy attribute is applied. | `string` | n/a | yes |
| <a name="input_redrive_policy"></a> [redrive\_policy](#input\_redrive\_policy) | JSON document defining the redrive policy. Must include deadLetterTargetArn (ARN of the dead-letter queue)<br/>and maxReceiveCount (1–10 for FIFO queues; 1–1,000 for standard queues) per Amazon SQS documentation. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | The queue URL (same as queue\_url). |
| <a name="output_queue_url"></a> [queue\_url](#output\_queue\_url) | The URL of the SQS queue. |
| <a name="output_redrive_policy"></a> [redrive\_policy](#output\_redrive\_policy) | The redrive policy JSON applied to the queue. |
<!-- END_TF_DOCS -->
