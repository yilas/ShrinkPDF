# Variables
IMAGE_NAME = yilas/shrinkpdf
TAG = 1.2.0
CLUSTER_NAME = k8s-shrink
CHART_PATH = ./charts/shrinkpdf
NAMESPACE = inis-tools-pdf
NAMESPACE_REGISTRY = inis-registry
CILIUM_VERSION = 1.18.5

.PHONY: all setup setup-infra build load deploy logs clean test proxy #check-dns

# All => setup, build, load et deploy
all: setup build load deploy

# Création du cluster Kind
setup:
	@echo "--- Creating Kind cluster w/o CNI ---"
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

setup-infra:
	@echo "--- Ensuring Zot Helm Repo ---"
	helm repo add project-zot http://zotregistry.dev/helm-charts
	helm repo update

	@echo "--- Installing Zot Registry ---"
	helm upgrade zot project-zot/zot --install \
		--namespace $(NAMESPACE_REGISTRY) \
		-f charts/zot/values.yaml \
		--create-namespace \
		--wait

	### /!\ Ouvrir issue pour prise en compte de httproute dans https://github.com/project-zot/helm-charts ?
	@echo "--- Applying Zot HTTPRoute ---"
	kubectl apply -f charts/zot/zot-route.yaml

	@echo "--- Cat the hosts.toml ---"
	docker exec -it k8s-shrink-worker cat /etc/containerd/certs.d/localhost:5555/hosts.toml

	@echo "--- Checking Zot DNS resolution from inside the cluster nodes ---"
	# On teste sur le control-plane, mais on pourrait boucler sur les workers
	docker exec $(CLUSTER_NAME)-control-plane getent hosts zot.$(NAMESPACE_REGISTRY).svc.cluster.local > /dev/null \
		&& echo "DNS Resolution for Zot is OK" \
		|| (echo "DNS Resolution for Zot FAILED. Check if Cilium is ready" && exit 1)

# Build de l'image Docker (Multi-stage)
build:
	@echo "--- Building Docker image $(IMAGE_NAME):$(TAG) ---"
	docker build -t $(IMAGE_NAME):$(TAG) .

# Chargement de l'image dans Kind
## Soit... on pousse directement dans kind
load: build
	@echo "--- Loading image into Kind cluster $(CLUSTER_NAME) ---"
	kind load docker-image $(IMAGE_NAME):$(TAG) --name $(CLUSTER_NAME)
## Soit... on pousse dans la registry zot
push: build
	@echo "--- Pushing image to remote registry ---"
	kubectl port-forward -n $(NAMESPACE_REGISTRY) svc/zot 5555:5555 & PID=$$!; \
	sleep 5; \
	docker tag yilas/shrinkpdf:$(TAG) localhost:5555/shrinkpdf:$(TAG); \
	docker push localhost:5555/shrinkpdf:$(TAG); \
	kill $$PID

# Déploiement via Helm
deploy:
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
	kubectl port-forward -n inis-tools-pdf services/shrink-shrinkpdf 8080:80

# Affichage des logs
logs:
	@echo "--- Streaming logs ---"
	kubectl logs -f -l app.kubernetes.io/name=shrinkpdf

# Nettoyage complet
clean:
	@echo "--- Deleting cluster and cleaning Docker ---"
	kind delete cluster --name $(CLUSTER_NAME)
 	docker rmi $(IMAGE_NAME):$(TAG) || true
