# ServiceNow SDK and Fluent

Use this reference when the task mentions ServiceNow SDK, `now-sdk`, Fluent, `.now.ts`, `now.config.json`, source-based ServiceNow applications, or converting an application to source code.

## What It Is

`ServiceNow/sdk` publishes the official `now-sdk` agent skill and documents the `@servicenow/sdk` CLI. It is not an MCP server and does not provide a persistent agent connection. The CLI supports authentication, application initialization/conversion, download, build, install/deploy, dependencies, transform, packaging, embedded documentation through `explain`, and narrow live Table API queries.

Keep the official `now-sdk` skill separate rather than copying it into this skill. Its published description triggers on almost any ServiceNow task or live lookup, which overlaps this PDI skill and can add unnecessary `npx` discovery to routine work. Do not install it globally by default. Install or enable it independently for active SDK/Fluent projects so ServiceNow's CLI guidance can update without changing this PDI-specific PowerShell skill. This skill remains responsible for instance routing, risk controls, update-set rules, live validation, and rollback evidence.

## Decision Rule

Prefer SDK/Fluent when all or most of these are true:

- the workspace already contains `now.config.json` and `package.json`;
- the work is a new custom scoped application or an intentional conversion of one;
- metadata-as-code, Git review, branching, reproducible builds, or CI/CD are material benefits;
- JavaScript modules, typed Glide APIs, reusable npm packages, or build-time validation are needed;
- the target is a confirmed non-production instance supported by the SDK.

Prefer the bundled PowerShell/Table API/Xplore/update-set workflow when any of these dominate:

- the work is Global, an operational configuration change, an emergency hotfix, or customization of plugin/Store-owned metadata;
- the artifact is a portal page/widget instance, builder-managed UX, ordinary data, or metadata not already owned by an SDK project;
- the task is live diagnosis, runtime probing, update-set capture verification, or a narrow repair in an established update-set pipeline;
- converting the application would expand scope beyond the requested change;
- Fluent does not support the metadata type. Unsupported types can remain as XML, but that mixed representation must be intentional.

For a small Service Portal spacing change in an existing update-set-managed portal, the PowerShell/live-record workflow is normally faster. SDK becomes attractive when the widget belongs to a deliberately source-managed custom application and subsequent development will stay there.

## Orientation and Version Gates

Never guess CLI flags. In the application directory, inspect the local or pinned SDK first:

```powershell
npx @servicenow/sdk --version
npx @servicenow/sdk --help
npx @servicenow/sdk explain quickstart --list --format=raw
```

Before first use of a subcommand, run its help. Search and preview embedded documentation before loading a full topic:

```powershell
npx @servicenow/sdk <subcommand> --help
npx @servicenow/sdk explain --list --format=raw
npx @servicenow/sdk explain <topic> --list --peek --format=raw
npx @servicenow/sdk explain <topic> --peek --format=raw
npx @servicenow/sdk explain <topic> --format=raw
```

Useful searches include the exact metadata type plus `build`, `transform`, `deploy`, `auth`, `naming`, `structure`, `scoping`, and `file-layout`.

- `explain` requires SDK 4.6.0 or newer.
- `query` requires SDK 4.8.0 or newer.
- Current official requirements for the latest SDK include Node.js 20.18.0 or newer and npm 8.19.3 or newer.
- The SDK supports instance integration beginning with the Washington DC release and is documented for non-production instances.
- Check the project's pinned dependency and `npm view @servicenow/sdk dist-tags --json` before recommending an upgrade. Do not assume the newest GitHub release is already npm's stable `latest` tag.

## Live Queries

SDK `query` is useful for narrow, machine-readable discovery. Read help and the embedded query guides before the first query:

```powershell
npx @servicenow/sdk query --help
npx @servicenow/sdk explain query --format=raw
npx @servicenow/sdk explain encoded-query-guide --format=raw
npx @servicenow/sdk query <table> -q '<encoded-query>' -f '<fields>' --limit 20 -o json
```

Use explicit fields, a selective encoded query, a small limit, JSON output, and an explicit auth alias when more than one instance is configured. Confirm the returned instance and user before trusting results.

SDK `query` does not replace this skill's cached discovery, scope/update-set preference controls, Xplore server execution, customer-update capture checks, or post-write rollback evidence. Treat it as another narrow read path unless the task is already inside a controlled SDK application workflow.

## Source-of-Truth and Delivery Rules

1. Confirm the application, scope, repository, branch, SDK version, auth alias, target instance, and current local status.
2. Decide whether each artifact is represented by Fluent source or metadata XML. When both exist, ServiceNow documents that XML takes precedence during installation; remove ambiguity before editing.
3. Download/transform live changes before local editing when the instance may be ahead. Preview transforms first when converting existing metadata.
4. Use stable Fluent identifiers such as `Now.ID` and references such as `Now.ref` according to the current SDK documentation; do not invent reusable instance sys_ids.
5. Keep reusable scripts in JavaScript modules when the Fluent API supports modules. Use the documented fallback for APIs that accept only string scripts.
6. Build locally and review generated files and Git diff. In CI, consider frozen generated keys and conflict-as-error options after confirming current command help.
7. Install only to an explicitly confirmed non-production instance. Validate configuration, behavior, security, and regression cases in the real channel.
8. Commit the source and generated identity/dependency files required by the project convention. Do not commit credentials, local auth stores, secrets, build output that the repository excludes, or unrelated instance downloads.
9. Publish/deploy through the application's established Application Repository or pipeline. Do not also transport the same SDK-managed artifacts through update sets.

Conversion and installation are controlled writes. They require explicit task scope, a clean rollback path in Git/application versions, and awareness that some metadata cannot be transformed to Fluent. Never convert an existing application merely to complete a small unrelated change.

## Authentication and Safety

- Use an explicit auth alias for every risky command when multiple instances exist.
- Follow the CLI's supported authentication flow; prefer OAuth or the organization's approved method.
- Never echo, copy into source, or commit the SDK credential store, passwords, tokens, or auth headers.
- SDK documentation requires admin for common initialization/conversion workflows. Treat that privilege as high impact even on a PDI.
- Do not point SDK install/deploy at production. The official SDK workflow is documented for non-production instances; promote through the approved application delivery mechanism.
- Inspect dependency changes and lockfiles. Third-party npm packages become part of the application's build and security/supply-chain surface.

## Official Sources

- Agent skill repository and Codex install instructions: https://github.com/ServiceNow/sdk
- Official `now-sdk` skill: https://github.com/ServiceNow/sdk/blob/master/skills/now-sdk/SKILL.md
- Fluent API documentation: https://servicenow.github.io/sdk/
- ServiceNow SDK overview: https://www.servicenow.com/docs/r/application-development/servicenow-sdk/servicenow-sdk.html
- SDK CLI commands: https://www.servicenow.com/docs/r/application-development/servicenow-sdk/servicenow-sdk-cli-commands.html
- Building applications in source code: https://www.servicenow.com/docs/r/application-development/building-applications-source-code.html
- Converting an application: https://www.servicenow.com/docs/r/application-development/servicenow-sdk/convert-application-now-sdk.html
- Source-control guidance: https://www.servicenow.com/docs/r/application-development/best-practices-use-source-control.html
- Official examples: https://github.com/ServiceNow/sdk-examples
