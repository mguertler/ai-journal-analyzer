.PHONY: help install install-user install-pipx dev uninstall config print-config clean

DIST_NAME := journal-ai-analyzer
CONFIG_EXAMPLE := journal_ai_analyzer.conf.example

help:
	@echo "Targets:"
	@echo "  make install       Install into the current Python environment"
	@echo "  make install-user  Install for the current user with pip"
	@echo "  make install-pipx  Install CLI tool with pipx"
	@echo "  make dev           Install in editable/development mode"
	@echo "  make config        Install example config into the user config directory"
	@echo "  make print-config  Print default config path"
	@echo "  make uninstall     Uninstall package"
	@echo "  make clean         Remove build artifacts"

install:
	python3 -m pip install .

install-user:
	python3 -m pip install --user .

install-pipx:
	pipx install .

dev:
	python3 -m pip install -e .

config:
	python3 -m journal_ai_analyzer --install-config "$(CONFIG_EXAMPLE)"

print-config:
	python3 -m journal_ai_analyzer --print-config-path

uninstall:
	python3 -m pip uninstall -y $(DIST_NAME)

clean:
	rm -rf build dist *.egg-info src/*.egg-info
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
