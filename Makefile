.PHONY: help install check clean
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

# Every part has its own Makefile with the same verbs (up, down, status, clean, test, help).
# <part>-<target> forwards to it: `make p2-up` == `make -C p2 up`.
p1-%:
	@$(MAKE) -C p1 $*

p2-%:
	@$(MAKE) -C p2 $*

p3-%:
	@$(MAKE) -C p3 $*

bonus-%:
	@$(MAKE) -C bonus $*

help:
	@echo "Inception of Things - 42 Project"
	@echo ""
	@echo "Every part has the same targets:  make <part>-<target>   (part: p1 p2 p3 bonus)"
	@echo ""
	@echo "  <part>-up        Build and start the part"
	@echo "  <part>-down      Stop it (keeps state)"
	@echo "  <part>-status    Show its state"
	@echo "  <part>-test      Run its verification checks (tests/<part>-test.sh)"
	@echo "  <part>-clean     Destroy it and clean state"
	@echo "  <part>-re        clean + up (p3, bonus)"
	@echo "  <part>-help      Show that part's own help"
	@echo ""
	@echo "Parts:"
	@echo "  p1     2 Vagrant VMs, K3s server + agent       (extra: p1-ssh-server, p1-ssh-worker, p1-reload)"
	@echo "  p2     1 Vagrant VM, K3s, 3 apps behind Ingress (extra: p2-ssh, p2-reload, p2-hosts)"
	@echo "  p3     k3d + Argo CD, GitOps from GitHub        (extra: p3-install, p3-ui, p3-roundtrip)"
	@echo "  bonus  k3d + local GitLab + Argo CD             (extra: bonus-install, bonus-ui, bonus-roundtrip)"
	@echo ""
	@echo "Global:"
	@echo "  make install     Install Docker, k3d, kubectl and Helm (uses sudo; Vagrant/VirtualBox are not included)"
	@echo "  make check       Build, test and clean p1, p2, p3 and the bonus, one after the other (~40 min)"
	@echo "  make clean       Destroy everything"
	@echo ""
	@echo "Constraints: p1 and p2 share 192.168.56.110, p3 and the bonus share port 8888:"
	@echo "run one of each pair at a time (p3-up / bonus-up refuse to start if the other is running)."

install:
	@$(MAKE) -C bonus install

# Full regression: each part is built, tested and destroyed before the next one starts.
# Stops at the first failure and leaves that part up so it can be inspected.
check:
	@$(MAKE) p1-up p1-test p1-clean
	@$(MAKE) p2-up p2-test p2-clean
	@$(MAKE) p3-up p3-test p3-clean
	@$(MAKE) bonus-up bonus-test bonus-clean
	@echo ""
	@echo "All parts built, tested and cleaned."

clean:
	-@$(MAKE) p1-clean
	-@$(MAKE) p2-clean
	-@$(MAKE) p3-clean
	-@$(MAKE) bonus-clean
