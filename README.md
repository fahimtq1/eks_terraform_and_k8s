Platform Simulator on AWS (EKS + Terraform + K8s)

This repository is a **minimal, portfolio-friendly simulation** of a Pismo-like core banking platform. It provisions **AWS networking + EKS** with **Terraform**, deploys a simple **Go (Golang) “accounts” microservice** to Kubernetes, and includes plain **Kubernetes manifests** plus an **advanced Argo Rollouts (Istio) canary** example.

> ✅ The goal: demonstrate end-to-end cloud-native delivery (IaC → cluster → app) with a structure you can extend.

---

## Contents

- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start (TL;DR)](#quick-start-tldr)
- [1) Provision AWS with Terraform](#1-provision-aws-with-terraform)
- [2) Configure EKS access](#2-configure-eks-access)
- [3) Build & Push the Accounts Service (optional)](#3-build--push-the-accounts-service-optional)
- [4) Deploy to Kubernetes (plain manifests)](#4-deploy-to-kubernetes-plain-manifests)
- [5) Canary with Argo Rollouts + Istio (optional)](#5-canary-with-argo-rollouts--istio-optional)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Roadmap / Next Steps](#roadmap--next-steps)

---

## Architecture

**Terraform** creates:
- A VPC with **public/private subnets**, IGW, NAT, and routing
- An **EKS** cluster + managed node group (private subnets)
- Security groups and IAM roles for EKS
- **PostgreSQL (RDS)** and **DocumentDB** (Mongo-compatible) for data workloads

**Kubernetes** then runs:
- A tiny **accounts** service (Go, HTTP on port `8080`)
- A **ClusterIP Service** for internal traffic
- Optional **Argo Rollouts** canary using **Istio** traffic splitting

You can extend this with more services, policies, and observability.

---

## Repository Structure

```text
eks_terraform_and_k8s/
├── terraform/
│   ├── vpc.tf                 # VPC, subnets, NAT, routes, tags for EKS discovery
│   ├── eks.tf                 # EKS cluster, IAM roles/policies, node group
│   ├── databases.tf           # RDS (Postgres) + DocumentDB cluster
│   └── outputs.tf             # Outputs (cluster endpoint/name, VPC/Subnet IDs, etc.)
├── services/
│   └── accounts/
│       └── main.go            # Minimal HTTP server (“Hello from the Accounts Service!”)
└── kubernetes/
    ├── manifests/
    │   ├── accounts-deployment.yaml  # Deployment (replicas, resources, labels)
    │   └── accounts-service.yaml     # ClusterIP Service (port 80 → 8080)
    └── accounts-rollout.yaml         # Argo Rollouts canary (requires Istio + Rollouts)
```

> Tip: You can later add `kubernetes/rollouts/` (to separate advanced rollouts), `kubernetes/policies/` (OPA/Conftest), and an `argo-apps/` folder for GitOps.

---

## Prerequisites

- **AWS account** with permissions to create VPC, EKS, RDS/DocDB, IAM, etc.
- **CLI tooling**:
  - Terraform ≥ 1.5
  - AWS CLI ≥ 2
  - kubectl ≥ 1.27
  - (Optional) Docker + an **ECR** repository if you will build/push your own image
  - (Optional) Helm, Istioctl, Argo Rollouts CLI (for canary path)
- **Credentials**: `aws configure` or environment vars for access keys/role.

---

## Quick Start (TL;DR)

```bash
# 0) In repo root (terminal with AWS creds set)
cd terraform
terraform init
terraform apply -auto-approve

# 1) Get kubeconfig to talk to the new cluster
aws eks update-kubeconfig --name fintech-cluster --region <your-region>

# 2) (Optional) Build and push your image to ECR, then update manifest image fields
#    Otherwise, ensure the deployment/rollout images point to a valid public image.

# 3) Deploy the service
kubectl apply -f ../kubernetes/manifests/

# 4) (Optional) If you have Istio + Argo Rollouts installed:
kubectl apply -f ../kubernetes/accounts-rollout.yaml
```

---

## 1) Provision AWS with Terraform

From `terraform/`:

```bash
terraform init
terraform plan
terraform apply
```

**What gets created:**
- **VPC/Subnets/Routes**: see `vpc.tf`
- **EKS** (cluster + node group, with IAM & SGs): see `eks.tf`
- **Databases** (RDS Postgres + DocumentDB): see `databases.tf`
- **Outputs** (useful IDs and endpoints): see `outputs.tf`

> 🔐 Strongly recommended (future): use a remote state backend (S3 + DynamoDB) and `variables.tf` to parameterise region, CIDRs, names, DB creds.

---

## 2) Configure EKS access

After `terraform apply`, configure `kubectl`:

```bash
aws eks update-kubeconfig --name fintech-cluster --region <your-region>
kubectl get nodes
```

You should see your worker nodes `Ready`.

---

## 3) Build & Push the Accounts Service (optional)

The demo deployment references an image. If you want to build your own:

1. **Create an ECR repo** (once):
   ```bash
   aws ecr create-repository --repository-name accounts-service
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   export AWS_REGION=<your-region>
   ```

2. **Authenticate Docker to ECR**:
   ```bash
   aws ecr get-login-password --region $AWS_REGION      | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
   ```

3. **Build + Tag + Push**:
   ```bash
   # Create a minimal Dockerfile next to main.go if you don’t have one yet:
   # --- services/accounts/Dockerfile ---
   # FROM golang:1.22 AS build
   # WORKDIR /src
   # COPY . .
   # RUN go build -o /app/accounts-service ./main.go
   # FROM gcr.io/distroless/base-debian12
   # COPY --from=build /app/accounts-service /accounts-service
   # EXPOSE 8080
   # ENTRYPOINT ["/accounts-service"]

   cd services/accounts
   docker build -t accounts-service:latest .
   docker tag accounts-service:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/accounts-service:latest
   docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/accounts-service:latest
   ```

4. **Update Kubernetes image** in:
   - `kubernetes/manifests/accounts-deployment.yaml`
   - (optional) `kubernetes/accounts-rollout.yaml`
   with your ECR URI:
   ```
   <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/accounts-service:latest
   ```

---

## 4) Deploy to Kubernetes (plain manifests)

Apply the Deployment + Service:

```bash
kubectl apply -f kubernetes/manifests/
kubectl get deploy,svc -l app=accounts
```

Test from within the cluster (e.g. via a temporary pod):

```bash
kubectl run curl --image=curlimages/curl:8.8.0 -it --rm --   curl -s http://accounts-service.default.svc.cluster.local/
# Expect: "Hello from the Accounts Service!"
```

> If you need external access, add an Ingress (ALB ingress controller) or change the Service type to `LoadBalancer` (not recommended for multi-service setups—prefer Ingress).

---

## 5) Canary with Argo Rollouts + Istio (optional)

This repo includes an **Argo Rollouts** spec (`kubernetes/accounts-rollout.yaml`) that performs a **canary** rollout. To use it:

1. **Install Istio & enable sidecar injection** (namespace-wide or via pod annotations).
2. **Install Argo Rollouts controller** in the cluster.
3. Create the necessary **Istio VirtualService/DestinationRule** (traffic split).
4. Update the `image:` in the Rollout spec to your ECR URI.
5. Apply:
   ```bash
   kubectl apply -f kubernetes/accounts-rollout.yaml
   ```

Observe the weighted rollout with the Argo Rollouts plugin/CLI or UI.

> If you’re not using Istio/Rollouts yet, skip this section and stick with the plain Deployment.

---

## Cleanup

```bash
# Remove Kubernetes resources first (optional)
kubectl delete -f kubernetes/manifests/ || true
kubectl delete -f kubernetes/accounts-rollout.yaml || true

# Tear down AWS infra
cd terraform
terraform destroy
```

---

## Troubleshooting

- **`kubectl get nodes` shows none / cluster auth issues**
  - Re-run `aws eks update-kubeconfig --name fintech-cluster --region <region>`
  - Verify your AWS role/creds; ensure EKS and node group finished creating.
- **Pods Pending**
  - Check node capacity and taints: `kubectl describe pod <name>`
  - Ensure subnets are tagged for EKS and nodes are in private subnets with outbound via NAT.
- **Image pull errors**
  - Confirm ECR login & that the image URI is correct and public/private permissions are correct.
  - For private images, ensure nodes can pull from your ECR (appropriate IAM on node role).
- **Database connectivity**
  - DB SGs restrict access to EKS nodes only; ensure app runs inside cluster and uses the right host/port/secret.

---

## Roadmap / Next Steps

- **Terraform hardening**
  - Add `variables.tf` (region, CIDRs, names) and `backend.tf` (S3 + DynamoDB state lock)
  - Parameterise DB credentials and avoid plaintext in code
- **Observability**
  - Helm-install Prometheus + Grafana; add service metrics (Prometheus client lib) and dashboards
- **Policy as Code**
  - Add `kubernetes/policies/*.rego` (OPA/Conftest) + Gatekeeper for admission controls
  - Example rules: required labels, disallow `:latest`, require resources, disallow privileged
- **GitOps**
  - Add Argo CD Application manifests; reconcile from a config repo
- **Security**
  - Image scanning and signing (e.g., Trivy + Cosign), RBAC least privilege, secret management (AWS Secrets Manager/External Secrets)
- **More services**
  - Split domains (cards, payments, ledger) and model inter-service communication

---

## License

MIT (or your preferred). Replace this with your chosen license.
