# Voidly Accessibility Check — GitHub Action

Add a censorship-data lookup to a GitHub Actions workflow. The Action sends the domains and country codes you choose to the [Voidly Accessibility API](https://voidly.ai/api-docs), writes a step summary, and exposes the returned statuses as workflow outputs.

**Interpretation:** A `blocked` result reflects the API's available evidence. `unknown` means there is not enough evidence for that domain and country. This Action is an API lookup, not a fresh network test from the target country. Review the [methodology](https://voidly.ai/methodology) and underlying evidence before using a result as a release gate.

## Quick start

```yaml
name: Accessibility check
on:
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: voidly-ai/voidly-check-action@v1
        with:
          domains: 'example.org'
          countries: 'IR,CN'
          fail-on-blocked: false
```

The `v1` tag exists. Pin to a full commit SHA if your workflow requires an immutable Action revision.

## Inputs and outputs

| Input | Meaning |
| --- | --- |
| `domains` | Required comma-separated domains; the API batch limit is 50 per country. |
| `countries` | Comma-separated ISO country codes; defaults to `IR,RU,CN`. |
| `fail-on-blocked` | `true` exits with failure when the API explicitly returns at least one `blocked` result; defaults to `false`. |
| `report-format` | `markdown` or `json`; defaults to `markdown`. |
| `api-key` | Optional API key supplied through a GitHub secret. |
| `api-base-url` | Advanced API override. |

Outputs: `blocked-count`, `total-checks`, `blocked-domains` (JSON), and `report-url`. See [`action.yml`](action.yml) for their definitions and [`examples/`](examples/) for more workflows.

The current script displays API failures as `error` rows. A zero blocked count therefore does not establish reachability when results are `unknown` or `error`; inspect the full summary. Setting `fail-on-blocked` does not turn those statuses into failures.

Only submit domains you are comfortable sharing with the API. Voidly-original data and upstream measurements can have different license terms; see [Open Data](https://voidly.ai/data).

Code license: [MIT](LICENSE).
