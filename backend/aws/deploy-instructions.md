# AWS Deployment Guide — Bucket Backend API

This guide details the deployment of the privacy-preserving Bucket FastAPI backend to AWS using **Amazon ECS Fargate**, **Amazon RDS PostgreSQL**, and **AWS Secrets Manager**.

---

## Architecture Overview

```
                                      Internet
                                         │
                                         ▼
                                  [Route 53 / DNS]
                                         │ (TLS / HTTPS)
                                         ▼
                            [Application Load Balancer]
                                         │
                      ┌──────────────────┴──────────────────┐
                      ▼                                     ▼
          [ECS Fargate Task 1]                  [ECS Fargate Task 2]
             (FastAPI Container)                   (FastAPI Container)
                      │                                     │
                      └──────────────────┬──────────────────┘
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                 [RDS PostgreSQL]               [AWS Secrets Manager]
              (Encrypted at rest)            (DB URLs & JWT Secrets)
```

### Privacy & Compliance Invariants
1. **Zero Financial Data:** No account balances, goal targets, bucket balances, or transaction lines are transmitted or stored in RDS PostgreSQL.
2. **Session Hash Only:** Sync sessions only store cross-device SHA-256 session hashes for deduplication.
3. **Zero-Knowledge Backups:** Cloud backups store opaque AES-256-GCM ciphertext encrypted on-device.

---

## 1. Secrets Configuration (AWS Secrets Manager)

Create secrets in region `ap-south-1` (Mumbai):

```bash
aws secretsmanager create-secret \
  --name "bucket/production/db-credentials" \
  --secret-string '{"DATABASE_URL":"postgresql+psycopg2://bucket_admin:<SECURE_PASSWORD>@bucket-db.c9xxxx.ap-south-1.rds.amazonaws.com:5432/bucket_prod"}'

aws secretsmanager create-secret \
  --name "bucket/production/jwt-secret" \
  --secret-string '{"SECRET_KEY":"<64_CHARACTER_CRYPTOGRAPHIC_RANDOM_STRING>"}'
```

---

## 2. Docker Image Build & Push to Amazon ECR

```bash
# 1. Authenticate Docker with Amazon ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com

# 2. Build backend container image
docker build -t bucket-api:latest -f Dockerfile .

# 3. Tag image for ECR repository
docker tag bucket-api:latest <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/bucket-api:latest

# 4. Push image
docker push <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/bucket-api:latest
```

---

## 3. Register ECS Task Definition & Deploy Service

```bash
# Register task definition
aws ecs register-task-definition \
  --cli-input-json file://aws/ecs-task-definition.json

# Update existing ECS service
aws ecs update-service \
  --cluster bucket-production-cluster \
  --service bucket-api-service \
  --task-definition bucket-api-task \
  --force-new-deployment
```

---

## 4. Health Check Verification

The load balancer performs health checks at `/api/v1/health`:

```bash
curl -f https://api.bucketapp.in/api/v1/health
# Response:
# {"status":"healthy","service":"Bucket Backend API","version":"0.4.0","timestamp":"2026-10-04T18:00:00Z"}
```
