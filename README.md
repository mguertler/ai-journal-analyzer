# journal-ai-analyzer

`journal-ai-analyzer` is a single-file Python CLI that reads Linux `journalctl`
output in chunks, analyzes each chunk with an OpenAI-compatible API, and can
produce a final prioritized report.

The project intentionally uses one Python source file only:

```text
.
├── README.md
├── LICENSE
├── Makefile
├── pyproject.toml
├── journal_ai_analyzer.conf.example
├── scripts/
│   └── install-simple.sh
└── src/
    └── journal_ai_analyzer
```

There is no package directory, no `__main__.py`, no `__init__.py`, and no
separate `cli.py` or `config.py`. The installed package command is created by
the entry point in `pyproject.toml`:

```toml
[project.scripts]
journal-ai-analyzer = "journal_ai_analyzer:main"
```

The repository source file is intentionally extensionless. During the wheel
build, Hatchling maps `src/journal_ai_analyzer` to the importable module
`journal_ai_analyzer.py`.

## Installation

You have two options to install this script.

### a) `make install`: Python package installation

Recommended when `pipx` is available:

```bash
make install
```

This installs the CLI as a Python package via `pipx`. It is safe on modern
Debian/Ubuntu systems with PEP 668 enabled because it does not write into the
externally managed system Python environment.

Equivalent explicit command:

```bash
make install-pipx
```

Configuration is then done manually:

```bash
make config
journal-ai-analyzer --print-config-path
```

### b) `make install-simple`: standalone script installation

Use this when you want a simple installation without pipx, packaging, or a
virtual environment:

```bash
make install-simple
```

This copies the single script and a config file into directories of your choice.
It also offers an interactive setup for the most important parameters:

- API key
- API base URL
- API path
- API style
- model
- chunk size in journal lines
- default log level
- default `journalctl --since` value
- timestamp output

Default target paths are:

- root: `/usr/local/bin/journal-ai-analyzer` and `/etc/journal-ai-analyzer/journal_ai_analyzer.conf`
- non-root: `~/.local/bin/journal-ai-analyzer` and `~/.config/journal_ai_analyzer/journal_ai_analyzer.conf`

At the end, the installer prints an example command using the installed config.

## Development

Development/editable installation uses a local virtual environment:

```bash
make dev
```

Then run the development command from the venv:

```bash
.venv/bin/journal-ai-analyzer --help
```

## Why pipx / .venv?

Modern Debian/Ubuntu Python installations often mark the system Python as an
externally managed environment. In that case, plain `python3 -m pip install .`
or `python3 -m pip install -e .` fail with `externally-managed-environment`.
This project therefore uses:

- `pipx` for normal package-based CLI installation
- a project-local `.venv` for development
- `make install-simple` for a direct standalone script installation

## Configuration

For package-based installs, the config path is independent of the pip, pipx,
virtualenv, or `--user` installation location. Config resolution order is:

1. `--config /path/to/config`
2. `JOURNAL_AI_ANALYZER_CONFIG=/path/to/config`
3. the default user config path from `platformdirs`, with a built-in fallback
   to `~/.config/journal_ai_analyzer/journal_ai_analyzer.conf` if
   `platformdirs` is not installed

On Linux, the default user path is typically:

```text
~/.config/journal_ai_analyzer/journal_ai_analyzer.conf
```

Print the default path:

```bash
journal-ai-analyzer --print-config-path
```

Install the example config into the user config directory:

```bash
make config
```

or directly:

```bash
journal-ai-analyzer --install-config journal_ai_analyzer.conf.example
```

Overwrite an existing config intentionally:

```bash
journal-ai-analyzer --install-config journal_ai_analyzer.conf.example --force
```

Use an explicit config file:

```bash
journal-ai-analyzer --config ./journal_ai_analyzer.conf
```

Use the environment variable:

```bash
JOURNAL_AI_ANALYZER_CONFIG=/path/to/journal_ai_analyzer.conf journal-ai-analyzer
```

## OpenAI defaults

The example config defaults to the OpenAI Responses API:

```conf
openai.api_key = ""
openai.api_url = https://api.openai.com
openai.api_path = /v1/responses
openai.api_style = responses
openai.model = gpt-5-mini
journal.chunksize = 300
```

`openai.api_url` is only the base URL. The endpoint is configured separately via
`openai.api_path`.

## LiteLLM example

For a local LiteLLM proxy, change the config to something like:

```conf
openai.api_key = anything
openai.api_url = http://127.0.0.1:4000
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = local
```

## Chunk size guidance

The default chunk size is intentionally conservative:

```conf
journal.chunksize = 300
```

Useful starting points:

- 100 lines: very safe for small/local models or noisy logs
- 200 lines: safe for many local models
- 300 lines: recommended default
- 500 lines: try only with larger/stable context windows
- 1000 lines: often too large in practice, even with nominal 64k contexts

## Usage examples

Analyze the last 12 hours with defaults from the config:

```bash
journal-ai-analyzer
```

Run with explicit options:

```bash
journal-ai-analyzer \
  --since "12 hours ago" \
  --loglevel "warning..alert" \
  --chunksize 300 \
  --mode all
```

Use LiteLLM explicitly from the command line:

```bash
journal-ai-analyzer \
  --api-url http://127.0.0.1:4000 \
  --api-path /v1/chat/completions \
  --api-style chat_completions \
  --model local
```

Include example journal timestamps in chunk findings and the final report:

```bash
journal-ai-analyzer --include-timestamps
```

Send the final report by email:

```bash
journal-ai-analyzer --mode report --mail admin@example.com
```

Local smoke test without API calls:

```bash
journal-ai-analyzer --dry-run
```

## Makefile

```bash
make help
make install
make install-user
make install-pipx
make install-simple
make dev
make config
make print-config
make uninstall
make clean
```

`make config` and `make print-config` intentionally call
`python3 src/journal_ai_analyzer ...` so they work from the repository before
the package has been installed.
