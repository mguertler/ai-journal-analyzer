# ai-journal-analyzer

**AI-assisted reports for Linux systemd journal logs.**

`ai-journal-analyzer` is a command-line tool that collects relevant `journalctl` entries,
filters known noise, and generates a structured report using a configured AI endpoint.

It is intended for Linux admins, homelab users, self-hosters and operators who want a quicker
overview of recent system warnings, errors or security-relevant events without manually reading
large amounts of journal output.

```bash
ai-journal-analyzer --boot --since "24 hours ago"
```

```bash
ai-journal-analyzer \
  --since "24 hours ago" \
  --loglevel "warning..alert" \
  --focus-on "network problems" \
  --gently-ignore "GNOME Desktop issues"
```

```bash
ai-journal-analyzer \
  --since "24 hours ago" \
  --loglevel "info..alert" \
  --focus-on "security incidents, failed logins, sudo, ssh, authentication" \
  --mail admin@example.com
```

## Example output

```text
Final report
============
Summary
-------
Several high-priority issues were found in the analyzed journal data: repeated hardware
sensor failures, possible cluster network MTU mismatches, and a potential split-brain
condition. Security-relevant findings include insecure Postfix certificate directory
permissions and repeated external SMTP/SASL probing.

Priority 1 - Fix soon
---------------------
* Custom Sensor sensor1 entering failsafe (100C): file unreadable
  First seen: 2026-06-02T20:04:01+02:00
  Last seen:  2026-06-09T19:58:01+02:00
  Examples:   2026-06-02T20:04:01+02:00, 2026-06-07T06:54:02+02:00
  Impact: Potential hardware overheating and thermal throttling/shutdown.
  Action: Check physical thermals, sensor drivers, and sysfs file permissions.

* [KNET] pmtud: possible MTU misconfiguration detected
  First seen: 2026-06-02T20:14:23+02:00
  Last seen:  2026-06-07T06:43:56+02:00
  Examples:   2026-06-02T20:14:23+02:00, 2026-06-05T00:35:39+02:00
  Impact: Packet fragmentation, high latency, and possible cluster instability.
  Action: Verify MTU consistency across all network interfaces in the Corosync cluster.

* error: ocf resource cluster_sync might be active on 2 nodes (attempting recovery)
  First seen: 2026-06-08T13:39:10+02:00
  Last seen:  2026-06-08T13:39:10+02:00
  Examples:   2026-06-08T13:39:10+02:00
  Impact: Critical split-brain scenario; high risk of data corruption.
  Action: Investigate cluster connectivity, fencing/STONITH, and resource state.

* warning: group or other writable: /etc/postfix/ssl/exampleCA
  First seen: 2026-06-02T23:53:06+02:00
  Last seen:  2026-06-09T04:00:26+02:00
  Examples:   2026-06-02T23:53:06+02:00, 2026-06-06T04:00:10+02:00
  Impact: Security risk; certificate material may be writable by unauthorized users.
  Action: Restrict write access to owner/root only.

Priority 2 - Investigate
------------------------
* clamav-clamonacc.service: Main process exited, code=killed, status=9/KILL
  First seen: 2026-06-02T23:51:25+02:00
  Last seen:  2026-06-06T01:12:20+02:00
  Impact: On-access malware scanning may be unavailable.
  Action: Check for OOM killer events, memory pressure, or manual service termination.

* warning: non-SMTP command / SASL LOGIN authentication failed from external IPs
  First seen: 2026-06-03T21:55:31+02:00
  Last seen:  2026-06-08T07:15:31+02:00
  Examples:   2026-06-03T21:55:31+02:00, 2026-06-08T03:52:16+02:00
  Impact: Potential automated scanning or brute-force attempts.
  Action: Review firewall/fail2ban rules and Postfix authentication policy.

Priority 3 - Monitor
--------------------
* kernel: BTRFS warning: space cache v1 is being deprecated
  First seen: 2026-06-03T06:00:31+02:00
  Last seen:  2026-06-03T06:00:31+02:00
  Action: Plan to remount the device with 'space_cache=v2' in future updates.

Notes
-----
* The KNET MTU warnings and cluster resource recovery event may be related and should be
  investigated together.
* Some lower-priority desktop/session warnings were intentionally omitted from this report.
```

