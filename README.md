# FE2 AWS

This repo is used to provision the required AWS infrastructure and build an updated docker image to run [FE2](https://alamos.gmbh/loesungen/alarmplattform) on AWS ECS.

## CI Guardrails

- Lint job runs Terraform fmt/validate alongside tflint to block obvious configuration issues before plan.
- Terraform plan job publishes plan artifacts; maintainers review those outputs before any apply runs.
- Production applies target the `production` GitHub environment and require an approval gate—configure the environment reviewers so the right maintainers are notified.
- A scheduled drift-detection workflow monitors the stack; check the recurring run results and investigate any drift that appears.
