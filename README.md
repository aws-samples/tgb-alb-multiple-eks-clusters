## How to leverage Application Load Balancer's advanced request routing to route application traffic across multiple Amazon EKS Clusters

This project shows the steps involved to implement the solution architecture explained in the [How to leverage Application Load Balancer’s advanced request routing to route application traffic across multiple Amazon EKS clusters](https://aws.amazon.com/blogs/containers/how-to-leverage-application-load-balancers-advanced-request-routing-to-route-application-traffic-across-multiple-amazon-eks-clusters/).

## Prerequisites

- [ ] A machine which has access to AWS and Kubernetes API server.
- [ ] You need the following tools on the client machine.
	- [ ] [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
   	- [ ] [eksctl](https://eksctl.io/installation/)
  	- [ ] [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
  	- [ ] [Helm](https://helm.sh/docs/intro/install/)
  	- [ ] [kubectx](https://github.com/ahmetb/kubectx) - Optional

Assumption : You already configured a [default] in the AWS CLI config/credentials files.

## Solution

### Step 1 - Clone this GitHub repo to your machine:

```bash
git clone https://github.com/aws-samples/tgb-alb-multiple-eks-clusters.git
cd tgb-alb-multiple-eks-clusters
```

Using AWS CloudFormation [cfn.yaml](/templates/cfn.yaml) stack, we configure the advanced request routing on the ALB. Explore [ListenerRule1](https://github.com/aws-samples/tgb-alb-multiple-eks-clusters/blob/e2a46793ece3473b31d9cf73d545ffc74a818aa8/cfn.yaml#L265) and [ListenerRule2](https://github.com/aws-samples/tgb-alb-multiple-eks-clusters/blob/e2a46793ece3473b31d9cf73d545ffc74a818aa8/cfn.yaml#L280C1-L280C1), which implements the http header based forwarding rule definitions. This provides the foundation to forward particular http requests to different target groups.

### Step 2 - Create CloudFormation Stack:

```bash
aws cloudformation create-stack --stack-name awsblogstack --template-body file://template/cfn.yaml
```

If you prefer to use your own values for the parameters in the stack then please use the `--parameters` option with the above command followed by `ParameterKey=KeyPairName, ParameterValue=TestKey`.

### Step 3 - Check the status of the CloudFormation stack:

```bash
watch aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].StackStatus" --output text
```

Once the output shows `CREATE_COMPLETE` you can move on to the next step. Exit using `CTRL + C`. 

For easier reference you can navigate to the CloudFormation service console and see which resources are created. At a high level the resources created are a VPC, two public subnets, two private subnets, two target groups, an Application Load Balancer with a listener and two listener rules. The rules configured on the ALB are shown below. 

![listener_rules_image](/images/listenerrules.png)

### Step 4 - Set environment variables:

```bash
source config_files/env.sh
```

### Step 5 - Embed environment variables into the eksctl cluster config file for `cluster1`:

```bash
envsubst < config_files/cluster1_template.yaml > config_files/cluster1.yaml
```

Cluster config manifests are configured with minimum information. In its current state it deploys EKS v1.28 and the worker nodes use Amazon Linux 2 OS.

### Step 6 - Create `cluster1`:

```bash
eksctl create cluster -f config_files/cluster1.yaml
```

It takes 15 minutes for an EKS cluster creation to be ready. You can either start creating `Cluster2` in a separate shell immediately (#14 below); or wait for `Cluster1` creation process to complete before moving on to the next step. If you choose to create `Cluster2` immediately then **do not forget** to source the env.sh file again in that other terminal window before attempting to create Cluster2.

### Step 7 - Update `kubeconfig` file to access `cluster1`:

```bash
aws eks update-kubeconfig --name cluster1 
```

Verify that the worker nodes status is `Ready` by doing `kubectl get nodes`. 

### Step 8 - Install AWS Load Balancer Controller on `cluster1`:

```bash
source config_files/aws_load_balancer_controller_cluster1.sh
```
If you see an error such as `A policy called AWSLoadBalancerControllerIAMPolicy already exists. Duplicate names are not allowed.` you can safely ignore it. Once the step completes you should see `AWS Load Balancer Controller installed!`

### Step 9 - Deploy the application pods and service on `cluster1`:

```bash
kubectl apply -f config_files/cluster1_app.yaml
```

### Step 10 - Create `TargetGroupBinding` custom resource on `cluster1`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: service1-tgb
spec:
  serviceRef:
    name: service1
    port: 80
  targetGroupARN: ${TargetGroup1ARN}
EOF
```

### Step 11 - Verify the Pods in `cluster1` are registered as Targets in `TargetGroup1` on ALB:

The Pod IPs should match the Target IPs. Verify that by using the commands shown below.

```bash
kubectl get pods -o wide
aws elbv2 describe-target-health --target-group-arn ${TargetGroup1ARN}  --query "TargetHealthDescriptions[*].Target.Id"
```

At this stage the targets will be `Unhealthy`. The reason is explained in the next step.

### Step 12 - Add ingress rule to the worker node security group for `cluster1`:

The node security group by default only allows communication from the EKS control plane. Pods are also part the node security group hence we need to allow TCP port 80. 

```bash
export Cluster1NodeSecurityGroupId=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'eks-cluster-sg-cluster1')].GroupId" --output text)
export ALBSecurityGroupId=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'ALBSecurityGroup')].GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id ${Cluster1NodeSecurityGroupId} --protocol tcp --port 80 --source-group ${ALBSecurityGroupId}
```

Alternatively you can use [Security Group for Pods](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html). For simplicity it is not demonstrated here.

Verify that the targets are now `Healthy`. 

```bash
aws elbv2 describe-target-health --target-group-arn ${TargetGroup1ARN}  --query "TargetHealthDescriptions[*].TargetHealth" --output text
```

### Step 13 - Verify access to the `service1`:

Examine the pre-configured forwarding rules on the AWS Application Load Balancer through AWS console or AWS CLI. Then perform the following command which sets a cookie as `user=user1`.

```bash
curl --cookie "user=user1" $ALBDNSNAME
```

Sample Output
```
<html>
  <head>
    <title> Welcome to Amazon EKS </title>
  </head>
  <body>
    <h1> You are accessing the application in cluster1 </h1>
    <h3> Knowledge is valuable only when it is shared. </h3>
  </body>
</html
```

If you do not use any cookies in the request then a fixed page shows up with the content `You did not specify a user-id. This is a fixed response`. 

### Step 14 - Embed environment variables into the eksctl cluster config file for `cluster2`:

```bash
envsubst < config_files/cluster2_template.yaml > config_files/cluster2.yaml
```

Cluster config manifests are configured with minimum information. In its current state it deploys EKS v1.28 and the worker nodes use Amazon Linux 2 OS.

### Step 15 - Create `cluster2`:

```bash
eksctl create cluster -f config_files/cluster2.yaml
```

### Step 16 - Update `kubeconfig` file to access `cluster2`:

```bash
aws eks update-kubeconfig --name cluster2
```

Use `kubectl config current-context` to make sure kubeconfig context is set to cluster2. 

### Step 17 - Install AWS Load Balancer Controller on `cluster2`:

```bash
source config_files/aws_load_balancer_controller_cluster2.sh
```

If you see an error such as `A policy called AWSLoadBalancerControllerIAMPolicy already exists. Duplicate names are not allowed.` you can safely ignore it. Once the step completes you should see `AWS Load Balancer Controller installed!`

### Step 18 - Deploy the application pods and service on `cluster2`:

```bash
kubectl apply -f config_files/cluster2_app.yaml
```

### Step 19 - Create `TargetGroupBinding` custom resource on `cluster2`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: service2-tgb
spec:
  serviceRef:
    name: service2
    port: 80
  targetGroupARN: ${TargetGroup2ARN}
EOF
```

### Step 20 - Verify the Pods in `cluster2` are registered as Targets in `TargetGroup2` on ALB:

The Pod IPs should match the Target IPs. Verify that by using the commands shown below.

```bash
kubectl get pods -o wide
aws elbv2 describe-target-health --target-group-arn ${TargetGroup2ARN}  --query "TargetHealthDescriptions[*].Target.Id"
```

At this stage the targets will be `Unhealthy`. The reason is explained in the next step.

### Step 21 - Add ingress rule to the worker node security group for `cluster2`:

The node security group by default only allows communication from the EKS control plane. Pods are also part the node security group hence we need to allow TCP port 80. 

```bash
export Cluster2NodeSecurityGroupId=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'eks-cluster-sg-cluster2')].GroupId" --output text)
export ALBSecurityGroupId=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'ALBSecurityGroup')].GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id ${Cluster2NodeSecurityGroupId} --protocol tcp --port 80 --source-group ${ALBSecurityGroupId}
```

Alternatively you can use [Security Group for Pods](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html). For simplicity purposes this feature is not demonstrated here.

Verify that the targets are now `Healthy`. 

```bash
aws elbv2 describe-target-health --target-group-arn ${TargetGroup2ARN}  --query "TargetHealthDescriptions[*].TargetHealth" --output text
```

### Step 22 - Verify access to the `service2`:

Examine the pre-configured forwarding rules on the AWS Application Load Balancer through AWS console or AWS CLI. Then perform the following command which sets a cookie as `user=user2`.

```bash
curl --cookie "user=user2" $ALBDNSNAME
```

Sample Output
```
<html>
  <head>
    <title> Welcome to Amazon EKS </title>
  </head>
  <body>
    <h1> You are accessing the application in cluster2 </h1>
    <h3> Knowledge is valuable only when it is shared. </h3>
  </body>
</html
```

If you do not use any cookies in the request then a fixed page shows up with the content `You did not specify a user-id. This is a fixed response`. 

## Clean-up

### Step 1 - Delete `cluster1`:

```bash
eksctl delete cluster --name cluster1
```

You can either wait for the `cluster1` to be deleted succesfully (which takes ~10 minutes) or you can move on to the next step immediately. 

### Step 1 - Delete `cluster2`:

In a separate terminal window start the process to delete `cluster2`

```bash
eksctl delete cluster --name cluster2
```

It will take approximately 10 minutes for the deletion process to be completed successfully.

### Step 3 - Delete CloudFormation stack `awsblogstack`:

```bash
aws cloudformation delete-stack --stack-name awsblogstack
```

- Watch the CloudFormation stack

```bash
watch aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].StackStatus" --output text
```

Once the output shows `DELETE_COMPLETE` that means the whole environment is deleted. Keep in mind that after it completes you will start seeing an error message stating that the stack does not exist. 

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