## What it does

`journalctl` is powerful, but real systems often produce a lot of repeated, unrelated or
low-priority warnings.

`ai-journal-analyzer` summarizes selected journal output into a structured report with:

- short summary
- prioritized findings
- likely impact
- example timestamps
- suggested checks or next actions
- optional focus topics
- optional ignored low-priority noise

The tool does not replace normal system administration, monitoring or incident response.
It is intended as an additional triage aid.

## Data handling and privacy considerations

System journal data may contain sensitive information, including hostnames, usernames,
IP addresses, email addresses, file paths, service names, error messages and security-relevant
events.

Before using the tool, make sure the configured AI endpoint is appropriate for the data you
are sending.

Depending on your configuration, the endpoint may be:

- a local model or local OpenAI-compatible API
- a self-hosted service
- a third-party API provider

The tool provides options to inspect and reduce the data before analysis:

- `--dry-run` collects and counts journal lines without calling the AI endpoint
- `--print-journal` prints the filtered journal lines before analysis
- `--exclude-pattern` removes lines containing a specific keyword
- `--exclude-regex-pattern` removes lines matching a regular expression
- `--gently-ignore` asks the model to deprioritize known noise
- system-wide and user configuration files can define defaults

The tool warns before sending journal data to the configured AI endpoint unless this warning
is disabled explicitly.

## Daily report example

A common use case is a daily report by email:

```bash
ai-journal-analyzer \
  --since "24 hours ago" \
  --loglevel "info..alert" \
  --focus-on "security incidents, failed logins, sudo, ssh, authentication, privilege escalation" \
  --gently-ignore "GNOME Desktop issues, harmless desktop session noise" \
  --include-timestamps \
  --mode report \
  --mail admin@example.com
```

This can be run manually, from cron, or from a systemd timer.

For security-focused reports, `info..alert` may be more useful than `warning..alert`, because
authentication and login-related events are often logged below warning level.

## Tested models

I have made good experience with running this tool against a local Gemma4-26b model with a
64k context size on an RTX 4090 with 24GB VRAM. Smaller models might work, and smaller context
sizes might work, but this has to be tested for the specific workload and journal volume.
Larger, more capable models with context sizes >=64k should work even better.

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

You can also install the package directly with `pipx`:

```bash
pipx install ai-journal-analyzer
```

Or, for development:

```bash
git clone https://github.com/YOUR-USER/ai-journal-analyzer.git
cd ai-journal-analyzer
make dev
.venv/bin/ai-journal-analyzer --help
```

## Configuration

Print the default user config path:

```bash
ai-journal-analyzer --print-config-path
```

Install the example config into the default user config path:

```bash
make config
```

Use an explicit config file:

```bash
ai-journal-analyzer --config ./ai-journal-analyzer.conf
```

Use a config file via environment variable:

```bash
AI_JOURNAL_ANALYZER_CONFIG=/path/to/ai-journal-analyzer.conf ai-journal-analyzer
```

The config lookup order is:

1. `--config /path/to/config`
2. `AI_JOURNAL_ANALYZER_CONFIG=/path/to/config`
3. `/usr/local/etc/ai-journal-analyzer.conf`, if it exists
4. legacy `/usr/local/etc/ai_journal_analyzer.conf`, if it exists
5. user config path from `platformdirs`, usually `~/.config/ai-journal-analyzer/ai-journal-analyzer.conf`

System-wide defaults can be configured in:

```text
/usr/local/etc/ai-journal-analyzer.conf
```

Install an example config manually:

```bash
ai-journal-analyzer --install-config ai-journal-analyzer.conf.example
```

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

## Basic usage

