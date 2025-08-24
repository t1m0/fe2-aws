# Terraform
1. Install [tfenv](https://github.com/tfutils/tfenv)
2. Install terraform 1.12.1
3. Start using terraform 1.12.1
```
tfenv use 1.12.1
```
4. Init terraform workspace
```
terraform init
```
5. Validate terraform workspace
```
terraform validate
```
6. Plan terraform execution
```
terraform plan --out plan.tfplan
```
7. Apply terraform
```
terraform apply --auto-approve
```