# ai-journal-analyzer

**Turn noisy Linux logs into prioritized admin reports.**

`ai-journal-analyzer` is a small, lightweight CLI tool for Linux admins, homelab users, self-hosters and operators. It collects relevant systemd journal entries, plain log files or piped log data, filters known noise, splits large input into model-friendly chunks, and creates an actionable report using an OpenAI-compatible AI endpoint.

**Use it to quickly answer:**

- What is broken?
- How serious is it?
- What probably happened?
- When did it happen?
- How can I find it again?
- What should I check next?

**Or use it to generate daily system reports by email:**

- What is going on across the system?
- Which issues need attention?

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
Critical hardware alerts indicate extreme disk temperature, RAID degradation and repeated thermal sensor failures. Additional service issues affect IMAP TLS connections, container DNS resolution and mail retrieval. Immediate checks should focus on disk health, RAID status and sensor availability.

Priority 1 - Fix soon
---------------------
* Extreme Disk Temperature and RAID Instability
  Impact: Possible disk failure and data loss risk on a degraded RAID array.
  Examples: 2026-06-10T21:43:56+02:00 (first seen), 2026-06-11T01:13:55+02:00 (last seen)
  Search: journalctl --since '24 hours ago' -p info..warning --no-pager -o short-iso | grep -E 'smartd.*Temperature_Celsius|mdadm.*DeviceDisappeared'
  Recommended commands/checks: Run `smartctl -a /dev/sdX`; run `mdadm --detail /dev/mdX`.

* Thermal Management Sensor Failure
  Impact: Cooling control repeatedly enters failsafe mode because a sensor cannot be read.
  Examples: 2026-06-10T21:12:01+02:00 (first seen), 2026-06-11T20:50:01+02:00 (last seen)
  Search: journalctl --since '24 hours ago' -p info..warning --no-pager -o short-iso | grep -E 'coolercontrold.*(failsafe|unreadable)'
  Recommended commands/checks: Check sensor paths in `/sys/class/hwmon/`; inspect `dmesg` for driver or hardware errors.

Priority 2 - Investigate
------------------------
* IMAP TLS Certificate Trust Issues
  Impact: Some clients cannot establish trusted TLS connections to the mail service.
  Examples: 2026-06-10T22:01:18+02:00 (first seen), 2026-06-11T20:16:00+02:00 (last seen)
  Search: journalctl --since '24 hours ago' -p info..warning --no-pager -o short-iso | grep -E 'dovecot.*(SSL_accept|certificate unknown)'

* Container DNS Resolution Failures
  Impact: Containers intermittently fail to resolve external hostnames due to upstream DNS timeouts.
  Examples: 2026-06-11T17:15:07+02:00 (first seen, last seen)
  Search: journalctl --since '24 hours ago' -p info..warning --no-pager -o short-iso | grep -E 'dockerd.*resolver.*failed'

* Mail Retrieval Timeouts
  Impact: Scheduled mail retrieval may be delayed or fail because remote connections time out.
  Examples: 2026-06-10T21:29:22+02:00 (first seen), 2026-06-11T18:13:15+02:00 (last seen)
  Search: journalctl --since '24 hours ago' -p info..warning --no-pager -o short-iso | grep -E 'fetchmail.*timeout'

Priority 3 - Monitor
--------------------
* Mail Server Configuration and Scanner Noise
  Impact: Repeated configuration warnings and automated internet scanning increase log volume.
  Examples: 2026-06-10T22:44:03+02:00 (first seen), 2026-06-11T15:25:55+02:00 (last seen)
  Search: journalctl --since '24 hours ago' -p info..warning --no-pager -o short-iso | grep -E 'postfix.*(NIS|writable|non-SMTP)'

Recommended immediate checks
----------------------------
1. Check disk health: `smartctl -a /dev/sdX`
2. Check RAID status: `mdadm --detail /dev/mdX`
3. Inspect kernel logs: `dmesg | grep -Ei 'error|fail|critical'`
4. Verify sensor accessibility: `ls -l /sys/class/hwmon/`
5. Check mail certificate validity: `openssl x509 -in <cert_path> -text -noout`
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
openai.model = Gemma4-26b
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
