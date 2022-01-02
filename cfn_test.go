package cloudformation

import (
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation/types"
	cfn "github.com/natemarks/awsgrips/cloudformation"
)

func TestCreateStack(t *testing.T) {
	type args struct {
		input *cloudformation.CreateStackInput
	}
	tests := []struct {
		name        string
		args        args
		wantStackId string
		wantErr     bool
	}{
		{name: "valid", args: args{input: &cloudformation.CreateStackInput{
			StackName:                   aws.String("cfn-vnc-test-create-stack-valid"),
			Capabilities:                nil,
			ClientRequestToken:          nil,
			DisableRollback:             nil,
			EnableTerminationProtection: nil,
			NotificationARNs:            nil,
			OnFailure:                   "",
			Parameters:                  []types.Parameter{{ParameterKey: aws.String("BucketName"), ParameterValue: aws.String("natemarks-test-create-stack-valid-2874gf8b24byv")}},
			ResourceTypes:               nil,
			RoleARN:                     nil,
			RollbackConfiguration:       nil,
			StackPolicyBody:             nil,
			StackPolicyURL:              nil,
			Tags:                        []types.Tag{{Key: aws.String("deleteme"), Value: aws.String("true")}},
			TemplateBody:                nil,
			TemplateURL:                 aws.String("https://natemarks-cloudformation-public.s3.amazonaws.com/cfn-s3buckets/private.json"),
			TimeoutInMinutes:            nil,
		}},
			wantErr:     false,
			wantStackId: "cfn-vnc-test-create-stack-valid"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotStackId, err := cfn.CreateStack(tt.args.input)
			_ = cfn.CreateStackWait(tt.wantStackId, 5)
			if (err != nil) != tt.wantErr {
				t.Errorf("CreateStack() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !strings.Contains(gotStackId, tt.wantStackId) {
				t.Errorf("CreateStack() gotStackId does not contain stack name: %v", tt.wantStackId)
			}
		})
		_ = cfn.DeleteStack(tt.wantStackId)
	}
}
