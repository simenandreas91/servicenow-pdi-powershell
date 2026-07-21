# Australia AI Platform Notes

Use this only for release-sensitive AI development features in the Australia family: Build Agent, ServiceNow Studio AI-assisted app generation, MCP Server Console, MCP Client, and related metadata support. For runtime Now Assist configuration, also load `references/now-assist.md`.

Research baseline: official ServiceNow Australia release notes and Australia AI documentation checked 2026-07-21.

## Current Signals

- Build Agent is positioned as a conversational development surface for creating, editing, and deploying full-stack applications and metadata. Australia highlights include use inside ServiceNow Studio, broader MCP support, global-scope support, additional model support, and expanded metadata support. Source: https://www.servicenow.com/docs/r/release-notes/build-agent-rn.html
- Australia Patch 2 release notes say Build Agent can connect to external MCP servers, create agentic workflows/agents/skills, run ATF tests through Test Agent, perform Playwright-based UI validation in Cloud Runner, use semantic artifact search, and support more metadata such as flows, Service Catalog configuration, inbound email actions, dictionary overrides, choice lists, condition builder queries, and enhanced Service Portal capabilities. Source: https://www.servicenow.com/docs/r/release-notes/build-agent-rn.html
- ServiceNow Studio is active by default on the ServiceNow AI Platform in Australia. Build Agent is the default AI-assisted app generation path, and Studio can add UI Builder files, catalog items, flows, notifications, and other app files. Source: https://www.servicenow.com/docs/r/release-notes/servicenow-studio-rn.html
- MCP Server Console is new in Australia and provides governed ServiceNow functionality to external MCP clients through MCP servers. Notes call out a Quickstart Server for incident/case lookup and summarization, OAuth 2.0 client access, tools from Now Assist skills, and version 1.3 support for tools from Knowledge Graph, subflows, actions, and REST APIs. Source: https://www.servicenow.com/docs/r/release-notes/mcp-server-console-rn.html
- MCP Server Console plugin is `sn_mcp_server`. Activation depends on Now Assist application activation and related Generative AI Controller / Now Assist plugin setup. Do not assume it exists in a PDI or customer DEV without checking installed plugins and entitlements. Source: https://www.servicenow.com/docs/r/release-notes/mcp-server-console-rn.html
- Australia Patch 2 adds property-gated UI validation for AI-initiated record updates. Verify the master `glide.ai_record_activity.validation.feature.enabled` property plus the relevant Now Assist panel, skill/Virtual Agent, or agentic-AI context property; do not assume client-side form validation protects an agentic write. Source: https://www.servicenow.com/docs/r/release-notes/now-assist-ai-agents-rn.html
- Australia Patch 3 adds a runaway-trigger kill switch, deny-by-default wildcard ACL behavior for agentic asset types on freshly reset instances, Knowledge Graph conversation-history support, and additional built-in-asset editing/migration changes. Store app and patch level determine the visible behavior. Source: https://www.servicenow.com/docs/r/release-notes/now-assist-ai-agents-rn.html
- The Patch 3 kill switch ships in `warn_only` mode. Default detection is five fires for the same record/objective in 24 hours, 25 distinct breaching records, and three consecutive windows; `enforce` disables the trigger on the third breach day. Treat this as a backstop for selective, idempotent triggers. Source: https://www.servicenow.com/docs/r/intelligent-experiences/aia-kill-switch.html
- Fresh/reset Patch 3 instances use deny-by-default wildcard behavior for `gen_ai_agent`, `gen_ai_workflow`, `gen_ai_skill`, `Flow`, and `flow_action`. Give every custom workflow, agent, skill, Flow/action, and downstream tool an explicit least-privilege ACL and validate the full execution chain. Source: https://www.servicenow.com/docs/r/intelligent-experiences/aia-acl-configuration.html

## Skill Routing Guidance

1. For Build Agent or Studio questions, inspect the actual instance release/build, installed apps/plugins, and visible Studio options before giving implementation steps.
2. For MCP Server Console work, verify `sn_mcp_server`, OAuth/client setup, AI Control Tower governance expectations, and the specific tool category before creating tools.
3. For MCP Client work inside ServiceNow, treat external MCP servers as integrations: confirm auth, data exposure, tool scope, logging, and governance before connecting.
4. Prefer read-only inventory first. Table API metadata reads can be blocked by API-level ACLs; use constrained Xplore fallback when the skill needs plugin/app inventory and Xplore is available.
5. Do not replace normal platform configuration with AI/agentic workflows when a deterministic Flow, ACL, catalog item, import, notification, or Business Rule is simpler and easier to test.