Analyze warnings and errors from the last 24 hours:

```bash
ai-journal-analyzer --since "24 hours ago" --loglevel "warning..alert"
```

Analyze the current boot:

```bash
ai-journal-analyzer --boot
```

Focus on network-related problems:

```bash
ai-journal-analyzer \
  --since "24 hours ago" \
  --loglevel "warning..alert" \
  --focus-on "network problems"
```

Analyze one systemd unit:

```bash
ai-journal-analyzer --unit ssh.service --since "7 days ago"
```

Print the filtered journal without calling the AI endpoint:

```bash
ai-journal-analyzer --dry-run
```

Inspect the filtered journal before analysis:

```bash
ai-journal-analyzer --print-journal
```

With explicit config:

```bash
ai-journal-analyzer --config ./ai-journal-analyzer.conf --since "24 hours ago" --mode report
```

Suppress the privacy/cost warning after you have reviewed the implications:

```bash
ai-journal-analyzer --config ./ai-journal-analyzer.conf --since "24 hours ago" --mode report --no-warn
```

The warning shows the full configured endpoint. Local loopback endpoints such as `127.0.0.1`, `localhost`, and `::1` are explicitly marked as local.

Debug chunk handling:

```bash
ai-journal-analyzer --config ./ai-journal-analyzer.conf --debug-ai
```

## Journal filtering and scoping

Use simple keyword excludes when you want to remove known noisy lines before they are sent to the AI:

```bash
ai-journal-analyzer --exclude-pattern "harmless noisy message"
```

For regular expressions, use the explicit regex option:

```bash
ai-journal-analyzer --exclude-regex-pattern "^.*mpt3sas_cm0: log_info\(0x30030109\).*$"
```

Use `--gently-ignore` for semantic AI guidance. The journal lines are still sent to the model, but the model is told not to report matching topics unless they are severe:

```bash
ai-journal-analyzer --gently-ignore "GNOME desktop problems, printer warnings"
```

Use `--focus-on` to bias both chunk analysis and final reporting. Matching final-report items are marked with labels such as `[FOCUS MATCH]`, while urgent non-focus issues may be labeled `[CRITICAL NON-FOCUS FINDING]`:

```bash
ai-journal-analyzer --focus-on "all problems related to networking"
```

Use journalctl-native filters for common scopes:

```bash
# Kernel messages, equivalent to journalctl -k
ai-journal-analyzer --kernel

# Current boot, equivalent to journalctl -b
ai-journal-analyzer --boot

# Specific services/units, equivalent to journalctl -u docker.service -u ssh.service
ai-journal-analyzer --unit docker.service --unit ssh.service
```

The same options are available in the config file as `journal.kernel`, `journal.boot`, and `journal.units`. If `--kernel` and `--unit` are combined, the script uses journalctl OR matches so kernel messages and selected units are both included.

## Cron example for daily email reports

Edit root's crontab if the tool needs full access to the system journal:

```bash
sudo crontab -e
```

Run once every 24 hours at 06:00 and send an email report:

```cron
0 6 * * * /usr/local/bin/ai-journal-analyzer --config /usr/local/etc/ai-journal-analyzer.conf --since "24 hours ago" --mode report --mail admin@example.com --no-warn >>/var/log/ai-journal-analyzer.log 2>&1
```

Notes:

- `--no-warn` is recommended for cron after you have reviewed the privacy/cost warning.
- Depending on your system, access to the full journal may require root or membership in the `systemd-journal` group.
- Configure SMTP settings in `ai-journal-analyzer.conf` before enabling `--mail`.

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

By default, normal runs print only the final report. Use `--mode all`, `--mode errors`, or `--debug-ai` to inspect internal chunk results.

The default chunk size is 500 journal lines. This is the recommended default and usually works well for a 64k context-size thinking model. Use lower values such as 200 or 300 for smaller local models or noisy logs.

Example timestamps are enabled by default so that findings can be searched later in the journal.

## License

GPL v2
