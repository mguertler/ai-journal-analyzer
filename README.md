# ai-journal-analyzer

**Turn noisy Linux logs into prioritized admin reports.**

`ai-journal-analyzer` is a small, lightweight CLI tool for Linux admins, homelab users, self-hosters and operators. It collects relevant systemd journal entries, plain log files or piped log data, filters known noise, splits large input into model-friendly chunks, and creates an actionable report using an OpenAI-compatible AI endpoint.

Use it to quickly answer:

- What is broken?
- How serious is it?
- What probably happened?
- When did it happen?
- How can I find it again?
- What should I check next?

It works with OpenAI-compatible cloud APIs, LiteLLM proxies, and local Ollama-style setups. No dashboard, database, or permanently running agent is required.

## Why?

Linux logs are noisy. Important problems are often buried between harmless warnings, desktop messages, repeated service noise, and low-value events.

`ai-journal-analyzer` turns that noise into a short, prioritized report that highlights what matters, why it matters, when it happened, how to search for it again, and what to check next.

## Highlights

- Lightweight CLI: no dashboard, no database, no permanently running agent
- Works with systemd journal, normal log files, and stdin
- Creates prioritized reports with actionable checks
- Keeps search commands for every finding
- Supports easy focusing on topics (`--focus-on "security incidents and network problems"`)
- Can ignore known noise without hiding the original input
- Supports local OpenAI-compatible endpoints such as LiteLLM and Ollama
- Suitable for daily cron-based email reports

## Quick examples

Analyze warnings and errors from the last 24 hours:

```bash
sudo ai-journal-analyzer --since "24 hours ago"
```

Analyze the current boot, including kernel/system events:

```bash
sudo ai-journal-analyzer --boot --kernel
```

Focus on security-relevant journal events and gently ignore desktop noise:

```bash
sudo ai-journal-analyzer \
  --since "24 hours ago" \
  --loglevel "info..alert" \
  --focus-on "security incidents, failed logins, sudo, ssh, authentication" \
  --gently-ignore "GNOME Desktop issues, printer warnings"
```

Analyze a normal log file:

```bash
ai-journal-analyzer --file /var/log/nginx/error.log --tail-lines 5000
```

Analyze piped log data:

```bash
tail -n 5000 /var/log/auth.log | ai-journal-analyzer --stdin --focus-on "failed logins and authentication problems"
```

Send a daily-style report by email:

```bash
sudo ai-journal-analyzer --since "24 hours ago" --mail admin@example.com --no-warn
```

## Example output

```text
Final report
============
Summary
-------
Several high-priority issues were found: possible cluster MTU mismatches, a potential
split-brain condition, and repeated external authentication probing.

Priority 1 - Fix soon
---------------------
* error: ocf resource cluster_sync might be active on 2 nodes (attempting recovery)
  Examples: 2026-06-08T13:39:10+02:00 (first seen, last seen)
  Search: journalctl --since "24 hours ago" -p warning..alert --no-pager -o short-iso | grep -E 'cluster_sync|active on 2 nodes|recovery'
  Impact: Critical split-brain scenario; high risk of data corruption.
  Action: Investigate cluster connectivity, fencing/STONITH, and resource state.

* [KNET] pmtud: possible MTU misconfiguration detected
  Examples: 2026-06-02T20:14:23+02:00 (first seen), 2026-06-05T00:35:39+02:00, 2026-06-07T06:43:56+02:00 (last seen)
  Search: journalctl --since "24 hours ago" -p warning..alert --no-pager -o short-iso | grep -E 'KNET|pmtud|MTU'
  Impact: Packet fragmentation, high latency, and possible cluster instability.
  Action: Verify MTU consistency across all network interfaces in the cluster.

Likely chain of events
----------------------
1. KNET detected possible MTU/path MTU issues.
2. Cluster links became unstable.
3. The cluster reported that a resource might be active on two nodes.

Recommended immediate checks
----------------------------
1. Check current cluster status.
2. Verify fencing/STONITH configuration.
3. Compare MTU settings on all cluster interfaces.
```

## What it can analyze

- systemd journal output via `journalctl`
- current boot logs via `--boot`
- kernel messages via `--kernel`
- selected systemd units via `--unit docker.service`
- plain log files via `--file /path/to/log`
- piped input via `--stdin`
- daily email reports via `--mail`

Useful filtering options:

