NAMESPACE   := argocd
RELEASE     := argocd
PORT        := 8080

.PHONY: setup install uninstall password forward status wait deploy

setup: install wait password forward

install:
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@for i in 1 2 3; do \
		echo "Attempt $$i/3: downloading and installing ArgoCD chart..."; \
		helm upgrade --install $(RELEASE) argo/argo-cd \
			--namespace $(NAMESPACE) \
			--values values.yaml \
			--wait && break || \
		{ [ $$i -lt 3 ] && echo "Failed (EOF/network error), retrying in 15s..." && sleep 15 || exit 1; }; \
	done

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)
	kubectl delete namespace $(NAMESPACE)ç

password:
	@echo "Usuario: admin"
	@printf "Contraseña: "
	@kubectl -n $(NAMESPACE) get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d
	@echo ""

forward:
	kubectl port-forward -n $(NAMESPACE) \
		$$(kubectl get pod -n $(NAMESPACE) -l app.kubernetes.io/name=argocd-server \
		   --no-headers -o custom-columns=":metadata.name") \
		$(PORT):8080

status:
	kubectl get pods -n $(NAMESPACE)

wait:
	kubectl wait --for=condition=available --timeout=300s \
		deployment/argocd-server -n $(NAMESPACE)

deploy:
	kubectl apply -f agentsbrew-app.yaml