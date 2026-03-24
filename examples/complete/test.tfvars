aws_region                 = "us-east-1"
logical_product_family     = "launch"
logical_product_service    = "sqsredrive"
class_env                  = "sandbox"
instance_env               = 1
instance_resource          = 1
max_receive_count          = 2
visibility_timeout_seconds = 5

resource_names_map = {
  main = {
    name       = "sqsqueue1"
    max_length = 80
  }
  dlq = {
    name       = "sqsqueue2"
    max_length = 80
  }
}

tags = {
  Example = "sqs_queue_redrive_policy_complete"
}
