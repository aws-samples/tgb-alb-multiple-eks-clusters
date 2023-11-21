export AccountId=$(aws sts get-caller-identity --query "Account" --output text)

export EnvironmentName=$(aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].Parameters[?ParameterKey == 'EnvironmentName'].ParameterValue" --output text)

export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query "AvailabilityZones[0].[RegionName]")

export TargetGroup1ARN=$(aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].Outputs[?contains(OutputKey, 'TargetGroup1ARN')].OutputValue" --output text)

export TargetGroup2ARN=$(aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].Outputs[?contains(OutputKey, 'TargetGroup2ARN')].OutputValue" --output text)

export PrivateSubnet1=$(aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].Outputs[?contains(OutputKey, 'PrivateSubnet1')].OutputValue" --output text)

export PrivateSubnet2=$(aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].Outputs[?contains(OutputKey, 'PrivateSubnet2')].OutputValue" --output text)

export Cluster1Name=cluster1

export Cluster2Name=cluster2

