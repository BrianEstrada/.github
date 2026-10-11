# Repo defaults

How my repos are set up on GitHub. To bring a repo in line, or to check one, run from this repo:

```bash
repo-defaults/apply.sh --check BrianEstrada/<repo>   # report what differs, exit 1 if anything does
repo-defaults/apply.sh BrianEstrada/<repo>           # apply the settings and the ruleset
```

It needs `gh` logged in as the repo's admin, and `jq`. It only compares the keys the files below set.

## What the script applies

- **[`settings.json`](settings.json):** squash merges only, titled after the PR and described by its body;
  branches deleted on merge; auto-merge and "update branch" on; issues on, wiki, projects and
  discussions off; secret scanning and push protection on. Also turns on Dependabot alerts.
- **[`workflow-permissions.json`](workflow-permissions.json):** `GITHUB_TOKEN` is read-only by default and
  can't approve PRs. Workflows ask for more in their own `permissions`.
- **[`ruleset-main.json`](ruleset-main.json):** the `main` ruleset, in the same JSON shape GitHub's ruleset
  import and export use.
  - Applies to the default branch: no deletion or force push, linear history, squash merges only.
  - Changes go through a PR with one approval from a code owner and every review thread resolved.
  - The `check` status (a GitHub Actions job named `check`) must pass.
  - Bypass: repo admins, through a PR only; BriansBot (App 5274319) always, so the release workflow can
    push its release commit and tag.

## What a repo needs by hand

The script reports these but doesn't change them, since they're files in the repo or secrets:

- `.github/CODEOWNERS` with `* @BrianEstrada`. The ruleset requires a code owner's approval.
- `.github/workflows/check.yml` with a job named `check` that runs the repo's checks on every PR.
- `.github/renovate.json` extending the [shared preset](../README.md#renovate-preset), and
  `.github/pull_request_template.md` copied from an existing repo.
- `.github/workflows/review.yml` to review PRs with diffcop (copy this repo's), with an
  `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` secret. It skips fork and Renovate PRs.
- To release an npm package: a `.github/workflows/release.yml` that calls
  [`bun-npm-release`](../.github/workflows/bun-npm-release.yml) (see the [README](../README.md)), with
  BriansBot installed on the repo, its Client ID as the `RELEASE_APP_CLIENT_ID` secret, and its private
  key as the `RELEASE_APP_PRIVATE_KEY` secret. On npmjs.com, a trusted publisher for the repo and
  `release.yml`.

## Changing a default

Edit the file here, then run `apply.sh --check` against each repo before applying, since a change here
applies to every repo the next time it's run.
