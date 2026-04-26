# Changelog

All notable changes to this Action will be documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-04-25

Initial public release.

### Added
- Composite GitHub Action (`action.yml`) that wraps the
  Voidly accessibility batch API.
- `entrypoint.sh` — pure bash + curl + jq, no Docker, no Node.
- Inputs: `domains`, `countries`, `fail-on-blocked`, `report-format`,
  `api-key`, `api-base-url`.
- Outputs: `blocked-count`, `total-checks`, `blocked-domains` (JSON),
  `report-url`.
- Markdown report rendered to `$GITHUB_STEP_SUMMARY` with a domain x country
  table, top-affected-country deep-link, and a CC BY 4.0 attribution.
- Optional JSON report format for downstream tooling.
- Three example workflows: basic check, scheduled monitor with Slack alerts,
  and PR-comment integration.
- Self-test workflow under `.github/workflows/test.yml` covering the happy
  path, JSON format, bad-input rejection, and shellcheck.
- MIT licence and Marketplace branding (globe icon, blue).

### Notes
- Action requires `ubuntu-latest`. Other runners are not yet supported.
- The accessibility endpoint is public; an API key only matters under heavy
  use.
