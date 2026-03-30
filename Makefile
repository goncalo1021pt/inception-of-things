.PHONY: help p1-up p1-down p1-status p1-clean p1-ssh-server p1-ssh-worker
.DEFAULT_GOAL := help

help:
	@echo "Inception of Things - 42 Project"
	@echo ""
	@echo "Quick Start:"
	@echo "  make p1-up        - Start Part 1 K3S cluster (full automation)"
	@echo ""
	@echo "Part 1 Targets:"
	@echo "  make p1-up         - Start K3S cluster with 2 nodes (master + worker)"
	@echo "  make p1-down       - Stop Part 1 VMs"
	@echo "  make p1-status     - Show Part 1 VM status"
	@echo "  make p1-clean      - Destroy Part 1 VMs and clean state"
	@echo "  make p1-ssh-server - SSH into K3S master"
	@echo "  make p1-ssh-worker - SSH into K3S worker"
	@echo ""
	@echo "After 'make p1-up', verify with:"
	@echo "  make p1-ssh-server"
	@echo "  kubectl get nodes"

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
