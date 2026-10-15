# StudySpace — Student Study Planner

StudySpace is a small full-stack app for keeping courses, assignments, priorities, and due dates in one place. It is the application for the Session 21 DevOps capstone. The project demonstrates a path from local development through container builds, CI security scanning, Kubernetes deployment, and monitoring.

## What it includes

- React + Vite responsive dashboard with course filters, deadlines, priorities, and assignment status.
- FastAPI REST API backed by PostgreSQL and SQLAlchemy.
- Alembic database migration and isolated pytest API tests.
- Dockerfiles and Docker Compose for a one-command local stack.
- GitHub Actions CI/CD for tests, frontend build, image build, Trivy scan, and GHCR publish; EKS deployment is run from the locally authenticated AWS CLI.
- Terraform for an AWS VPC and EKS cluster.
- Helm chart with frontend, backend, PostgreSQL, Ingress, HPA, and ServiceMonitor resources.
- Prometheus/Grafana configuration and troubleshooting examples.

## Run the app locally

Install Docker Desktop (or Docker Engine with Compose) and Python 3.12+. Then from this directory run:

```bash
docker compose up --build
```

Open [http://localhost:3000](http://localhost:3000). The API docs are at [http://localhost:8000/docs](http://localhost:8000/docs); health, readiness, and metrics are at `/health`, `/ready`, and `/metrics` on port 8000.

Stop the app with `Ctrl+C`, or run `docker compose down`. To remove the local database volume as well, run `docker compose down -v`.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/assignments` | List assignments ordered by due date |
| GET | `/api/assignments/{id}` | Fetch one assignment |
| POST | `/api/assignments` | Create an assignment |
| PUT | `/api/assignments/{id}` | Update an assignment |
| DELETE | `/api/assignments/{id}` | Delete an assignment |
| GET | `/api/assignments/stats` | Return counts by status and due soon |

Valid statuses are `TODO`, `IN_PROGRESS`, and `DONE`; priorities are `LOW`, `MEDIUM`, and `HIGH`. `/health` is the liveness endpoint, `/ready` checks database access, and `/metrics` exposes Prometheus metrics.

## Tests and local development

The backend tests use a temporary in-memory SQLite database, not the app database.

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest -v
```

For standalone backend development, start PostgreSQL and set `DATABASE_URL` to a PostgreSQL URL, then run:

```bash
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

For the frontend, use Node.js 22 or newer:

```bash
cd frontend
npm ci
npm run dev
```

## GitHub Actions and GHCR

The workflow in `.github/workflows/ci-cd.yml` runs on pushes and pull requests to `main`. It runs pytest and builds the frontend first. On pushes, it builds both images, fails on unfixed HIGH or CRITICAL Trivy findings, then publishes images to GHCR tagged with the commit SHA.

To use it, create a GitHub repository, push this project to its `main` branch, and enable Actions and package publishing. The workflow uses the repository-provided `GITHUB_TOKEN`; do not add a personal access token to the source. Set the two GHCR packages to public if the Kubernetes cluster will pull them without an image pull secret.

The pipeline intentionally stops after publishing images. Deploy from your local terminal after authenticating the AWS CLI and reviewing the cluster; this avoids storing AWS credentials or kubeconfig in GitHub. Once the pipeline is green, the Helm commands below use the exact SHA-tagged images for that revision.

## Terraform and AWS

Terraform in `terraform/` defines a VPC, public and private subnets, a NAT gateway, an EKS control plane, and managed worker nodes in `ap-southeast-2`. Terraform files are prepared for review; they do not create anything until you run `terraform apply`.

You need an AWS account, AWS CLI v2.32.0 or newer, and Terraform installed. Sign in using the AWS console session without creating or sharing access keys:

```bash
aws login --profile studyspace --region ap-southeast-2
export AWS_PROFILE=studyspace
aws sts get-caller-identity
```

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and adjust it if needed. Your console screenshot shows the AWS Free account plan. AWS says this plan does not incur charges while active; eligible usage consumes credits, and the account closes when credits are exhausted or the six-month period ends. EKS is listed among services available on the Free plan. Keep the account on the Free plan and do not choose “Upgrade plan”; if you later switch to Paid, usage beyond credits is billed. Monitor the credit balance and set a budget alert. EKS standard support is $0.10 per cluster-hour; worker nodes, a NAT gateway, storage, and load balancers add usage. Review [EKS pricing](https://aws.amazon.com/eks/pricing/), [VPC/NAT Gateway pricing](https://aws.amazon.com/vpc/pricing/), [Free plan terms](https://docs.aws.amazon.com/en_en/awsaccountbilling/latest/aboutv2/free-tier-plans.html), and the [Free plan service list](https://docs.aws.amazon.com/accounts/latest/reference/supported-services-sign-up-new.html) before applying. Keep the demo brief and destroy the resources after evidence is collected. Never put AWS keys or kubeconfig files in this repository.

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
./scripts/terraform-aws.sh -chdir=terraform plan -out=studyspace.tfplan
```

Review the complete plan and confirm the AWS console still shows the **Free plan** before applying. Apply only after we have reviewed the plan together:

```bash
./scripts/terraform-aws.sh -chdir=terraform apply studyspace.tfplan
aws eks update-kubeconfig --profile studyspace --region ap-southeast-2 --name study-planner-eks
kubectl get nodes
```

After deployment and screenshots, tear down the cloud resources and verify Terraform reports them destroyed:

```bash
./scripts/terraform-aws.sh -chdir=terraform destroy
```

## Kubernetes and Helm

The chart is in `helm/taskboard/` (directory retained from the supplied starter). It deploys the app and an in-cluster PostgreSQL database. The classroom chart uses temporary database storage; `values-prod.yaml` enables a 5 GiB persistent volume and therefore requires a working storage class such as the EBS CSI driver on EKS. A Kubernetes ingress controller and Metrics Server are required for Ingress and HPA behavior.

```bash
kubectl apply -f k8s/namespace.yaml
IMAGE_TAG="$(git rev-parse HEAD)"
helm upgrade --install study-planner ./helm/taskboard \
  --namespace study-planner --create-namespace \
  --set frontend.image=ghcr.io/tanushshoor/study-planner-frontend \
  --set frontend.tag="$IMAGE_TAG" \
  --set backend.image=ghcr.io/tanushshoor/study-planner-backend \
  --set backend.tag="$IMAGE_TAG"
```

After the commit's GitHub Actions run has passed and both GHCR packages are public, the same SHA-pinned deployment can be run with `./scripts/deploy-eks.sh`. It uses the `studyspace` AWS CLI profile by default; set `AWS_PROFILE`, `AWS_REGION`, `EKS_CLUSTER_NAME`, or `NAMESPACE` to override those defaults.

For the classroom ingress config, install an ingress controller and Metrics Server, then use `helm/taskboard/values-dev.yaml`. Update your hosts file to point `studyspace.local` to the ingress address. Configure a real Kubernetes Secret for the PostgreSQL password before using a shared or public cluster; the chart's starter value is only for a disposable demo.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system

helm upgrade --install study-planner ./helm/taskboard \
  --namespace study-planner \
  -f helm/taskboard/values-dev.yaml \
  --set frontend.image=ghcr.io/tanushshoor/study-planner-frontend \
  --set frontend.tag="$IMAGE_TAG" \
  --set backend.image=ghcr.io/tanushshoor/study-planner-backend \
  --set backend.tag="$IMAGE_TAG"
```

## Monitoring

The backend exports Prometheus metrics at `/metrics`. `monitoring/prometheus-values.yaml` contains the Prometheus Operator setup, and the chart can create a ServiceMonitor. The ServiceMonitor is disabled by default so the app chart can install before the Prometheus Operator CRD exists. Install Prometheus/Grafana, then upgrade the app with `--set monitoring.serviceMonitor.enabled=true`; confirm the StudySpace target is `UP`, and build a dashboard panel for request volume, latency, or errors. Metrics Server is separate and is used by the HPA.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/prometheus-values.yaml

helm upgrade --install study-planner ./helm/taskboard \
  --namespace study-planner \
  --set frontend.image=ghcr.io/tanushshoor/study-planner-frontend \
  --set frontend.tag="$IMAGE_TAG" \
  --set backend.image=ghcr.io/tanushshoor/study-planner-backend \
  --set backend.tag="$IMAGE_TAG" \
  --set monitoring.serviceMonitor.enabled=true
```

## Submission evidence checklist

Capture your own evidence after running each environment; screenshots and live account results cannot be produced from source files alone.

- Browser screenshot of StudySpace running at `localhost:3000`.
- `pytest -v` output showing the tests pass.
- Docker Compose startup and running containers.
- GitHub repository URL and meaningful commit history.
- Successful GitHub Actions run and GHCR SHA-tagged package pages.
- Trivy scan output for both images.
- Terraform plan, AWS VPC/EKS view, and destroy completion.
- Kubernetes pods/services, Helm release, and application through Ingress.
- Backend `/metrics`, Prometheus target `UP`, and a populated Grafana panel.
- Final walkthrough or recording explaining the pipeline and architecture.

## Troubleshooting exercises

The deliberately broken manifests under `troubleshooting/` are for practice. They are not included in the StudySpace chart. Compare their image and service configuration with the working Helm templates when practicing diagnosis.
