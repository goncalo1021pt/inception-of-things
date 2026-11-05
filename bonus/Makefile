.PHONY: install up down status ui test roundtrip clean re guard help
.DEFAULT_GOAL := help

CLUSTER_NAME ?= iot-bonus
export CLUSTER_NAME
# Part 3 and the bonus both publish port 8888: only one of them may run at a time.
OTHER_CLUSTER := iot

install:
	@bash scripts/install.sh

guard:
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -Fxq 'k3d-$(OTHER_CLUSTER)-serverlb'; then \
		echo "Error: the p3 cluster ($(OTHER_CLUSTER)) is running and holds port 8888."; \
		echo "Run 'make p3-clean' (or 'make p3-down') first."; \
		exit 1; \
	fi

up: guard
	@echo "Starting the bonus (k3d + GitLab + Argo CD)..."
	@echo "This may take 10-15 minutes on first run (GitLab is heavy)."
	@echo ""
	@k3d cluster start $(CLUSTER_NAME) >/dev/null 2>&1 || true
	bash scripts/setup.sh

down:
	k3d cluster stop $(CLUSTER_NAME)

status:
	@bash scripts/verify.sh

ui:
	@bash scripts/credentials.sh

test:
	@bash ../tests/bonus-test.sh

roundtrip:
	@bash ../tests/bonus-test.sh --roundtrip

clean:
	@bash scripts/cleanup.sh

re: clean up

help:
	@echo "Bonus: local GitLab (namespace gitlab) as the Git source of Argo CD"
	@echo ""
	@echo "  make install    - Install Docker, k3d, kubectl and Helm (uses sudo)"
	@echo "  make up         - Create the cluster, install GitLab + Argo CD, deploy the app"
	@echo "  make down       - Stop the cluster (keeps its state)"
	@echo "  make status     - Show namespaces, GitLab, Argo CD app and the app response"
	@echo "  make ui         - Print the GitLab / Argo CD logins and open the Argo CD UI"
	@echo "  make test       - Run bonus verification checks"
	@echo "  make roundtrip  - Same, plus a live v1 -> v2 -> v1 push to GitLab"
	@echo "  make clean      - Delete the cluster"
	@echo "  make re         - clean + up"
	@echo "  make help       - Show this help"
