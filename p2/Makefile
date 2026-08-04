<<<<<<< HEAD
.PHONY: up down status clean ssh reload help
.DEFAULT_GOAL := help

MACHINE_NAME := gfontaoS

up:
	@echo "Starting K3s server VM..."
	@echo "This may take 5-15 minutes on first run."
=======
.PHONY: up down status clean ssh reload test hosts help
.DEFAULT_GOAL := help

MACHINE_NAME := gfontao-S

up:
	@echo "Starting P2 K3s instance..."
	@echo "This may take 5-10 minutes on first run."
>>>>>>> fix/p1-internal-provision-ip
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
<<<<<<< HEAD
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
=======
	vagrant reload

hosts:
	@bash scripts/setup-hosts.sh

test:
	@bash ../tests/p2-test.sh

help:
	@echo "Part 2: K3s + Three Applications"
	@echo ""
	@echo "  make up      - Start the VM and deploy apps"
	@echo "  make down    - Stop the VM"
	@echo "  make status  - Show VM status"
	@echo "  make clean   - Destroy VM and clean state"
	@echo "  make ssh     - SSH into the VM"
	@echo "  make reload  - Reload and re-provision"
	@echo "  make hosts   - Add app1/2/3.com to /etc/hosts (idempotent)"
	@echo "  make test    - Run p2 verification checks"
	@echo "  make help    - Show this help"
>>>>>>> fix/p1-internal-provision-ip
