eksctl utils associate-iam-oidc-provider --region ${AWS_REGION} --cluster ${Cluster2Name} --approve

curl -o iam-policy.json curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

eksctl create iamserviceaccount --cluster=${Cluster2Name} --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::${AccountId}:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --region ${AWS_REGION} --approve

helm repo add eks https://aws.github.io/eks-charts

helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${Cluster2Name} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
