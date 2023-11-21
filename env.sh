export AccountId=$(aws sts get-caller-identity --query "Account" --output text)

export EnvironmentName=$(aws cloudformation describe-stacks --stack-name awsblogstack --query 'Stacks[0].Parameters[?ParameterKey == `EnvironmentName`].ParameterValue' --output text)

export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')

export PrivateSubnet1=$(aws ec2 describe-subnets --filters "Name=tag:aws:cloudformation:logical-id,Values=PrivateSubnet1" --query "Subnets[*].SubnetId" --output text)

export PrivateSubnet2=$(aws ec2 describe-subnets --filters "Name=tag:aws:cloudformation:logical-id,Values=PrivateSubnet2" --query "Subnets[*].SubnetId" --output text)

export Cluster1Name=cluster1

export Cluster2Name=cluster2