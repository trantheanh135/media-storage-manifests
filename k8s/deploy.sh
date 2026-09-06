#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="media-storage"
REGISTRY="${REGISTRY:-docker.io/yourname}"
BACKEND_IMAGE="${REGISTRY}/media-storage-backend:latest"
FRONTEND_IMAGE="${REGISTRY}/media-storage-frontend:latest"
TIMEOUT=300

echo -e "${YELLOW}🚀 Media Storage Kubernetes Deployment${NC}"
echo "Registry: $REGISTRY"
echo "Namespace: $NAMESPACE"
echo

# Step 1: Create namespace
echo -e "${YELLOW}📦 Step 1: Creating namespace...${NC}"
kubectl apply -f 00-namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}\n"

# Step 2: Apply ConfigMap
echo -e "${YELLOW}⚙️  Step 2: Applying ConfigMap...${NC}"
kubectl apply -f 01-configmap.yaml
echo -e "${GREEN}✓ ConfigMap applied${NC}\n"

# Step 3: Apply Secrets
echo -e "${YELLOW}🔐 Step 3: Applying Secrets...${NC}"
kubectl apply -f 02-secret.yaml
echo -e "${GREEN}✓ Secrets applied${NC}\n"

# Step 4: Create Storage
echo -e "${YELLOW}💾 Step 4: Creating PersistentVolumes...${NC}"
kubectl apply -f 03-storage.yaml
echo -e "${GREEN}✓ Storage created${NC}\n"

# Step 5: Deploy PostgreSQL
echo -e "${YELLOW}🗄️  Step 5: Deploying PostgreSQL...${NC}"
kubectl apply -f 04-postgres.yaml
echo "Waiting for PostgreSQL to be ready (up to ${TIMEOUT}s)..."
timeout $TIMEOUT kubectl rollout status statefulset/postgres -n $NAMESPACE || {
  echo -e "${RED}✗ PostgreSQL deployment timeout${NC}"
  exit 1
}
echo -e "${GREEN}✓ PostgreSQL deployed${NC}\n"

# Step 6: Deploy Backend
echo -e "${YELLOW}🔌 Step 7: Deploying Backend...${NC}"
# Update image in the deployment
kubectl set image deployment/backend backend=$BACKEND_IMAGE -n $NAMESPACE --record 2>/dev/null || true
kubectl apply -f 06-backend.yaml
echo "Waiting for Backend to be ready (up to ${TIMEOUT}s)..."
timeout $TIMEOUT kubectl rollout status deployment/backend -n $NAMESPACE || {
  echo -e "${RED}✗ Backend deployment timeout${NC}"
  exit 1
}
echo -e "${GREEN}✓ Backend deployed${NC}\n"

# Step 8: Deploy Frontend
echo -e "${YELLOW}🌐 Step 8: Deploying Frontend...${NC}"
# Update image in the deployment
kubectl set image deployment/frontend frontend=$FRONTEND_IMAGE -n $NAMESPACE --record 2>/dev/null || true
kubectl apply -f 07-frontend.yaml
echo "Waiting for Frontend to be ready (up to ${TIMEOUT}s)..."
timeout $TIMEOUT kubectl rollout status deployment/frontend -n $NAMESPACE || {
  echo -e "${RED}✗ Frontend deployment timeout${NC}"
  exit 1
}
echo -e "${GREEN}✓ Frontend deployed${NC}\n"

# Step 9: Apply Ingress (optional)
echo -e "${YELLOW}🔀 Step 9: Applying Ingress...${NC}"
kubectl apply -f 08-ingress.yaml 2>/dev/null || {
  echo -e "${YELLOW}⚠️  Ingress apply skipped (Ingress controller may not be installed)${NC}"
}
echo

# Step 10: Verify deployment
echo -e "${YELLOW}🔍 Step 10: Verifying deployment...${NC}"
echo
echo "Pods status:"
kubectl get pods -n $NAMESPACE
echo
echo "Services:"
kubectl get svc -n $NAMESPACE
echo
echo "PersistentVolumes:"
kubectl get pv -n $NAMESPACE
echo

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo
echo "Access points:"
echo "  Frontend (NodePort): http://192.168.1.100:$(kubectl get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')"
echo "  Backend (Internal): http://backend-service:8080"
echo
echo "Next steps:"
echo "1. Run ./generate-jwt-secret.sh to create the JWT signing secret (required before backend can start)"
echo "2. Register the first account at the frontend URL - it is automatically promoted to SUPER_ADMIN"
