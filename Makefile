.PHONY: help p1-up p1-down p1-status p1-clean p1-ssh-server p1-ssh-worker \
	p2-up p2-down p2-status p2-clean p2-ssh-server
.DEFAULT_GOAL := help

help:
	@echo "Inception of Things - 42 Project"
	@echo ""
	@echo "Quick Start:"
	@echo "  make p1-up        - Start Part 1 K3S cluster (full automation)"
	@echo "  make p2-up        - Start Part 2 K3S server (full automation)"
	@echo ""
	@echo "Part 1 Targets:"
	@echo "  make p1-up         - Start K3S cluster with 2 nodes (master + worker)"
	@echo "  make p1-down       - Stop Part 1 VMs"
	@echo "  make p1-status     - Show Part 1 VM status"
	@echo "  make p1-clean      - Destroy Part 1 VMs and clean state"
	@echo "  make p1-ssh-server - SSH into K3S master"
	@echo "  make p1-ssh-worker - SSH into K3S worker"
	@echo ""
	@echo "Part 2 Targets:"
	@echo "  make p2-up         - Start the VM with K3S in server mode"
	@echo "  make p2-down       - Stop Part 2 VM"
	@echo "  make p2-status     - Show Part 2 VM status"
	@echo "  make p2-clean      - Destroy Part 2 VM and clean state"
	@echo "  make p2-ssh-server - SSH into K3S server"
	@echo ""
	@echo "After 'make p1-up' / 'make p2-up', verify with:"
	@echo "  make p1-ssh-server   (or p2-ssh-server)"
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

p2-up:
	@$(MAKE) -C p2 up

p2-down:
	@$(MAKE) -C p2 down

p2-status:
	@$(MAKE) -C p2 status

p2-clean:
	@$(MAKE) -C p2 clean

p2-ssh-server:
	@$(MAKE) -C p2 ssh-server
