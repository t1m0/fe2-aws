# Terraform
1. Install [tfenv](https://github.com/tfutils/tfenv)
2. Install terraform 1.12.1
3. Start using terraform 1.12.1
```
tfenv use 1.12.1
```
4. Init terraform workspace
```
terraform init \
    -backend-config="BUCKET_NAME" \
    -backend-config="key=OBJECT_KEY" \
    -backend-config="region=eu-central-1"
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
7. Update mongodb
```
aws ecs execute-command \
  --cluster fe2-app-cluster \
  --task TASK_ID \
  --container mongodb-container \
  --interactive \
  --command "mongosh"

db.adminCommand( { setFeatureCompatibilityVersion: "VERSION" } )
```