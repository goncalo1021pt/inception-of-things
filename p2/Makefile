.PHONY: up down status clean ssh reload help
.DEFAULT_GOAL := help

MACHINE_NAME := gfontaoS

up:
	@echo "Starting K3s server VM..."
	@echo "This may take 5-15 minutes on first run."
	@echo ""
	VAGRANT_DEFAULT_PROVIDER=virtualbox vagrant up

down:
	vagrant halt

status:
	vagrant status

clean:
	@vagrant destroy -f 2>/dev/null || true
	@rm -rf .vagrant

ssh:
	vagrant ssh $(MACHINE_NAME)

reload:
	vagrant reload --provision

help:
	@echo "Part 2: K3s + Ingress routing"
	@echo ""
	@echo "Quick start:"
	@echo "  make up           - Start the VM and deploy all apps"
	@echo ""
	@echo "All targets:"
	@echo "  make up           - Boot VM, install K3s, apply manifests"
	@echo "  make down         - Halt the VM"
	@echo "  make status       - Show VM status"
	@echo "  make clean        - Destroy VM and clean state"
	@echo "  make ssh          - SSH into the VM"
	@echo "  make reload       - Reload and re-provision"
	@echo ""
	@echo "After 'make up', test routing:"
	@echo "  curl -H 'Host: app1.com' 192.168.56.110   -> App 1"
	@echo "  curl -H 'Host: app2.com' 192.168.56.110   -> App 2"
	@echo "  curl 192.168.56.110                        -> App 3 (default)"
