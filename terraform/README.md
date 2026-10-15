# Terraform lab

This folder teaches Infrastructure as Code by provisioning the AWS VPC and EKS cluster used by StudySpace.

The module-based approach keeps the lesson focused on Terraform concepts: providers, variables, modules, state, plan/apply, outputs and dependency graphs.

> Cost warning: EKS control planes, worker nodes, and a NAT gateway can incur charges. Review AWS pricing for your region before applying. This project does not create resources unless you run `terraform apply`.

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
aws eks update-kubeconfig --region ap-southeast-2 --name study-planner-eks
terraform destroy
```
