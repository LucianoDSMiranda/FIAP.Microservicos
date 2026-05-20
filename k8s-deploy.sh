#!/bin/bash
set -e

BUILD_IMAGES=false
DOWN=false

for arg in "$@"; do
  case $arg in
    --build) BUILD_IMAGES=true ;;
    --down)  DOWN=true ;;
  esac
done

wait_pods() {
  local label=$1
  local timeout=${2:-120}
  echo "  Aguardando pods '$label'..."
  kubectl wait pod --for=condition=Ready -l "$label" --timeout="${timeout}s"
  echo "  OK"
}

if [ "$DOWN" = true ]; then
  echo "Removendo todos os recursos do cluster..."
  kubectl delete -f Notification/k8s/    --ignore-not-found
  kubectl delete -f FIAP.Payments/k8s/   --ignore-not-found
  kubectl delete -f FIAP.Catalog/k8s/    --ignore-not-found
  kubectl delete -f User/k8s/            --ignore-not-found
  kubectl delete -f k8s/monitoring/      --ignore-not-found
  kubectl delete -f k8s/kong/            --ignore-not-found
  kubectl delete -f k8s/                 --ignore-not-found
  echo "Cluster limpo."
  exit 0
fi

if [ "$BUILD_IMAGES" = true ]; then
  echo -e "\n[BUILD] Buildando imagens locais (Docker Desktop)..."

  echo "  Build users-api..."
  docker build -t fiapmicroservicos-users-api ./User -q

  echo "  Build catalog-api..."
  docker build -t fiapmicroservicos-catalog-api ./FIAP.Catalog -q

  echo "  Build payments-api..."
  docker build -t fiapmicroservicos-payments-api ./FIAP.Payments -q

  echo "  Build notifications-functions..."
  docker build -t fiapmicroservicos-notifications-functions ./Notification -q

  echo "  Imagens prontas."
fi

echo -e "\n[1/5] Infra: MongoDB, RabbitMQ, Redis..."
kubectl apply -f k8s/mongo-pvc.yaml
kubectl apply -f k8s/mongo-deployment.yaml
kubectl apply -f k8s/mongo-service.yaml
kubectl apply -f k8s/rabbitmq-secret.yaml
kubectl apply -f k8s/rabbitmq-deployment.yaml
kubectl apply -f k8s/rabbitmq-service.yaml
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/redis-service.yaml

wait_pods "app=mongo"
wait_pods "app=rabbitmq"
wait_pods "app=redis"

echo -e "\n[2/5] Azurite (Azure Storage emulator)..."
kubectl apply -f Notification/k8s/azurite.yaml
wait_pods "app=azurite"

echo -e "\n[3/5] Monitoring: Prometheus + Grafana..."
kubectl apply -f k8s/monitoring/
wait_pods "app=prometheus"
wait_pods "app=grafana"

echo -e "\n[4/5] Microsservicos..."
kubectl apply -f User/k8s/
kubectl apply -f FIAP.Catalog/k8s/
kubectl apply -f FIAP.Payments/k8s/
kubectl apply -f Notification/k8s/

wait_pods "app=users-api"
wait_pods "app=catalog-api"
wait_pods "app=payments-api"
wait_pods "app=notifications-functions"

echo -e "\n[5/5] Kong API Gateway..."
kubectl apply -f k8s/kong/kong.yaml
wait_pods "app=kong"

MINIKUBE_IP="localhost"

echo ""
echo "========================================"
echo " Cluster pronto!"
echo "========================================"
echo ""
echo "URLs de acesso (NodePort):"
echo "  Users API           http://${MINIKUBE_IP}:$(kubectl get svc users-api-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
echo "  Catalog API         http://${MINIKUBE_IP}:$(kubectl get svc catalog-api-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
echo "  Payments API        http://${MINIKUBE_IP}:$(kubectl get svc payments-api-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
echo "  Notifications Func  http://${MINIKUBE_IP}:$(kubectl get svc notifications-functions-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
echo "  RabbitMQ Management http://${MINIKUBE_IP}:$(kubectl get svc rabbitmq-service -o jsonpath='{.spec.ports[?(@.name=="management")].nodePort}' 2>/dev/null)"
echo "  Prometheus          http://${MINIKUBE_IP}:$(kubectl get svc prometheus-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
echo "  Grafana             http://${MINIKUBE_IP}:$(kubectl get svc grafana-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
echo ""
