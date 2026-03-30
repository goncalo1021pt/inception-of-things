.PHONY: up down status clean ssh-server ssh-worker reload help
.DEFAULT_GOAL := help

MACHINE_NAME_S := gfontao-S
MACHINE_NAME_W := gfontao-SW


up:
	@echo "Starting K3S Cluster with Vagrant..."
	@echo "This may take 5-15 minutes on first run."
	@echo "Do NOT interrupt this process."
	@echo ""
	VAGRANT_DEFAULT_PROVIDER=virtualbox vagrant up

down:
	vagrant halt

status:
	vagrant status

clean:
	@vagrant destroy -f 2>/dev/null || true
	@rm -rf .vagrant
	@rm -f k3s-token

ssh-server:
	vagrant ssh $(MACHINE_NAME_S)

ssh-worker:
	vagrant ssh $(MACHINE_NAME_W)

reload:
	vagrant reload

help:
	@echo "Part 1: Vagrant K3S Setup"
	@echo ""
	@echo "Quick start:"
	@echo "  make up           - Start the K3S cluster (one command, full automation)"
	@echo ""
	@echo "All targets:"
	@echo "  make up           - Start VMs with K3S (master + worker)"
	@echo "  make down         - Stop the VMs"
	@echo "  make status       - Show VM status"
	@echo "  make clean        - Destroy VMs and clean state"
	@echo "  make ssh-server   - SSH into K3S master ($(MACHINE_NAME_S))"
	@echo "  make ssh-worker   - SSH into K3S worker ($(MACHINE_NAME_W))"
	@echo "  make reload       - Reload and re-provision VMs"
	@echo "  make help         - Show this help"
