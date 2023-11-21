## How to leverage Application Load Balancer's advanced request routing to route application traffic across multiple Amazon EKS Clusters

This project shows the implementation steps of the solution architecture explained in the [AWS Blog]().

## Prerequisites

- A client machine which has access to AWS and Kubernetes API server.
- You need the following tools on the client machine.
	- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
   	- [eksctl](https://eksctl.io/installation/)
  	- [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
  	- [Helm](https://helm.sh/docs/intro/install/)

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

It takes 15 minutes for an EKS cluster creation to be ready. You can either start creating `Cluster2` in a separate shell immediately; or can wait for `Cluster1` creation process to complete before moving on to the next step. If you choose to create `Cluster2` immediately then **do not forget** to source the env.sh file again in that other terminal window before attempting to create Cluster2.

6. Create `cluster2`

```bash
eksctl create cluster -f cluster2.yaml
```

7. Update `kubeconfig` file to access `cluster1`

```bash
aws eks update-kubeconfig --name cluster1 
```

Verify that the worker nodes status is `ready` by doing `kubectl get nodes`. 

8. Install AWS Load Balancer Controller on `cluster1`

```bash
eksctl utils associate-iam-oidc-provider --region ${AWS_REGION} --cluster ${Cluster1Name} --approve

curl -o iam-policy.json curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

eksctl create iamserviceaccount --cluster=${Cluster1Name} --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::${AccountId}:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --region ${AWS_REGION} --approve

helm repo add eks https://aws.github.io/eks-charts

helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${Cluster1Name} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
```

9. Update `kubeconfig` file to access `cluster2`

```bash
aws eks update-kubeconfig --name cluster2
```

10. Install AWS Load Balancer Controller on `cluster2`

```bash
eksctl utils associate-iam-oidc-provider --region ${AWS_REGION} --cluster ${Cluster1Name} --approve

curl -o iam-policy.json curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

eksctl create iamserviceaccount --cluster=${Cluster1Name} --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::${AccountId}:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --region ${AWS_REGION} --approve

helm repo add eks https://aws.github.io/eks-charts

helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${Cluster1Name} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

