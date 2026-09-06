#!/bin/bash
# Generates a random JWT signing secret and creates the K8s secret.
# Kept out of git deliberately: this repo is public, and anyone with this
# value could forge auth tokens for any user, including super-admin.
set -e

NAMESPACE="${1:-media-storage}"

JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')

kubectl create secret generic jwt-secret \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret 'jwt-secret' created/updated in namespace '$NAMESPACE'."
echo "Restart the backend deployment to pick it up: kubectl rollout restart deployment/backend -n $NAMESPACE"
