# .github

Shared GitHub Actions for my repos.

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
