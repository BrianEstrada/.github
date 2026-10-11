# .github

Shared GitHub Actions and workflows for my repos.

## git-cliff-version

Picks the version for a release workflow: the next one from the commits (`git-cliff --bumped-version`),
or the one requested. Fails when every commit since the last `v*` tag is skipped by git-cliff, or when the
tag already exists. Needs a full-history checkout and git-cliff runnable with `bunx`.

```yaml
- id: version
  uses: BrianEstrada/.github/git-cliff-version@<sha> # main
  with:
    version: ${{ inputs.version }}

- run: echo "Releasing ${{ steps.version.outputs.version }}"
```

## bun-npm-release

Reusable release workflow for a Bun-built npm package. It picks the version with `git-cliff-version`,
bumps `package.json`, runs `bun run changelog` and `bun run check`, pushes `chore(release): vX.Y.Z` and
its tag to main, publishes to npm with trusted publishing, and creates the GitHub Release from
`CHANGELOG.md`.

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
