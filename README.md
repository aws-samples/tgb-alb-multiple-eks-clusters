## How to leverage Application Load Balancer's advanced request routing to route application traffic across multiple Amazon EKS Clusters

This project shows the implementation steps of the solution architecture explained in the [AWS Blog]().

## Prerequisites

- A client machine which has access to AWS and Kubernetes API server.
- You need the following tools on the client machine.
	- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
   	- [eksctl](https://eksctl.io/installation/)
  	- [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
  	- [Helm](https://helm.sh/docs/intro/install/)
  	- [kubectx](https://github.com/ahmetb/kubectx) - Optional

All the shell commands shown below are based on the assumption that you use the default profile in your AWS CLI config.

## Solution

1. Create CloudFormation Stack

```bash
aws cloudformation create-stack --stack-name awsblogstack --template-body file://cfn.yaml
```

If you prefer to use your own values for the parameters in the stack then please use the `--parameters` option with the above command followed by `ParameterKey=KeyPairName, ParameterValue=TestKey`.

2. Check the status of the CloudFormation stack

```bash
watch aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].StackStatus" --output text
```

Once the output shows `CREATE_COMPLETE` you can move on to next step. Exit using `CTRL + C`. 

3. Set environment variables

```bash
source env.sh
```

4. Prepare the eksctl cluster config manifests

```bash
envsubst < cluster1_template.yaml > cluster1.yaml
envsubst < cluster2_template.yaml > cluster2.yaml
```

Cluster config manifests are configured with minimum information. In its current state it deploys EKS v1.28 and the worker nodes use Amazon Linux 2 OS.

5. Create `cluster1`

```bash
eksctl create cluster -f cluster1.yaml
```

It takes 15 minutes for an EKS cluster creation to be ready. You can either start creating `Cluster2` in a separate shell immediately ([Step X]()); or wait for `Cluster1` creation process to complete before moving on to the next step. If you choose to create `Cluster2` immediately then **do not forget** to source the env.sh file again in that other terminal window before attempting to create Cluster2.

6. Update `kubeconfig` file to access `cluster1`

```bash
aws eks update-kubeconfig --name cluster1 
```

Verify that the worker nodes status is `ready` by doing `kubectl get nodes`. 

7. Install AWS Load Balancer Controller on `cluster1`

```bash
source aws_load_balancer_controller_cluster1.sh
```

8. Deploy the application pods and service on `cluster1`

```bash
kubectl apply -f cluster1_app.yaml
```

9. Create `TargetGroupBinding` custom resource on `cluster1`

```bash
cat <<EOF | kubectl apply -f -
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: test1-service-tgb
spec:
  serviceRef:
    name: test1service
    port: 80
  targetGroupARN: ${TargetGroup1ARN}
EOF
```

10. 

11. Add ingressrule to the worker node security group for `cluster1`

```bash
export NodeSecurityGroupId=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'eks-cluster-sg-cluster1')].GroupId" --output text)
export ALBSecurityGroupId=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'ALBSecurityGroup')].GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id ${NodeSecurityGroupId} --protocol tcp --port 80 --source-group ${ALBSecurityGroupId}
```


12. Create `cluster2`

```bash
eksctl create cluster -f cluster2.yaml
```

13. Update `kubeconfig` file to access `cluster2`

```bash
aws eks update-kubeconfig --name cluster2
```

Use `kubectl config current-context` to make sure you are in cluster2 context. 

14. Install AWS Load Balancer Controller on `cluster2`

```bash
source aws_load_balancer_controller_cluster2.sh
```

15. Deploy the application pods and service on `cluster2`

```bash
kubectl apply -f cluster2_app.yaml
```

16. Create `TargetGroupBinding` custom resource on `cluster2`

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

## Clean-up

- delete sg rules
- delete clusters


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

