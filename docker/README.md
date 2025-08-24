# Docker Image Build
1. Connect to ECR
```
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ECR_FQDN
```
2. Build docker image
```
cd docker
docker build -t fe2-app-ecr .
````
3. Tag docker image
```
docker tag fe2-app-ecr:latest ECR_FQDN/fe2-app-ecr:2.38
```
4. Push docker image to ECR
```
docker push ECR_FQDN/fe2-app-ecr:2.38
```