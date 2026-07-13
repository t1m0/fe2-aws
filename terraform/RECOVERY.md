# EFS Recovery Playbook

## Overview
- Environment: production in a single AWS account (see `terraform/main.tf` for provider configuration)
- Primary data store: `aws_efs_file_system.main` (creation token `fe2-app-efs`)
- Backups: `aws_backup_plan.daily` targeting vault `fe2-app-backup-vault`

## Prerequisites
- AWS IAM principal that can assume the `fe2-app-backup-role`. Use the CLI to obtain and export temporary credentials:
  ```bash
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ASSUME_SESSION_NAME="fe2-recovery-$(date +%Y%m%d%H%M%S)"
  ASSUME_JSON=$(aws sts assume-role \
    --role-arn arn:aws:iam::${ACCOUNT_ID}:role/fe2-app-backup-role \
    --role-session-name "${ASSUME_SESSION_NAME}")
  export AWS_ACCESS_KEY_ID=$(echo "${ASSUME_JSON}" | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo "${ASSUME_JSON}" | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo "${ASSUME_JSON}" | jq -r '.Credentials.SessionToken')
  ```
  The snippet uses `jq` to parse the JSON response.
- AWS CLI v2 with the production profile authenticated (`aws configure sso` or export static credentials)
- Terraform state access for the `terraform/` stack (`terraform -chdir=terraform init -backend-config=backend.hcl`)

## Identify Recovery Point
1. **Console:** Navigate to AWS Backup → Backup vault `fe2-app-backup-vault` → Recovery points → Filter by resource `fe2-app-efs`.
2. **CLI:**
   ```bash
    AWS_REGION=$(aws configure get region || echo "eu-central-1")
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    FILE_SYSTEM_ID=$(aws efs describe-file-systems \
      --creation-token fe2-app-efs \
      --query 'FileSystems[0].FileSystemId' \
     --output text)

   aws backup list-recovery-points-by-resource \
     --resource-arn arn:aws:elasticfilesystem:${AWS_REGION}:${ACCOUNT_ID}:file-system/${FILE_SYSTEM_ID}
   ```

## Start Restore Job (Console)
1. Select the desired recovery point → **Actions** → **Restore**.
2. Choose **Restore to new file system** and set the name to `fe2-app-efs-restore-YYYYMMDD` (for example, `fe2-app-efs-restore-20260713`).
3. Select the same VPC and private subnets tagged `fe2-app-private-*` as the original mount targets (see `terraform/network.tf`).
4. Submit and note the restore job ID.

## Start Restore Job (CLI)
1. Capture resource identifiers (run from the `terraform/` directory or any shell with AWS credentials):
   ```bash
   AWS_REGION=$(aws configure get region || echo "eu-central-1")
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   FILE_SYSTEM_ID=$(aws efs describe-file-systems \
     --creation-token fe2-app-efs \
     --query 'FileSystems[0].FileSystemId' \
     --output text)
   RECOVERY_POINT_ARN=$(aws backup list-recovery-points-by-resource \
     --resource-arn arn:aws:elasticfilesystem:${AWS_REGION}:${ACCOUNT_ID}:file-system/${FILE_SYSTEM_ID} \
     --query 'RecoveryPoints[?Lifecycle==`COMPLETED`].RecoveryPointArn | [0]' \
     --output text)
   RESTORE_NAME="fe2-app-efs-restore-$(date +%Y%m%d-%H%M)"
   TARGET_SUBNET_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=fe2-app-private-1" \
     --query 'Subnets[0].SubnetId' \
     --output text)
    TARGET_SG_ID=$(aws ec2 describe-security-groups \
      --filters "Name=tag:Name,Values=fe2-app-efs-sg" \
      --query 'SecurityGroups[0].GroupId' \
      --output text)
    ```
2. Start the restore job:
   ```bash
   RESTORE_JOB_ID=$(aws backup start-restore-job \
     --recovery-point-arn "${RECOVERY_POINT_ARN}" \
     --iam-role-arn arn:aws:iam::${ACCOUNT_ID}:role/fe2-app-backup-role \
      --metadata "{\"newFileSystem\":\"true\",\"CreationToken\":\"${RESTORE_NAME}\",\"SubnetId\":\"${TARGET_SUBNET_ID}\",\"SecurityGroupId\":\"${TARGET_SG_ID}\"}" \
      --query 'RestoreJobId' \
      --output text)
   ```
   The command stores the restore job ID in `RESTORE_JOB_ID` for reuse.

   Include optional metadata keys when required, for example `"PerformanceMode":"generalPurpose"`, `"ThroughputMode":"elastic"`, or `"Encrypted":"true"` (with `"KmsKeyId"` when using a customer-managed key). For an in-place restore, set `"newFileSystem":"false"` and provide `"FileSystemId":"${FILE_SYSTEM_ID}"` instead of the creation token. `TARGET_SUBNET_ID` and `TARGET_SG_ID` can also come from Terraform outputs (e.g., `terraform -chdir=terraform output -raw private_subnet_ids | jq -r '.[0]'`) or environment variables if you capture them during provisioning.

## Monitor Restore
```bash
aws backup describe-restore-job --restore-job-id "${RESTORE_JOB_ID}"
```
Wait for the `Status` field to reach `COMPLETED` before proceeding.

## Post-Restore Validation
- Confirm the new EFS filesystem:
  ```bash
  RESTORED_FS_ID=$(aws backup describe-restore-job \
    --restore-job-id "${RESTORE_JOB_ID}" \
    --query 'CreatedResourceArn' \
    --output text | awk -F'/' '{print $NF}')

  aws efs describe-file-systems --file-system-id "${RESTORED_FS_ID}"
  ```
- Verify mount targets exist in all private subnets tagged `fe2-app-private-*` and the security group matches `fe2-app-efs-sg`.
- Recreate or attach EFS access points using the existing Terraform modules (see `terraform/efs.tf` and dependent modules) or via the console if faster.

## ECS Cutover
1. Update ECS task definition volumes to reference the restored access point ARNs. Adjust `terraform/fe2.tf` and `terraform/mongodb.tf` if the ARNs changed.
2. Run `terraform -chdir=terraform plan` to confirm the updates align with expected resource changes.
3. Apply the validated plan (`terraform -chdir=terraform apply`) and monitor the ECS service deployment in the console.

## Cleanup
- After application validation, decommission the original filesystem:
  ```bash
  ORIGINAL_FS_ID=$(aws efs describe-file-systems \
    --creation-token fe2-app-efs \
    --query 'FileSystems[0].FileSystemId' \
    --output text)

  aws efs delete-file-system --file-system-id "${ORIGINAL_FS_ID}"
  ```
  Record the deletion in the ops log once complete.
- Tag the restore job and new filesystem with the incident/ticket reference and the restoration date (use `aws resourcegroupstaggingapi tag-resources`).

## Audit & Evidence
- Store the restore job ID, new filesystem ID, ECS task definition revision, and Terraform plan/apply output hashes in the incident record.
- Archive CLI transcripts or console screenshots demonstrating each recovery phase in the ops ticketing system.

## Troubleshooting
- Restore stuck in `PENDING`: verify the `fe2-app-backup-role` trust policy allows AWS Backup and that targeted subnets are available.
- Access point mount failures: align UID/GID with module defaults (999) or update filesystem permissions before remounting.
