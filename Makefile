# Variables
IMAGE_NAME = yilas/shrinkpdf
TAG = 1.2.0
CLUSTER_NAME = k8s-shrink
CHART_PATH = ./charts/shrinkpdf
NAMESPACE = inis-tools-pdf
CILIUM_VERSION = 1.18.5

.PHONY: all setup build load deploy logs clean test proxy

# Commande par défaut : setup, build, load et deploy
all: setup build load deploy

# Création du cluster Kind
setup:
	@echo "--- Creating Kind cluster without CNI ---"
	kind create cluster --name $(CLUSTER_NAME) --config dev/kind-config.yaml

	@echo "--- Adding Cilium Helm Repo ---"
	helm repo add cilium https://helm.cilium.io/
	helm repo update

	@echo "--- Installing Gateway API CRDs ---"
	kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

	@echo "--- Installing Cilium with Gateway API support ---"
	helm install cilium cilium/cilium --version $(CILIUM_VERSION) \
	  --namespace kube-system \
	  --set kubeProxyMode=replaced \
	  --set k8sServiceHost=$(CLUSTER_NAME)-control-plane \
	  --set k8sServicePort=6443 \
	  --set gatewayAPI.enabled=true \
	  --set operator.replicas=1

	@echo "--- Waiting for Cilium to be ready ---"
	kubectl wait --namespace kube-system --for=condition=ready pod -l k8s-app=cilium --timeout=120s

# Build de l'image Docker (Multi-stage)
build:
	@echo "--- Building Docker image $(IMAGE_NAME):$(TAG) ---"
	docker build -t $(IMAGE_NAME):$(TAG) .

# Chargement de l'image dans Kind
load: build
	@echo "--- Loading image into Kind cluster $(CLUSTER_NAME) ---"
	kind load docker-image $(IMAGE_NAME):$(TAG) --name $(CLUSTER_NAME)

# Déploiement via Helm
deploy: load
	@echo "--- Deploying Helm chart ---"
	helm upgrade shrink $(CHART_PATH) --install \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set image.tag=$(TAG)
	@echo "--- Waiting for rollout ---"
	kubectl rollout status deployment/shrink-shrinkpdf --namespace $(NAMESPACE)

# Accès à l'interface (Port-forward)
proxy:
	@echo "--- Proxy available at http://localhost:8080 ---"
	kubectl port-forward svc/shrink-shrinkpdf 8080:80

# Affichage des logs en direct
logs:
	@echo "--- Streaming logs ---"
	kubectl logs -f -l app.kubernetes.io/name=shrinkpdf

# Nettoyage complet
clean:
	@echo "--- Deleting cluster and cleaning Docker ---"
	kind delete cluster --name $(CLUSTER_NAME)
# 	docker rmi $(IMAGE_NAME):$(TAG) || true
