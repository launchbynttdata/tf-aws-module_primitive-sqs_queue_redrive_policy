package testimpl

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	sqstypes "github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	terratesttypes "github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type redrivePolicyDoc struct {
	DeadLetterTargetArn string `json:"deadLetterTargetArn"`
	MaxReceiveCount     int    `json:"maxReceiveCount"`
}

func awsSQSClient(t *testing.T, region string) *sqs.Client {
	t.Helper()

	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	require.NoError(t, err, "load AWS config")

	return sqs.NewFromConfig(cfg)
}

func getQueueAttribute(t *testing.T, client *sqs.Client, queueURL string, name sqstypes.QueueAttributeName) string {
	t.Helper()

	out, err := client.GetQueueAttributes(context.Background(), &sqs.GetQueueAttributesInput{
		QueueUrl:       aws.String(queueURL),
		AttributeNames: []sqstypes.QueueAttributeName{name},
	})
	require.NoError(t, err, "GetQueueAttributes %s", name)

	v, ok := out.Attributes[string(name)]
	require.True(t, ok, "attribute %s must be present", name)

	return v
}

func parseRedrivePolicy(t *testing.T, raw string) redrivePolicyDoc {
	t.Helper()

	var doc redrivePolicyDoc
	require.NoError(t, json.Unmarshal([]byte(raw), &doc), "redrive policy JSON")

	return doc
}

func assertRedriveAndKMSSettings(
	t *testing.T,
	client *sqs.Client,
	mainQueueURL string,
	dlqARN string,
	expectedMaxReceive int,
	expectedKMSKeyARN string,
) {
	t.Helper()

	raw := getQueueAttribute(t, client, mainQueueURL, sqstypes.QueueAttributeNameRedrivePolicy)
	doc := parseRedrivePolicy(t, raw)
	assert.Equal(t, dlqARN, doc.DeadLetterTargetArn, "deadLetterTargetArn should match DLQ ARN")
	assert.Equal(t, expectedMaxReceive, doc.MaxReceiveCount, "maxReceiveCount should match configuration")

	kmsMain := getQueueAttribute(t, client, mainQueueURL, sqstypes.QueueAttributeNameKmsMasterKeyId)
	require.True(t, len(kmsMain) > 0, "main queue must expose KMS master key id")
	assert.Equal(t, expectedKMSKeyARN, kmsMain, "main queue KMS key should match Terraform output")
}

func TestComposableComplete(t *testing.T, ctx terratesttypes.TestContext) {
	t.Parallel()

	opts := ctx.TerratestTerraformOptions()
	region := terraform.Output(t, opts, "aws_region")
	mainURL := terraform.Output(t, opts, "main_queue_url")
	dlqURL := terraform.Output(t, opts, "dlq_queue_url")
	dlqARN := terraform.Output(t, opts, "dlq_arn")
	kmsKeyARN := terraform.Output(t, opts, "kms_key_arn")
	maxReceiveStr := terraform.Output(t, opts, "max_receive_count")
	visibilityStr := terraform.Output(t, opts, "visibility_timeout_seconds")
	expectedRedriveJSON := terraform.Output(t, opts, "redrive_policy_json")

	maxReceive, err := strconv.Atoi(maxReceiveStr)
	require.NoError(t, err)

	visibilitySeconds, err := strconv.Atoi(visibilityStr)
	require.NoError(t, err)

	client := awsSQSClient(t, region)

	t.Run("outputsMatchAPI", func(t *testing.T) {
		assertRedriveAndKMSSettings(t, client, mainURL, dlqARN, maxReceive, kmsKeyARN)

		apiRedrive := getQueueAttribute(t, client, mainURL, sqstypes.QueueAttributeNameRedrivePolicy)
		assert.JSONEq(t, expectedRedriveJSON, apiRedrive, "API RedrivePolicy should match module output JSON")
	})

	t.Run("messageRedrivesToDLQ", func(t *testing.T) {
		body := fmt.Sprintf("terratest-redrive-%d", time.Now().UnixNano())
		_, err := client.SendMessage(context.Background(), &sqs.SendMessageInput{
			QueueUrl:    aws.String(mainURL),
			MessageBody: aws.String(body),
		})
		require.NoError(t, err, "SendMessage")

		// Receive without deleting until SQS moves the message to the DLQ.
		for range maxReceive + 3 {
			out, err := client.ReceiveMessage(context.Background(), &sqs.ReceiveMessageInput{
				QueueUrl:            aws.String(mainURL),
				MaxNumberOfMessages: 1,
				WaitTimeSeconds:     20,
				VisibilityTimeout:   int32(visibilitySeconds),
			})
			require.NoError(t, err)

			if len(out.Messages) == 0 {
				break
			}

			time.Sleep(time.Duration(visibilitySeconds+2) * time.Second)
		}

		var dlqBody string
		require.Eventually(t, func() bool {
			out, err := client.ReceiveMessage(context.Background(), &sqs.ReceiveMessageInput{
				QueueUrl:            aws.String(dlqURL),
				MaxNumberOfMessages: 1,
				WaitTimeSeconds:     5,
			})
			if err != nil || len(out.Messages) == 0 {
				return false
			}
			dlqBody = aws.ToString(out.Messages[0].Body)
			return true
		}, 3*time.Minute, 5*time.Second, "message should arrive in DLQ")

		assert.Equal(t, body, dlqBody, "DLQ message body should match sent payload")
	})
}

func TestComposableCompleteReadonly(t *testing.T, ctx terratesttypes.TestContext) {
	t.Parallel()

	opts := ctx.TerratestTerraformOptions()
	region := terraform.Output(t, opts, "aws_region")
	mainURL := terraform.Output(t, opts, "main_queue_url")
	dlqURL := terraform.Output(t, opts, "dlq_queue_url")
	dlqARN := terraform.Output(t, opts, "dlq_arn")
	kmsKeyARN := terraform.Output(t, opts, "kms_key_arn")
	maxReceiveStr := terraform.Output(t, opts, "max_receive_count")
	expectedRedriveJSON := terraform.Output(t, opts, "redrive_policy_json")

	maxReceive, err := strconv.Atoi(maxReceiveStr)
	require.NoError(t, err)

	client := awsSQSClient(t, region)

	assertRedriveAndKMSSettings(t, client, mainURL, dlqARN, maxReceive, kmsKeyARN)

	apiRedrive := getQueueAttribute(t, client, mainURL, sqstypes.QueueAttributeNameRedrivePolicy)
	assert.JSONEq(t, expectedRedriveJSON, apiRedrive, "API RedrivePolicy should match module output JSON")

	kmsDlq := getQueueAttribute(t, client, dlqURL, sqstypes.QueueAttributeNameKmsMasterKeyId)
	require.True(t, len(kmsDlq) > 0, "DLQ must expose KMS master key id")
	assert.Equal(t, kmsKeyARN, kmsDlq, "DLQ KMS key should match Terraform output")
}
