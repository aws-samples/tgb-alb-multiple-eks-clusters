## How to leverage Application Load Balancer's advanced request routing to route application traffic across multiple Amazon EKS Clusters

This project shows the implementation steps of the solution architecture explained in the [AWS Blog]().

## Prerequisites

- A client machine which has access to AWS and Kubernetes API server.
- You need the following tools on the client machine.
	- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
  	- [eksctl](https://eksctl.io/installation/)
  	- [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
  	- [Helm](https://helm.sh/docs/intro/install/)

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## Solution

1. Create CloudFormation Stack

```bash
aws cloudformation create-stack --stack-name awsblogstack --template-body file://cfn.yml
```

**Note :** User can provide their own values for the parameters in the stack by using `--parameters` option followed by `ParameterKey=KeyPairName, ParameterValue=TestKey`

2. Watch the status of the stack

```bash
watch aws cloudformation describe-stacks --stack-name awsblogstack --query "Stacks[0].StackStatus" --output text
```
3. Set environment variables

```bash
source env.sh
```

4. Prepare the eksctl cluster config manifests

```bash
envsubst < cluster1_template.yml > cluster1.yml
envsubst < cluster2_template.yml > cluster2.yml
```

5. Create eks `Cluster1`

```bash
eksctl create cluster -f cluster1.yml
```

**Note :** Cluster creation and nodes to get ready takes 15 minutes.

**Note :** You can create `Cluster2` in a separate terminal window simultaneously otherwise you need to wait for `Cluster1` to be ready before moving to the next step. Do not forget to source the env.sh file again in that other terminal window before attempting to create Cluster2.

6. Create eks `Cluster2`

```bash
eksctl create cluster -f cluster2.yml
```

7. Update `kubeconfig` file

```bash
aws eks update-kubeconfig --name Cluster1 
aws eks update-kubeconfig --name Cluster2
```

8. 


 

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

