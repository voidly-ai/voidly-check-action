# Voidly Accessibility Check — GitHub Action

[![Marketplace](https://img.shields.io/badge/GitHub%20Marketplace-voidly--check--action-blue?logo=github)](https://github.com/marketplace/actions/voidly-accessibility-check)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Powered by Voidly](https://img.shields.io/badge/data-Voidly%20%E2%80%94%2019.6M%20samples-0a0a0a)](https://voidly.ai)

**Verify your services are accessible from countries with internet censorship — straight from your CI.**

This Action calls the [Voidly Accessibility API](https://api.voidly.ai/v1/accessibility/check) to check whether your domains are reachable in countries like Iran, Russia, China, Belarus, Turkmenistan, and more. It posts a report to your GitHub Actions step summary, sets workflow outputs you can branch on, and (optionally) fails the build when blocking is detected.

Voidly is built on **19.6M+ live OONI samples**, **2.2B+ underlying measurements**, and a global probe network — so the answer is grounded in real network observations, not guesses.

---

## Why?

- **SaaS / dev-tool companies** — make sure your CDN, marketing site, and API endpoints aren't silently DNS-poisoned in markets you sell into.
- **News orgs and journalists** — verify your reporting platform reaches readers under censorship.
- **Open-source maintainers** — confirm contributors in restricted countries can still pull from your install URLs.
- **NGOs and human-rights tooling** — ship with confidence that the people who need your service can actually reach it.

If your CDN, registrar, or hosting provider gets caught in an upstream block, this Action surfaces it on every push.

---

## Quick start

```yaml
# .github/workflows/accessibility.yml
name: Accessibility

on:
  push:
  schedule:
    - cron: '0 12 * * *'  # daily at noon UTC

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Verify accessibility
        uses: voidly-ai/voidly-check-action@v1
        with:
          domains: 'mycompany.com,api.mycompany.com,docs.mycompany.com'
          countries: 'IR,RU,CN,UA'
          fail-on-blocked: false
```

That's it. The summary lands in the workflow run page.

---

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `domains` | yes | — | Comma-separated list of domains. Up to 50 per workflow run. |
| `countries` | no | `IR,RU,CN` | Comma-separated ISO 3166-1 alpha-2 country codes. |
| `fail-on-blocked` | no | `false` | If `true`, the step fails when **any** domain is blocked in **any** target country. |
| `report-format` | no | `markdown` | `markdown` (rendered table) or `json` (machine-readable). |
| `api-key` | no | — | Optional Voidly API key for higher rate limits. The endpoint is public; a key is only needed for heavy use. |
| `api-base-url` | no | `https://api.voidly.ai` | Override for self-hosting / testing. |

---

## Outputs

| Name | Description |
|---|---|
| `blocked-count` | Total number of `(domain, country)` pairs that returned `status=blocked`. |
| `total-checks` | Total number of `(domain, country)` pairs evaluated. |
| `blocked-domains` | JSON array: `[{"domain":"x","country":"IR","status":"blocked","methods":["tcp-reset"]}, ...]` |
| `report-url` | Link to the most-affected country page on voidly.ai (empty if nothing blocked). |

Use them in later steps:

```yaml
- name: Verify accessibility
  id: voidly
  uses: voidly-ai/voidly-check-action@v1
  with:
    domains: 'mycompany.com'
    countries: 'IR,RU'

- name: Notify on Slack if blocked
  if: steps.voidly.outputs.blocked-count != '0'
  run: |
    curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
      -d "{\"text\":\":rotating_light: ${{ steps.voidly.outputs.blocked-count }} domain(s) blocked. See ${{ steps.voidly.outputs.report-url }}\"}"
```

---

## Sample output

When blocking is detected, the workflow summary looks like this:

```
## Voidly Accessibility Report

Checked 2 domain(s) across 2 country/countries — 4 total checks.

4 blocked result(s) detected.

| Domain        | Country | Status      | Methods   |
|---------------|---------|-------------|-----------|
| facebook.com  | CN      | ✕ blocked   | tcp-reset |
| twitter.com   | CN      | ✕ blocked   | tcp-reset |
| facebook.com  | IR      | ✕ blocked   | tcp-reset |
| twitter.com   | IR      | ✕ blocked   | tcp-reset |

Most-affected country: CN full report

Powered by Voidly — 19.6M+ live censorship samples across 130 countries.
```

When everything is reachable:

```
## Voidly Accessibility Report

Checked 3 domain(s) across 4 country/countries — 12 total checks.

No blocking detected. All targets returned accessible or unknown.
```

`unknown` means Voidly doesn't have enough recent observations from that country for that exact domain — it's neither a pass nor a fail signal.

---

## Examples

See [`examples/`](examples/) for full workflows:

- [`basic-check.yml`](examples/basic-check.yml) — minimal use
- [`scheduled-monitor.yml`](examples/scheduled-monitor.yml) — daily cron with Slack alerting
- [`pr-comment.yml`](examples/pr-comment.yml) — auto-comment results on every PR

---

## How it works

1. The Action splits your CSV inputs into a domain list and a country list.
2. For each country, it `POST`s to `https://api.voidly.ai/v1/accessibility/batch` with the full domain list.
3. Results are aggregated, rendered to `$GITHUB_STEP_SUMMARY`, and exposed as outputs via `$GITHUB_OUTPUT`.
4. If `fail-on-blocked=true` and any pair is blocked, the step exits non-zero.

It's a composite Action — pure bash + curl + jq. No Docker, no Node, no transitive npm dependencies.

---

## Privacy

- **No PII is collected.** This Action sends only the domains and country codes you specify.
- **No telemetry.** Voidly's accessibility endpoint is a stateless lookup against publicly aggregated OONI / CensoredPlanet / IODA data plus our probe network.
- **Data licence.** Voidly publishes the underlying censorship data under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

---

## Versioning

We follow semver. Pin to a major (`@v1`) for automatic patch and minor updates, or to a full SHA for total reproducibility:

```yaml
uses: voidly-ai/voidly-check-action@v1            # latest v1.x.y
uses: voidly-ai/voidly-check-action@v1.0.0        # exact tag
uses: voidly-ai/voidly-check-action@<commit-sha>  # immutable
```

See [`CHANGELOG.md`](CHANGELOG.md) for release notes.

---

## Contributing

Issues and PRs welcome. The relevant files:

- `action.yml` — composite Action manifest
- `entrypoint.sh` — the bash that does the work
- `examples/` — kept in sync with the README

To test locally:

```bash
export GITHUB_OUTPUT=/tmp/out.txt
export GITHUB_STEP_SUMMARY=/tmp/sum.md
export INPUT_DOMAINS='voidly.ai'
export INPUT_COUNTRIES='IR'
export INPUT_FAIL_ON_BLOCKED=false
export INPUT_REPORT_FORMAT=markdown
bash entrypoint.sh
cat /tmp/sum.md
```

---

## License

MIT — see [LICENSE](LICENSE).

---

## Built by [Voidly](https://voidly.ai)

The censorship-research network. [Open data](https://voidly.ai/data) · [API docs](https://voidly.ai/api-docs) · [MCP server](https://www.npmjs.com/package/@voidly/mcp-server)
