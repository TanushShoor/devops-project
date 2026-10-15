# StudySpace — Student Study Planner

StudySpace is a small full-stack app for keeping courses, assignments, priorities, and due dates in one place. It is the application for the Session 21 DevOps capstone. The project demonstrates a path from local development through container builds, CI security scanning, Kubernetes deployment, and monitoring.

## What it includes

- React + Vite responsive dashboard with course filters, deadlines, priorities, and assignment status.
- FastAPI REST API backed by PostgreSQL and SQLAlchemy.
- Alembic database migration and isolated pytest API tests.
- Dockerfiles and Docker Compose for a one-command local stack.
- GitHub Actions CI/CD for tests, frontend build, image build, Trivy scan, GHCR publish, and optional Helm deployment.
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

The EKS deploy job is disabled by default. Enable it only after an EKS cluster is ready, by adding repository variable `DEPLOY_TO_EKS=true` and secret `KUBE_CONFIG_DATA` containing the base64 encoded kubeconfig. Keep credentials and kubeconfig out of Git.

## Terraform and AWS

Terraform in `terraform/` defines a VPC, public and private subnets, a NAT gateway, an EKS control plane, and managed worker nodes in `ap-southeast-2`. Terraform files are prepared for review; they do not create anything until you run `terraform apply`.

You need an AWS account, AWS CLI credentials with the required permissions, and Terraform installed. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and adjust it if needed. An EKS cluster, EC2 worker nodes, and NAT gateway can incur charges. Check current AWS pricing and set a budget alert before applying. When you are done, run `terraform destroy` and verify the resources are gone. Never put AWS keys in this repository.

```bash
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
aws eks update-kubeconfig --region ap-southeast-2 --name study-planner-eks
```

## Kubernetes and Helm

The chart is in `helm/taskboard/` (directory retained from the supplied starter). It deploys the app and an in-cluster PostgreSQL database. A Kubernetes ingress controller and Metrics Server are required for Ingress and HPA behavior.

```bash
kubectl apply -f k8s/namespace.yaml
helm upgrade --install study-planner ./helm/taskboard \
  --namespace study-planner --create-namespace \
  --set frontend.image=ghcr.io/tanushshoor/study-planner-frontend \
  --set backend.image=ghcr.io/tanushshoor/study-planner-backend
```

For the classroom ingress config, install an ingress controller and Metrics Server, then use `helm/taskboard/values-dev.yaml`. Update your hosts file to point `studyspace.local` to the ingress address. Configure a real Kubernetes Secret for the PostgreSQL password before using a shared or public cluster; the chart's starter value is only for a disposable demo.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system
```

## Monitoring

The backend exports Prometheus metrics at `/metrics`. `monitoring/prometheus-values.yaml` contains the Prometheus Operator setup, and the chart can create a ServiceMonitor. Install Prometheus/Grafana, confirm the StudySpace target is `UP`, and build a dashboard panel for request volume, latency, or errors. Metrics Server is separate and is used by the HPA.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/prometheus-values.yaml
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
