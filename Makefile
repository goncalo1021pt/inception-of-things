.PHONY: help p1-up p1-down p1-status p1-clean p1-ssh-server p1-ssh-worker \
        p2-up p2-down p2-status p2-clean p2-ssh p2-reload
.DEFAULT_GOAL := help

help:
	@echo "Inception of Things - 42 Project"
	@echo ""
	@echo "Quick Start:"
	@echo "  make p1-up        - Start Part 1 K3s cluster (server + worker)"
	@echo "  make p2-up        - Start Part 2 K3s server with 3 routed apps"
	@echo ""
	@echo "Part 1 Targets:"
	@echo "  make p1-up         - Start K3s cluster with 2 nodes (master + worker)"
	@echo "  make p1-down       - Stop Part 1 VMs"
	@echo "  make p1-status     - Show Part 1 VM status"
	@echo "  make p1-clean      - Destroy Part 1 VMs and clean state"
	@echo "  make p1-ssh-server - SSH into K3s master"
	@echo "  make p1-ssh-worker - SSH into K3s worker"
	@echo ""
	@echo "Part 2 Targets:"
	@echo "  make p2-up         - Boot VM, install K3s, deploy 3 apps with Ingress"
	@echo "  make p2-down       - Stop Part 2 VM"
	@echo "  make p2-status     - Show Part 2 VM status"
	@echo "  make p2-clean      - Destroy Part 2 VM and clean state"
	@echo "  make p2-ssh        - SSH into Part 2 VM"
	@echo "  make p2-reload     - Reload and re-provision"
	@echo ""
	@echo "After 'make p2-up', test with:"
	@echo "  curl -H 'Host: app1.com' 192.168.56.110"
	@echo "  curl -H 'Host: app2.com' 192.168.56.110"
	@echo "  curl 192.168.56.110"

p2-up:
	@$(MAKE) -C p2 up

p2-down:
	@$(MAKE) -C p2 down

p2-status:
	@$(MAKE) -C p2 status

p2-clean:
	@$(MAKE) -C p2 clean

p2-ssh:
	@$(MAKE) -C p2 ssh

p2-reload:
	@$(MAKE) -C p2 reload

p1-up:
	@$(MAKE) -C p1 up

p1-down:
	@$(MAKE) -C p1 down

p1-status:
	@$(MAKE) -C p1 status

p1-clean:
	@$(MAKE) -C p1 clean

p1-ssh-server:
	@$(MAKE) -C p1 ssh-server

p1-ssh-worker:
	@$(MAKE) -C p1 ssh-worker
