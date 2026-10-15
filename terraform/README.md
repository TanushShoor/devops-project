# Terraform lab

This folder teaches Infrastructure as Code by provisioning the AWS VPC and EKS cluster used by StudySpace.

The module-based approach keeps the lesson focused on Terraform concepts: providers, variables, modules, state, plan/apply, outputs and dependency graphs.

> Cost warning: EKS standard support is $0.10 per cluster-hour, before compute and networking. Your AWS console screenshot shows the Free account plan: AWS says eligible use consumes the account credits, and the account closes when credits or the plan period ends. EKS is on the Free plan service list. Keep the account on Free plan; upgrading to Paid makes use beyond credits billable. Monitor the balance, set a budget alert, and keep the demo brief. Review [EKS pricing](https://aws.amazon.com/eks/pricing/), [VPC/NAT Gateway pricing](https://aws.amazon.com/vpc/pricing/), the [Free plan terms](https://docs.aws.amazon.com/en_en/awsaccountbilling/latest/aboutv2/free-tier-plans.html), and the [Free plan service list](https://docs.aws.amazon.com/accounts/latest/reference/supported-services-sign-up-new.html). Resources are created only when you run `terraform apply`.

Authenticate with the AWS CLI using your console session; do not create or share access keys:

```bash
aws login --profile studyspace --region ap-southeast-2
export AWS_PROFILE=studyspace
aws sts get-caller-identity
```

Review and save the plan before applying it. Take the requested AWS screenshots, deploy and demonstrate the app, then destroy the environment and verify that its resources are gone.

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
./scripts/terraform-aws.sh -chdir=terraform plan -out=studyspace.tfplan
```

Review the plan before applying it. Apply only after confirming the AWS account is still on the Free plan and the resource list matches the project:

```bash
./scripts/terraform-aws.sh -chdir=terraform apply studyspace.tfplan
aws eks update-kubeconfig --profile studyspace --region ap-southeast-2 --name study-planner-eks
kubectl get nodes
```

After the demo and screenshots, destroy the stack and verify completion:

```bash
./scripts/terraform-aws.sh -chdir=terraform destroy
```
