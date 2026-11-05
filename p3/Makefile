.PHONY: install up down status ui test roundtrip clean re guard help
.DEFAULT_GOAL := help

CLUSTER_NAME ?= iot
export CLUSTER_NAME
# Part 3 and the bonus both publish port 8888: only one of them may run at a time.
OTHER_CLUSTER := iot-bonus

install:
	@bash scripts/install.sh

guard:
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -Fxq 'k3d-$(OTHER_CLUSTER)-serverlb'; then \
		echo "Error: the bonus cluster ($(OTHER_CLUSTER)) is running and holds port 8888."; \
		echo "Run 'make bonus-clean' (or 'make bonus-down') first."; \
		exit 1; \
	fi

up: guard
	@echo "Starting P3 (k3d + Argo CD)..."
	@echo "This may take 2-5 minutes on first run."
	@echo ""
	@k3d cluster start $(CLUSTER_NAME) >/dev/null 2>&1 || true
	bash scripts/setup.sh

down:
	k3d cluster stop $(CLUSTER_NAME)

status:
	@bash scripts/verify.sh

ui:
	@bash scripts/argocd-ui.sh

test:
	@bash ../tests/p3-test.sh

roundtrip:
	@bash ../tests/p3-test.sh --roundtrip

clean:
	@bash scripts/cleanup.sh

re: clean up

help:
	@echo "Part 3: K3d + Argo CD (GitOps from github.com/goncalo1021pt/gfontao-iot)"
	@echo ""
	@echo "  make install    - Install Docker, k3d and kubectl (uses sudo)"
	@echo "  make up         - Create the cluster, install Argo CD, deploy the app"
	@echo "  make down       - Stop the cluster (keeps its state)"
	@echo "  make status     - Show namespaces, Argo CD app, pods and the app response"
	@echo "  make ui         - Print the Argo CD login and open the UI (ARGOCD_UI_PORT=8443 to change port)"
	@echo "  make test       - Run p3 verification checks"
	@echo "  make roundtrip  - Same, plus a live v1 -> v2 -> v1 push to GitHub (needs push credentials)"
	@echo "  make clean      - Delete the cluster"
	@echo "  make re         - clean + up"
	@echo "  make help       - Show this help"
