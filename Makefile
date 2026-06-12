# ═══════════════════════════════════════════════════════════════════════
#  RAGF Monorepo · Root Makefile
# ═══════════════════════════════════════════════════════════════════════
#
#  Conventions:
#    - Targets prefixed with a component name (e.g. `test-auditor`,
#      `lint-auditor`) delegate to that component's own Makefile or
#      tooling. The root Makefile is an ORCHESTRATOR, not a duplicator
#      of per-component logic.
#    - Targets without a prefix operate on the monorepo as a whole
#      (e.g. `test-all`, `lint-all`) and aggregate per-component
#      delegates.
#    - Docker-compose targets manage the runtime services (gateway +
#      Neo4j + TimescaleDB + Redis) declared in docker-compose.yml.
#      They do NOT touch the harness_auditor's ephemeral sandbox,
#      which is managed by harness_auditor/Makefile and runs on its
#      own Docker network (ragf-auditor-net) and port (7687 by default).
#
#  Python binary:
#    Defaults to `python3`. Override for any target via:
#      make <target> PYTHON=/path/to/python
#
#  See pyproject.toml at the repo root for shared ruff / mypy / pytest
#  configuration that all Python components inherit.
# ═══════════════════════════════════════════════════════════════════════

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

PYTHON ?= python3
PIP    := $(PYTHON) -m pip

# ─────────────── Help (auto-generated from comments) ────────────────────
.PHONY: help
help:  ## Show this help
	@echo "════════════════════════════════════════════════════════════════"
	@echo " RAGF Monorepo · Available targets"
	@echo "════════════════════════════════════════════════════════════════"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z][a-zA-Z0-9_-]*:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Component-specific targets:"
	@echo "  harness_auditor : run \`make -C harness_auditor help\`"
	@echo ""

# ─────────────── Environment diagnostics ────────────────────────────────
.PHONY: check-python
check-python:  ## Verify the Python binary used by this Makefile
	@if ! command -v $(PYTHON) >/dev/null 2>&1; then \
	  echo "ERROR: '$(PYTHON)' not found in PATH." >&2; \
	  exit 1; \
	fi
	@echo "PYTHON   : $(PYTHON)"
	@echo "Resolved : $$(command -v $(PYTHON))"
	@$(PYTHON) --version

# ─────────────── Runtime services (gateway + Neo4j + TimescaleDB) ───────
.PHONY: init
init:  ## First-time initialization (copies .env.example to .env if absent)
	@if [ ! -f .env ]; then \
	  cp .env.example .env; \
	  echo "WARN: copy .env.example → .env complete. Edit .env before make up." >&2; \
	fi
	@echo "Init complete. Next: edit .env then run 'make up'."

.PHONY: build
build:  ## Build runtime Docker images (no cache)
	docker-compose build --no-cache

.PHONY: up
up:  ## Start runtime services in the background
	docker-compose up -d
	@sleep 10
	@$(MAKE) status

.PHONY: down
down:  ## Stop runtime services
	docker-compose down

.PHONY: status
status:  ## Show running container status
	@docker-compose ps

.PHONY: logs
logs:  ## Follow logs from all runtime services
	docker-compose logs -f

.PHONY: shell
shell:  ## Open a bash shell inside the API container
	docker-compose exec api /bin/bash

.PHONY: shell-neo4j
shell-neo4j:  ## Open a cypher-shell inside the Neo4j container
	docker-compose exec neo4j cypher-shell -u neo4j -p ragf_secure_2026

.PHONY: seed
seed:  ## Load ontology schema + aviation seed into Neo4j
	@docker-compose exec -T neo4j cypher-shell -u neo4j -p ragf_secure_2026 < gateway/ontologies/schema.cypher
	@docker-compose exec -T neo4j cypher-shell -u neo4j -p ragf_secure_2026 < gateway/ontologies/aviation_seed.cypher
	@echo "Ontologies loaded."

.PHONY: health
health:  ## Probe the health of API and Neo4j UI
	@curl -s http://localhost:8001/health | $(PYTHON) -m json.tool 2>&1 || echo "API not responding"
	@curl -s http://localhost:7475 > /dev/null && echo "Neo4j UI: http://localhost:7475 (up)" || echo "Neo4j UI not responding"

.PHONY: restart
restart: down up  ## Restart the runtime stack (down + up)

# ─────────────── Testing (orchestrated across components) ───────────────
.PHONY: test
test: test-all  ## Alias for test-all

.PHONY: test-all
test-all: test-runtime test-auditor  ## Run every component's test suite

.PHONY: test-runtime
test-runtime: check-python  ## Test the runtime (gateway, ragf_core, shared)
	$(PYTHON) -m pytest tests/ -v

.PHONY: test-auditor
test-auditor:  ## Test the harness_auditor (delegates to its Makefile)
	$(MAKE) -C harness_auditor test

.PHONY: test-auditor-fast
test-auditor-fast:  ## Test the harness_auditor without Neo4j (delegates)
	$(MAKE) -C harness_auditor test-fast

.PHONY: smoke
smoke:  ## Run smoke tests (3 critical scenarios)
	docker-compose exec api pytest tests/smoke_test.py -v

# ─────────────── Linting (orchestrated across components) ───────────────
.PHONY: lint
lint: lint-all  ## Alias for lint-all

.PHONY: lint-all
lint-all: lint-runtime lint-auditor  ## Lint every component

.PHONY: lint-runtime
lint-runtime: check-python  ## Ruff + mypy on gateway, ragf_core, shared
	$(PYTHON) -m ruff check gateway ragf_core shared tests
	$(PYTHON) -m mypy gateway ragf_core shared

.PHONY: lint-auditor
lint-auditor:  ## Lint the harness_auditor (delegates to its Makefile)
	$(MAKE) -C harness_auditor lint

# ─────────────── Installation ───────────────────────────────────────────
.PHONY: install
install: check-python  ## Install runtime dependencies (requirements.txt)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

.PHONY: install-auditor
install-auditor:  ## Editable install of harness_auditor with dev extras
	$(MAKE) -C harness_auditor install

.PHONY: install-all
install-all: install install-auditor  ## Install everything

# ─────────────── Benchmarks and analysis ────────────────────────────────
.PHONY: benchmark
benchmark:  ## Run the runtime benchmark suite (latency + throughput)
	docker-compose exec api pytest tests/benchmark/benchmark_suite.py -v

.PHONY: benchmark-graph
benchmark-graph: check-python  ## Reproduce the Neo4j vs PostgreSQL benchmark
	@echo "Running graph-vs-relational benchmark (1,000 iterations per query)..."
	@echo "See benchmark/README.md for context. Results land in benchmark/results/."
	$(PYTHON) benchmark/queries/run_benchmark.py
	$(PYTHON) benchmark/queries/run_scale_benchmark.py
	$(PYTHON) benchmark/queries/plot_results.py

.PHONY: analyze-escalations
analyze-escalations: check-python  ## Regenerate escalation metrics for the paper
	$(PYTHON) scripts/analyze_escalations.py

# ─────────────── Cleanup ────────────────────────────────────────────────
.PHONY: clean
clean:  ## Remove Docker volumes, caches, and generated outputs
	docker-compose down -v
	docker system prune -f
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .mypy_cache .ruff_cache

.PHONY: clean-results
clean-results:  ## Remove generated analysis outputs (keep checked-in artefacts)
	rm -rf results/escalation_analysis/*

# ─────────────── Watch (live diagnostics) ───────────────────────────────
.PHONY: watch
watch:  ## Live container resource usage
	watch -n 2 'docker stats --no-stream'
