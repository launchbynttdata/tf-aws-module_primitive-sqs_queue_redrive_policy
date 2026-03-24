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

output "aws_region" {
  description = "AWS region used for the example."
  value       = var.aws_region
}

output "main_queue_url" {
  description = "URL of the main SQS queue."
  value       = aws_sqs_queue.main.url
}

output "dlq_queue_url" {
  description = "URL of the dead-letter queue."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue."
  value       = aws_sqs_queue.dlq.arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed key encrypting the queues."
  value       = aws_kms_key.sqs.arn
}

output "max_receive_count" {
  description = "Configured maxReceiveCount in the redrive policy."
  value       = var.max_receive_count
}

output "visibility_timeout_seconds" {
  description = "Main queue visibility timeout."
  value       = var.visibility_timeout_seconds
}

output "redrive_policy_id" {
  description = "Redrive policy resource id from the primitive module."
  value       = module.sqs_queue_redrive_policy.id
}

output "redrive_policy_json" {
  description = "Redrive policy JSON from the primitive module."
  value       = module.sqs_queue_redrive_policy.redrive_policy
}
