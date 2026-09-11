# swift-microservices skills

Agent skills for building Swift services the [swift-microservices](https://github.com/swift-microservices) way, packaged as one Claude Code plugin. Each skill covers one activity, carries its own references, and is tested with evals.

| Skill | Use it when |
| --- | --- |
| `designing-swift-systems` | drawing service boundaries, choosing communication, consistency, or extracting a bounded context from a monolith |
| `building-swift-services` | creating or changing a service package: Core, Postgres, GRPC, the executable, and its tests |
| `building-swift-gateways` | putting an HTTP surface on Hummingbird or Vapor in front of services |
| `orchestrating-temporal-workflows` | workflows, Activities, signals, queries, and workers |
| `delivering-swift-services` | images, Compose, secrets, certificates, CI, per-commit publishing, migrations in the pipeline |
| `reviewing-swift-services` | auditing an existing service against the rules, read-only, on request |

## Install

Claude Code, from the marketplace in this repository:

```
/plugin marketplace add swift-microservices/skills
/plugin install swift-microservices@swift-microservices
```

Skills are then `/swift-microservices:building-swift-services` and so on, and Claude invokes them on its own when a task matches their descriptions.

Codex, one skill at a time:

```bash
git clone https://github.com/swift-microservices/skills.git ~/.swift-microservices-skills
ln -s ~/.swift-microservices-skills/skills/building-swift-services ~/.codex/skills/building-swift-services
```

## Layout

```
.claude-plugin/plugin.json        the plugin
.claude-plugin/marketplace.json   the marketplace that serves it
skills/<skill>/SKILL.md           instructions, under 500 lines, loaded when the skill triggers
skills/<skill>/references/*.md    detail, one level deep, loaded as needed
evals/<skill>-<case>/             claude plugin eval cases: a prompt and its graders
scripts/validate.py               the structural checks CI runs
```

## Development

```sh
python3 scripts/validate.py        # frontmatter, line budgets, links, retired names
claude --plugin-dir .              # try the skills in a session
claude plugin validate .           # Claude Code's own structural check
claude plugin eval .               # run every eval case with and without the plugin
```

Evals call the model on your account. Run one case while iterating: `claude plugin eval . --case building-swift-services-tenant-service --runs 1 --ablation none`.

## Contributing

Keep a change to one skill. Update its evals with it. Label the pull request with its semantic version impact.

MIT.
