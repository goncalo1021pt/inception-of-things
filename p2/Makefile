.PHONY: up down status clean ssh reload test hosts help
.DEFAULT_GOAL := help

MACHINE_NAME := gfontao-S

up:
	@echo "Starting P2 K3s instance..."
	@echo "This may take 5-10 minutes on first run."
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
