# swift-microservices skills

Agent skills for building Swift systems the [swift-microservices](https://github.com/swift-microservices) way — a modular monolith or microservices, over HTTP, gRPC, or both — packaged for Claude Code and Codex. Each skill covers one activity, carries its own references, and is tested with evals.

| Skill | Use it when |
| --- | --- |
| `designing-swift-systems` | choosing the shape (a modular monolith or microservices) and the transport (HTTP, gRPC, or both), cutting modules, communication, events and projections, consistency, and when a module becomes a service |
| `building-swift-services` | creating or changing a module or a service: Core, Postgres with row-level security, the HTTP or gRPC transport, the executable, a gateway in front of services, and the tests |
| `orchestrating-temporal-workflows` | workflows, Activities, signals, queries, and workers |
| `delivering-swift-services` | images, Compose, secrets, certificates, CI, per-commit publishing, migrations in the pipeline |
| `reviewing-swift-services` | auditing an existing service against the rules, read-only, on request |

## Install in Claude Code

Claude Code, from the marketplace in this repository:

```
/plugin marketplace add swift-microservices/skills
/plugin install swift-microservices@swift-microservices
```

Skills are then `/swift-microservices:building-swift-services` and so on, and Claude invokes them on its own when a task matches their descriptions.

## Install in Codex

Add this repository as a local plugin source:

```bash
codex plugin marketplace add https://github.com/swift-microservices/skills
codex plugin add swift-microservices@swift-microservices
```

For local evaluation, use the skills from this checkout in an isolated Codex workspace; see the evaluation guidance below.

Start a new Codex thread after installing or updating the plugin so it can load the skills.

## Layout

```
.claude-plugin/plugin.json        Claude Code plugin manifest
.claude-plugin/marketplace.json   Claude Code marketplace manifest
.codex-plugin/plugin.json         Codex plugin manifest
skills/<skill>/SKILL.md           instructions, under 500 lines, loaded when the skill triggers
skills/<skill>/references/*.md    detail, one level deep, loaded as needed
evals/<skill>-<case>/             shared eval prompts, fixtures, and behavioral rubrics
evals/results/                   ignored local eval transcripts, artifacts, and reports
.github/scripts/validate.sh       the structural and manifest checks CI runs
.github/scripts/create-release.sh label-based releases with synchronized plugin versions
```

## Development

```sh
bash .github/scripts/validate.sh   # frontmatter, line budgets, links, plugin versions
claude --plugin-dir .              # try the skills in a session
claude plugin validate .           # Claude Code's own structural check
claude plugin eval .               # run every eval case with and without the plugin
```

### Evals with Codex

Run a case's `prompt.md` in an isolated Codex workspace with the current skills and its `scaffold.sh` fixture, when present. Load required supporting skills such as `swift-concurrency`. Review the response, tool transcript, and generated artifacts against `graders/*.md`; a successful session is not a behavioral pass. Verify that read-only reviews leave fixture files unchanged. Keep transcripts, artifacts, and reports under the ignored `evals/results/` directory.

For the Swift settings build case, run the independent checks with a compatible Swift 6.3+ toolchain:

```sh
python3 evals/building-swift-services-swift-settings/checks/verify.py \
  evals/results/<run>/workspace
```

Claude-specific `tool_used`/`Skill` graders do not apply to Codex; inspect its skill-file reads instead. Explicit-skill runs do not establish automatic skill selection or with/without-plugin ablation. Claude's eval runner remains optional; no Claude subscription is needed for Codex evaluation.

## Contributing

Keep a change to one skill. Update its evals with it. Label the pull request with its semantic version impact.

## Releases

Run **Auto Release** from GitHub Actions on `main`, or use:

```sh
gh workflow run auto-release.yml --ref main
```

Like the other organization repositories, the workflow uses merged PR labels since the latest release: `🆕 semver/minor` takes precedence over `🔨 semver/patch`; `semver/none` does not trigger a release. PRs must carry a SemVer label. A `⚠️ semver/major` change requires a manual release.

The Bash release helper lives in `.github/scripts`, following the [Swift Temporal SDK release script](https://github.com/apple/swift-temporal-sdk/blob/main/.github/scripts/create-release.sh), with additional handling for the plugin manifests.

Before publishing, CI validates the skills and plugin manifests. It updates both plugin manifests, commits the version, pushes that commit and its tag together, and publishes a GitHub release with categorized notes. These checks run in the release job because commits pushed with `GITHUB_TOKEN` do not trigger the regular validation workflow.

If publication fails after the tag was pushed, rerun on that same commit before merging more changes. The workflow reuses the tag only when it points to that commit and both manifests match; it never moves an existing tag. Branch protection must permit the workflow token to push the version commit to `main`.

To preview the next version from a clean, up-to-date `main` checkout with tags fetched and `gh` authenticated:

```sh
GITHUB_REPOSITORY=swift-microservices/skills GITHUB_REF=refs/heads/main bash .github/scripts/create-release.sh --dry-run
```

MIT.
