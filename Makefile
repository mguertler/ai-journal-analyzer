.PHONY: help install install-user install-pipx install-simple dev uninstall config print-config clean

DIST_NAME := journal-ai-analyzer
CONFIG_EXAMPLE := journal_ai_analyzer.conf.example
PYTHON ?= python3
PIPX ?= pipx
VENV ?= .venv
VENV_PYTHON := $(VENV)/bin/python

help:
	@echo "Targets:"
	@echo "  make install       Install CLI tool as a Python package with pipx (recommended)"
	@echo "  make install-user  Alias for make install-pipx"
	@echo "  make install-pipx  Install CLI tool with pipx"
	@echo "  make install-simple Install as a standalone script and config file interactively"
	@echo "  make dev           Create/update local .venv and install editable"
	@echo "  make config        Install example config into the user config directory"
	@echo "  make print-config  Print default config path"
	@echo "  make uninstall     Uninstall from pipx, then try pip as fallback"
	@echo "  make clean         Remove build artifacts and local virtualenv"

install: install-pipx

install-user: install-pipx

install-simple:
	sh scripts/install-simple.sh

install-pipx:
	$(PIPX) install .

dev:
	$(PYTHON) -m venv $(VENV)
	$(VENV_PYTHON) -m pip install --upgrade pip
	$(VENV_PYTHON) -m pip install -e .
	@echo ""
	@echo "Development environment ready."
	@echo "Run: $(VENV)/bin/journal-ai-analyzer --help"

config:
	$(PYTHON) src/journal_ai_analyzer --install-config "$(CONFIG_EXAMPLE)"

print-config:
	$(PYTHON) src/journal_ai_analyzer --print-config-path

uninstall:
	-$(PIPX) uninstall $(DIST_NAME)
	-$(PYTHON) -m pip uninstall -y $(DIST_NAME)

clean:
	rm -rf build dist *.egg-info src/*.egg-info .pytest_cache .mypy_cache .ruff_cache $(VENV)
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
