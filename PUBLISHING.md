# Publishing `voidly-check-action` to the GitHub Marketplace

This file is for the maintainer. It walks through everything that has to
happen *outside* of `git push` so the Action shows up at
`github.com/marketplace/actions/voidly-accessibility-check`.

## 0. Prerequisites

- A GitHub org named **`voidly-ai`** (or whichever org you want to host
  under — adjust the `uses:` strings throughout if you change it).
- `gh` CLI authenticated (`gh auth status`).
- This directory committed to a clean local repo.

## 1. Initialise and push the repo

From this directory:

```bash
cd voidly-check-action

git init -b main
git add .
git commit -m "chore: initial release v1.0.0"

# Create the empty repo on GitHub
gh repo create voidly-ai/voidly-check-action \
  --public \
  --description "GitHub Action to verify your services are accessible from censored countries. Powered by Voidly." \
  --homepage "https://voidly.ai" \
  --source . \
  --remote origin \
  --push
```

If the org doesn't exist yet, create it first under your account settings,
then re-run the `gh repo create` line.

## 2. Tag a release

The Marketplace requires a tag and a published Release.

```bash
git tag -a v1.0.0 -m "v1.0.0 — initial release"
git push origin v1.0.0

# Floating major tag — users pin to this with @v1
git tag -fa v1 -m "v1 — track latest v1.x.y"
git push origin v1 --force
```

Then publish a GitHub Release from the tag. Either via UI or:

```bash
gh release create v1.0.0 \
  --title "v1.0.0 — initial release" \
  --notes-file CHANGELOG.md
```

## 3. Publish to the Marketplace (UI step — required)

GitHub gates Marketplace publishing behind a click-through. There is no
API for this step.

1. Open the release page:
   `https://github.com/voidly-ai/voidly-check-action/releases/tag/v1.0.0`
2. Click **Edit release**.
3. Tick **Publish this Action to the GitHub Marketplace**.
4. Accept the Marketplace Developer Agreement (one-time per org).
5. Choose the primary category: **Continuous integration**. Optional second
   category: **Code quality**.
6. Confirm the icon / colour pulled from `action.yml` (globe / blue).
7. Click **Publish release**.

Your listing will appear at
`https://github.com/marketplace/actions/voidly-accessibility-check` within a
few minutes.

## 4. Verify it works for an external consumer

In an unrelated repo:

```yaml
- uses: voidly-ai/voidly-check-action@v1
  with:
    domains: 'example.com'
    countries: 'IR'
```

Push, watch the workflow run, confirm the step summary renders correctly.

## 5. Future releases

For each release:

1. Update `CHANGELOG.md` and bump version references in `README.md` /
   `User-Agent` in `entrypoint.sh` if you want.
2. Commit, tag (`vX.Y.Z`), push the tag.
3. Move the floating major tag (`v1`, `v2`, ...) forward:
   ```bash
   git tag -fa v1 -m "v1 — track latest v1.x.y"
   git push origin v1 --force
   ```
4. Publish the GitHub Release from that tag — the Marketplace listing
   updates automatically.

## Troubleshooting

- **"This Action is missing required metadata"** — `action.yml` must have
  `name`, `description`, and `branding.icon` (one of GitHub's allowed
  Octicons). We use `globe`, which is on the allow-list.
- **`action.yml` not at repo root** — Marketplace requires it at the top
  level. Don't move it.
- **"Name conflicts with an existing Marketplace listing"** — change the
  `name:` in `action.yml`. The slug derives from the repo name; the listing
  title comes from `name:`.
