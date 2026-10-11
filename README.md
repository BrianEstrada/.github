# .github

Shared GitHub workflows and repo defaults for my repos.

- [`repo-defaults/`](repo-defaults/README.md): how every repo is set up (settings, the `main` ruleset,
  required files), with a script that checks or applies it.

## Renovate preset

[`default.json`](default.json) is the Renovate config every repo extends from its `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>BrianEstrada/.github"]
}
```

It's `config:recommended` with `chore` commit types and GitHub Actions pinned to digests, and it waits 3
days before proposing an npm release. PRs from branches in the repo, Renovate's included, run workflows
with the repo's secrets, so a hijacked version should be pulled before it gets there.

## bun-npm-release

Reusable release workflow for a Bun-built npm package. It picks the next version with git-cliff (or
takes the one requested), bumps `package.json`, runs `bun run changelog` and `bun run check`, pushes
`chore(release): vX.Y.Z` and its tag to main, publishes to npm with trusted publishing, and creates the
GitHub Release from `CHANGELOG.md`. It stops when every commit since the last `v*` tag is one git-cliff
skips (deps, chores).

The release commit goes straight to main, so it needs a GitHub App with Contents: read and write,
installed on the repo and allowed to bypass main's ruleset. Store its Client ID as the
`RELEASE_APP_CLIENT_ID` variable and its private key as the `RELEASE_APP_PRIVATE_KEY` secret.

```yaml
# .github/workflows/release.yml (npm's trusted publisher matches this file name)
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: Version to release, like 0.2.0. Leave empty to work it out from the commits.
        required: false
        type: string

permissions:
  contents: read
  id-token: write

concurrency:
  group: release
  cancel-in-progress: false

jobs:
  release:
    uses: BrianEstrada/.github/.github/workflows/bun-npm-release.yml@<sha> # main
    with:
      version: ${{ inputs.version }}
      app-client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}
    secrets:
      app-private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```
