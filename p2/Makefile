.PHONY: up down status clean ssh-server reload help
.DEFAULT_GOAL := help

MACHINE_NAME_S := gfontao-S


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

ssh-server:
	vagrant ssh $(MACHINE_NAME_S)

reload:
	vagrant reload

help:
	@echo "Part 2: K3S Server + three applications"
	@echo ""
	@echo "Quick start:"
	@echo "  make up           - Start the K3S server VM (one command, full automation)"
	@echo ""
	@echo "All targets:"
	@echo "  make up           - Start the VM with K3S in server mode"
	@echo "  make down         - Stop the VM"
	@echo "  make status       - Show VM status"
	@echo "  make clean        - Destroy VM and clean state"
	@echo "  make ssh-server   - SSH into K3S server ($(MACHINE_NAME_S))"
	@echo "  make reload       - Reload and re-provision the VM"
	@echo "  make help         - Show this help"
