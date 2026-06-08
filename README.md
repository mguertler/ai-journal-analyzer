# journal-ai-analyzer

`journal-ai-analyzer` is a single-file Python CLI that reads Linux `journalctl`
output in chunks, analyzes each chunk with an OpenAI-compatible API, and can
produce a final prioritized report.

The project intentionally uses one Python module only:

```text
.
├── README.md
├── LICENSE
├── Makefile
├── pyproject.toml
├── journal_ai_analyzer.conf.example
└── src/
    └── journal_ai_analyzer
```

There is no package directory, no `__main__.py`, no `__init__.py`, and no
separate `cli.py` or `config.py`. The installed command is created by the
entry point in `pyproject.toml`:

```toml
[project.scripts]
journal-ai-analyzer = "journal_ai_analyzer:main"
```

## Installation

Recommended:

```bash
pipx install .
```

Alternative user installation:

```bash
make install-user
```

Development/editable installation:

```bash
make dev
```

Do not install the script manually into `/usr/local/bin`; use the package entry
point instead.

## Configuration

The config path is independent of the pip, pipx, virtualenv, or `--user`
installation location. Config resolution order is:

1. `--config /path/to/config`
2. `JOURNAL_AI_ANALYZER_CONFIG=/path/to/config`
3. the default user config path from `platformdirs`

On Linux, the default path is typically:

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

## LiteLLM example

The example config is prepared for a local LiteLLM proxy:

```conf
openai.api_key = anything
openai.api_url = http://127.0.0.1:4000
openai.api_style = chat_completions
openai.model = local
```

The script normalizes this to the OpenAI-compatible endpoint:

```text
http://127.0.0.1:4000/v1/chat/completions
```

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
  --chunksize 1000 \
  --mode all
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
make dev
make config
make print-config
make uninstall
make clean
```

`make config` and `make print-config` intentionally call
`python3 src/journal_ai_analyzer ...` so they work from the repository before
the package has been installed.
