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

variable "aws_region" {
  description = "AWS region for all resources in this example."
  type        = string
}

variable "logical_product_family" {
  description = "Logical product family for resource naming."
  type        = string
}

variable "logical_product_service" {
  description = "Logical product service for resource naming."
  type        = string
}

variable "class_env" {
  description = "Class environment segment for resource naming."
  type        = string
}

variable "instance_env" {
  description = "Instance environment number (0–999) for resource naming."
  type        = number

  validation {
    condition     = var.instance_env >= 0 && var.instance_env <= 999
    error_message = "instance_env must be between 0 and 999."
  }
}

variable "instance_resource" {
  description = "Instance resource number (0–100) for resource naming."
  type        = number

  validation {
    condition     = var.instance_resource >= 0 && var.instance_resource <= 100
    error_message = "instance_resource must be between 0 and 100."
  }
}

variable "resource_names_map" {
  description = "Map of resource naming module instances (keys used as for_each keys)."
  type = map(object({
    name       = string
    max_length = number
  }))
}

variable "tags" {
  description = "Tags applied to taggable resources."
  type        = map(string)
  default     = {}
}

variable "max_receive_count" {
  description = "Maximum receives before messages move to the dead-letter queue (passed through the module redrive policy)."
  type        = number
  default     = 2

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000 for standard queues."
  }
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for the main queue (lower values speed up functional tests)."
  type        = number
  default     = 5

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200."
  }
}
