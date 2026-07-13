# Terraform
1. Install [tfenv](https://github.com/tfutils/tfenv)
2. Install terraform 1.15.0
3. Start using terraform 1.15.0
```
tfenv use 1.15.0
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

## Recovery & Backups

- EFS daily (Tue–Sun, 7-day retention) and weekly (Mon, 30-day retention) backups run via AWS Backup (see `terraform/efs.tf` resources `aws_backup_plan.daily` and `aws_backup_selection.efs`).
- Restores require the `fe2-app-backup-role` IAM role. Permissions are scoped to the configured backup vault and filesystem; review `terraform/iam.tf` for details.
- Follow `terraform/RECOVERY.md` for the end-to-end manual restore procedure, including AWS Backup console steps, CLI commands, and post-restore ECS updates.
- Record AWS Backup job IDs and Terraform plan/apply hashes after any restore for audit.

## MongoDB Maintenance

```
aws ecs execute-command \
  --cluster fe2-app-cluster \
  --task TASK_ID \
  --container mongodb-container \
  --interactive \
  --command "mongosh"

db.adminCommand( { setFeatureCompatibilityVersion: "VERSION" } )
```