- `--exclude-pattern` removes lines containing a simple keyword
- `--exclude-regex-pattern` removes lines matching a regular expression
- `--focus-on` restricts the analysis to a topic
- `--gently-ignore` asks the model to deprioritize known noise
- `--max-lines` prevents unexpectedly large and costly runs
- `--print-journal` lets you inspect the filtered input first
- `--dry-run` collects and counts lines without calling the AI endpoint

## Data handling and privacy

Logs may contain hostnames, usernames, IP addresses, file paths, service names, email addresses and security-relevant events. The tool warns before sending filtered data to the configured AI endpoint unless you use `--no-warn` or set `safety.no_warn = true`.

The endpoint can be local, self-hosted, or a third-party provider. For sensitive data, consider a local OpenAI-compatible endpoint such as LiteLLM or Ollama.

When run as a normal user, journal access may be incomplete. For full system journal access, run the tool with `sudo` or as root.

## Tested models

I have made good experience with running this tool against a local Gemma4-26b model with a 64k context size on an RTX 4090 with 24GB VRAM. Smaller models might work, and smaller context sizes might work, but this has to be tested for the specific workload and log volume. Larger, more capable models with context sizes >=64k should work even better.

## Installation

You have two installation options.

### a) `make install` - simple script installation

Recommended for most users:

```bash
sudo make install
```

This installs the standalone script and config file interactively. It does not require `pipx`.

If an existing config file is found, the installer can merge it with the new example config:

- existing values are kept
- new parameters and comments are added
- a timestamped backup is created first

If you run `make install` as a normal user, the installer warns and asks before continuing with a user-local installation.

### b) `make install-pipx` - Python package installation

```bash
make install-pipx
```

This installs the CLI through `pipx` and then runs the same interactive config setup. Requires `pipx`.

For development:

```bash
git clone https://github.com/mguertler/ai-journal-analyzer.git
cd ai-journal-analyzer
make dev
.venv/bin/ai-journal-analyzer --help
```

## Configuration

System-wide config:

```text
/usr/local/etc/ai-journal-analyzer.conf
```

User config:

```text
~/.config/ai-journal-analyzer/ai-journal-analyzer.conf
```

Print the default user config path:

```bash
ai-journal-analyzer --print-config-path
```

Use an explicit config file:

```bash
ai-journal-analyzer --config ./ai-journal-analyzer.conf
```

Use a config file via environment variable:

```bash
AI_JOURNAL_ANALYZER_CONFIG=/path/to/ai-journal-analyzer.conf ai-journal-analyzer
```

Config lookup order:

1. `--config /path/to/config`
2. `AI_JOURNAL_ANALYZER_CONFIG=/path/to/config`
3. `/usr/local/etc/ai-journal-analyzer.conf`, if it exists
4. user config path from `--print-config-path`

## API examples

OpenAI default:

```conf
openai.api_url = https://api.openai.com
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = gpt-5-mini
```

LiteLLM proxy:

```conf
openai.api_url = http://127.0.0.1:4000
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = local
```

Ollama OpenAI-compatible endpoint:

```conf
openai.api_url = http://127.0.0.1:11434
openai.api_path = /v1/chat/completions
openai.api_style = chat_completions
openai.model = gemma3:27b
```

## More usage examples

Analyze one systemd unit:

```bash
sudo ai-journal-analyzer --unit ssh.service --since "7 days ago"
```

Analyze multiple files:

```bash
ai-journal-analyzer \
  --file /var/log/nginx/error.log \
  --file /var/log/nginx/access.log \
  --tail-lines 10000
```

Inspect filtered input before analysis:

```bash
sudo ai-journal-analyzer --print-journal --since "24 hours ago"
```

Run without an API call:

```bash
sudo ai-journal-analyzer --dry-run --since "24 hours ago"
```

## Cron example for daily email reports

Edit root's crontab if the tool needs full access to the system journal:

```bash
sudo crontab -e
```

Run once every 24 hours at 06:00 and send an email report:

```cron
0 6 * * * /usr/local/bin/ai-journal-analyzer --config /usr/local/etc/ai-journal-analyzer.conf --since "24 hours ago" --mail admin@example.com --no-warn >>/var/log/ai-journal-analyzer.log 2>&1
```

Notes:

- `--no-warn` is recommended for cron after you have reviewed the privacy/cost warning.
- Configure SMTP settings in `ai-journal-analyzer.conf` before enabling `--mail`.
- For security-focused reports, `info..alert` may be more useful than `warning..alert`, because authentication and login-related events are often logged below warning level.

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

## License

GPL v2
