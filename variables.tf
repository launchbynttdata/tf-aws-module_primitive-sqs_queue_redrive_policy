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

variable "queue_url" {
  description = "The URL of the SQS queue to which the redrive policy attribute is applied."
  type        = string
}

variable "redrive_policy" {
  description = <<-EOT
    JSON document defining the redrive policy. Must include deadLetterTargetArn (ARN of the dead-letter queue)
    and maxReceiveCount (1–10 for FIFO queues; 1–1,000 for standard queues) per Amazon SQS documentation.
  EOT
  type        = string

  validation {
    condition     = can(jsondecode(var.redrive_policy))
    error_message = "redrive_policy must be valid JSON."
  }

  validation {
    condition = try(
      length(jsondecode(var.redrive_policy).deadLetterTargetArn) > 0 &&
      can(tonumber(jsondecode(var.redrive_policy).maxReceiveCount)),
      false,
    )
    error_message = "redrive_policy JSON must include non-empty deadLetterTargetArn and numeric maxReceiveCount."
  }

  validation {
    condition = try(
      tonumber(jsondecode(var.redrive_policy).maxReceiveCount) >= 1 &&
      tonumber(jsondecode(var.redrive_policy).maxReceiveCount) <= 1000,
      false,
    )
    error_message = "maxReceiveCount must be between 1 and 1000 (standard queue maximum per AWS; FIFO queues allow up to 10)."
  }
}
