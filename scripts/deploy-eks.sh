#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-studyspace}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-study-planner-eks}"
NAMESPACE="${NAMESPACE:-study-planner}"

for command in aws kubectl helm git; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
IMAGE_TAG="$(git -C "$REPO_ROOT" rev-parse HEAD)"

printf 'Checking AWS identity for profile %s...\n' "$AWS_PROFILE"
aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null

printf 'Updating kubeconfig for %s in %s...\n' "$EKS_CLUSTER_NAME" "$AWS_REGION"
aws eks update-kubeconfig \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME"

kubectl wait --for=condition=Ready nodes --all --timeout=5m
kubectl apply -f "$REPO_ROOT/k8s/namespace.yaml"

helm upgrade --install study-planner "$REPO_ROOT/helm/taskboard" \
  --namespace "$NAMESPACE" \
  --set frontend.image=ghcr.io/tanushshoor/study-planner-frontend \
  --set-string frontend.tag="$IMAGE_TAG" \
  --set backend.image=ghcr.io/tanushshoor/study-planner-backend \
  --set-string backend.tag="$IMAGE_TAG"

kubectl rollout status deployment/study-planner-frontend -n "$NAMESPACE" --timeout=5m
kubectl rollout status deployment/study-planner-backend -n "$NAMESPACE" --timeout=5m
kubectl get pods,services -n "$NAMESPACE"
