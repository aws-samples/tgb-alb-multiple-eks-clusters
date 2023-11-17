# AWS Blog - How to leverage Application Load Balancer's advanced request routing to route application traffic across multiple Amazon EKS Clusters

This project shows the implementation steps of the architecture explained in the AWS Blog.

## Step 1. Create two EKS clusters:

- Create Cluster 1:
```bash
cat environment/cluster1.yaml | envsubst | eksctl create cluster -f -
```

- Create Cluster 2:
```bash
cat environment/cluster1.yaml | envsubst | eksctl create cluster -f -
```
## Step 2. Create unique namespace for each cluster:

- Create Cluster 1 namespace:
```bash
kubectl create namespace eks-sample-webapp-1
```

- Create Cluster 2 namespace:
```bash
kubectl create namespace eks-sample-webapp-2
```
---
- Use the following command to delete the namepsace:
```bash
kubectl delete namespace eks-sample-webapp-1
```
## Step 3. Create ConfigMap to modify default index.html on an nginx webserver:

- Service 1 running in Cluster 1: 
    - Create/apply ConfigMap:
    ```bash
    kubectl apply -f service1-index-html-configmap.yaml
    ```
- Service 1 running in Cluster 2: 
    - Create/apply ConfigMap:
    ```bash
    kubectl apply -f service2-index-html-configmap.yaml
    ```
---
- Additiona commands:
    - Describe ConfigMap:
    ```bash
    kubectl describe configmap -n eks-sample-webapp-1
    ```
    - Delete ConfigMap:
    ```bash
    kubectl delete -f service1-index-html-configmap.yaml
    ```
## Step 4. Create service deployment, unique for each service:

- Service 1 Cluster 1:
    - Create/apply service 1 manifest file:
    ```bash
    kubectl apply -f service1-manifest.yaml
    ```
- Service 2 Cluster 1:
    - Create/apply service 2 manifest file:
    ```bash
    kubectl apply -f service2-manifest.yaml
    ```
---
- Additional commands:
    - Get deployment
    ```bash
    kubectl get deployment sample-http-service-1 -n eks-sample-webapp-1
    ```
    - Get pods details:
    ```bash
    kubectl get pods -n eks-sample-webapp-1 -l=app=sample-http-service-1 -o wide
    ```
    - Describe service:
    ```bash
    kubectl describe svc sample-http-service-1 -n eks-sample-webapp-1
    ```
    - Delete deployment:
    ```bash
    kubectl delete -f service1-manifest.yaml
    ```        

## Step 5.  Create ALB and target groups:

## Step 6.  Create Targetgoupbinding:

- Create target group binding for cluster 1 service 1
```bash
	cat target-group-binding.yaml | envsubst | kubectl create -f -
```

- Repeat the step service to target group binding

---
- Delete target group binding:
```bash
	cat target-group-binding.yaml | envsubst | kubectl delete -f -
```

## Step 7. Create ALB Controller - k8s component) to update Target Group

---
* Create IAM Policy for the AWS Load Balancer Controller:

```bash
aws iam create-policy \
--policy-name AWSLoadBalancerControllerIAMPolicy \
--policy-document file://iam-policy.json
```
* Create an IAM Role and ServiceAccount for the AWS Load Balancer controller:
```bash
eksctl create iamserviceaccount \
--cluster=${EKS_CLUSTER1_NAME} \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region ${AWS_REGION} \
--approve
```
* Deploy AWS Load Balancer Controller using Helm:
    * Make sure have Helm installed by following the steps in the Using Helm section. If you have not then use the below command to install it:
    ```bash
    curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    ```
    * Next, add the EKS chart Helm repo:
    ```bash
    helm repo add eks https://aws.github.io/eks-charts
    ```
    * Next, deploy AWS Load Balancer Controller using the respective Helm chart. Copy and paste the command shown below:
    ```bash
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${EKS_CLUSTER1_NAME} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
    ```
---
- Repeat the steps for the 2nd EKS cluster (except the IAM Policy)

---
- Uninstalling AWS Load Balancer Controller

```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

- Delete the service account created for AWS Load Balancer Controller.
```bash
eksctl delete iamserviceaccount \
    --cluster ${EKS_CLUSTER1_NAME} \
    --name aws-load-balancer-controller \
    --namespace kube-system \
    --wait
```

- Delete the IAM Policy created for the AWS Load Balancer Controller.
```bash
aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
```
## Step 8. Create advance routing rules for ALB (path based and header based):


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

