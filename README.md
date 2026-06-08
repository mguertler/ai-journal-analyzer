# journal-ai-analyzer

`journal-ai-analyzer` is a small Linux CLI tool that reads `journalctl` output in line-based chunks, sends each chunk to an OpenAI-compatible API, and optionally creates a final prioritized report.

The project is intentionally a single-file CLI:

```text
src/journal_ai_analyzer
```

There is no package directory, no `cli.py`, no `config.py`, no `__main__.py`, and no `__init__.py`.

## Installation

You have two options to install this script.

### a) `make install`

Install as a standalone script and config file in a directory of your choice with interactive parameter setup.

```bash
make install
```

This is the simple path. It does not require `pipx`. It asks where to install the script and config file, then optionally asks for the most important settings.

The installer starts with this hint:

```text
INFO: To install this script as python package use 'make install-pipx'; requires pipx on your system.
```

### b) `make install-pipx`

Install as a Python package. Requires `pipx`. Configuration is done manually.

```bash
make install-pipx
```

## Development install

```bash
make dev
.venv/bin/journal-ai-analyzer --help
```

## Configuration

Print the default user config path:

```bash
journal-ai-analyzer --print-config-path
```

Install the example config into the default user config path:

```bash
make config
```

Use an explicit config file:

```bash
journal-ai-analyzer --config ./journal-ai-analyzer.conf
```

Use a config file via environment variable:

```bash
JOURNAL_AI_ANALYZER_CONFIG=/path/to/journal-ai-analyzer.conf journal-ai-analyzer
```

The config lookup order is:

1. `--config /path/to/config`
2. `JOURNAL_AI_ANALYZER_CONFIG=/path/to/config`
3. `/usr/local/etc/journal-ai-analyzer.conf`, if it exists
4. legacy `/usr/local/etc/journal_ai_analyzer.conf`, if it exists
5. user config path from `platformdirs`, usually `~/.config/journal-ai-analyzer/journal-ai-analyzer.conf`

## API defaults

The default API mode is Chat Completions because it works reliably with OpenAI-compatible servers, LiteLLM, and Ollama:

```conf
openai.api_url = https://api.openai.com
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = gpt-5-mini
```

For LiteLLM:

```conf
openai.api_url = http://127.0.0.1:4000
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = local
```

For Ollama direct:

```conf
openai.api_url = http://127.0.0.1:11434
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = gemma3:27b
```

`openai.api_url` is always only the base URL. The endpoint path is configured separately with `openai.api_path`.

## Example usage

```bash
journal-ai-analyzer --since "24 hours ago" --mode all
```

With explicit config:

```bash
journal-ai-analyzer --config ./journal-ai-analyzer.conf --since "24 hours ago" --mode all
```

Suppress the privacy and cost warning after you have reviewed the implications:

```bash
journal-ai-analyzer --config ./journal-ai-analyzer.conf --since "24 hours ago" --mode report --no-warn
```

Debug chunk handling:

```bash
journal-ai-analyzer --config ./journal-ai-analyzer.conf --debug-ai
```

Dry run without API calls:

```bash
journal-ai-analyzer --config ./journal-ai-analyzer.conf --dry-run
```

## Journal filtering and scoping

Use simple keyword excludes when you want to remove known noisy lines before they are sent to the AI:

```bash
journal-ai-analyzer --exclude-pattern "harmless noisy message"
```

For regular expressions, use the explicit regex option:

```bash
journal-ai-analyzer --exclude-regex-pattern "^.*mpt3sas_cm0: log_info\(0x30030109\).*$"
```

Use `--gently-ignore` for semantic AI guidance. The journal lines are still sent to the model, but the model is told not to report matching topics unless they are severe:

```bash
journal-ai-analyzer --gently-ignore "GNOME desktop problems, printer warnings"
```

Use `--focus-on` to bias both chunk analysis and final reporting. Matching final-report items are marked with `[FOCUS]`:

```bash
journal-ai-analyzer --focus-on "all problems related to networking"
```

Use journalctl-native filters for common scopes:

```bash
# Kernel messages, equivalent to journalctl -k
journal-ai-analyzer --kernel

# Current boot, equivalent to journalctl -b
journal-ai-analyzer --boot

# Specific services/units, equivalent to journalctl -u docker.service -u ssh.service
journal-ai-analyzer --unit docker.service --unit ssh.service
```

The same options are available in the config file as `journal.kernel`, `journal.boot`, and `journal.units`. If `--kernel` and `--unit` are combined, the script uses journalctl OR matches so kernel messages and selected units are both included.

## Cron example for daily email reports

Edit root's crontab if the tool needs full access to the system journal:

```bash
sudo crontab -e
```

Run once every 24 hours at 06:00 and send an email report:

```cron
0 6 * * * /usr/local/bin/journal-ai-analyzer --config /usr/local/etc/journal-ai-analyzer.conf --since "24 hours ago" --mode report --mail admin@example.com --no-warn >>/var/log/journal-ai-analyzer.log 2>&1
```

Notes:

- `--no-warn` is recommended for cron after you have reviewed the privacy and cost warning.
- Depending on your system, access to the full journal may require root or membership in the `systemd-journal` group.
- Configure SMTP settings in `journal-ai-analyzer.conf` before enabling `--mail`.

## Make targets

```text
make help
make install
make install-simple
make install-pipx
make dev
make config
make print-config
make uninstall
make clean
```

## Notes

The default chunk size is 500 journal lines. This is the recommended default and usually works well for a 64k context-size thinking model. Use lower values such as 200 or 300 for smaller local models or noisy logs.

Example timestamps are enabled by default so that findings can be searched later in the journal.
