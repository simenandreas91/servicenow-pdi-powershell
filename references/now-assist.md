# Now Assist, AI Search, And AI Agents

Use this when work touches Now Assist, Now Assist for HRSD, AI Search Genius Results, Now Assist Skill Kit, AI agents, AI Agent Studio, agentic workflows, MCP tools, AI Control Tower, model providers, prompt/privacy controls, or HRSD generative AI skills.

Research baseline: ServiceNow Australia documentation reviewed 2026-07-21 from public `ServiceNow/ServiceNowDocs` Australia commit `71f4936517ebd1fbaf76c5515c40b8d12bc6dd5c` (2026-07-15), current ServiceNow docs pages through 2026-07-17, Australia Patch 3 release notes, and the ServiceNow Assist Overview effective 2026-07-10. The repository is the preferred LLM research source for current AI Platform docs; search `markdown/intelligent-experiences`, `markdown/platform-administration/ai-search`, and the target product publication before broad web research. AI features change quickly; before implementing in a client instance, verify entitlements, installed Store app versions, patch level, data-center/regional restrictions, contract terms, and the actual options shown in Now Assist Admin, AI Agent Studio, or AI Control Tower.

## Mental Model

- Now Assist Admin / Now Assist Center is the primary admin surface for installing Now Assist plugins, reviewing account/license details, configuring model providers, activating skills, and managing privacy/safety settings.
- Product Now Assist apps, such as Now Assist for HRSD, provide packaged skills, agents, and agentic workflows for a workflow/product area.
- Now Assist Skill Kit is for custom skills/prompts. Use it when the packaged skill does not meet the business requirement.
- Generative AI Controller / AI Control Tower govern model-provider availability, model versions, and policy controls. Skill-level choices depend on what the organization and region allow.
- Now Assist in AI Search adds LLM-generated or LLM-selected answer cards to search experiences through Genius Result configurations.
- AI Search remains the retrieval layer. Keep knowledge, catalog items, search sources, search profiles, and result improvement rules healthy before blaming Now Assist output.
- AI Agent Studio is the build/test surface for AI agents and agentic workflows. Treat a workflow as the orchestrated business outcome, an AI agent as a specialized reasoning role, and tools as the bounded actions or retrieval capabilities the agent can select.
- AI Control Tower is the governance/inventory surface when work expands to AI assets, approvals, risk/compliance, model providers, AI Gateway, evaluations, or MCP connections across the organization.
- “Copilot” is best treated as an interaction pattern: AI assists a human inside a panel, workspace, or product experience. It is not a substitute for identifying the actual deployable asset—packaged/custom skill, AI agent, agentic workflow, assistant, trigger, tool, or channel.

## Fast Decision Path

1. Inspect packaged Now Assist skills, product AI agents, search features, and existing workflow metadata before designing custom AI.
2. Use AI Search/Genius Results when the job is permissioned retrieval and answer presentation from indexed content.
3. Use a packaged Now Assist skill when ServiceNow already owns the product workflow and its prompt/output shape is acceptable.
4. Use Skill Kit for a custom generative skill with a prompt, retriever, tool, deployment surface, or Flow/UI invocation that does not need autonomous multi-step planning.
5. Use AI Agent Studio for agentic workflows that need orchestrated planning across specialized agents and tools. Do not use an AI agent to hide a deterministic Flow, approval, ACL, import, or integration that normal platform configuration handles better.
6. Route model-provider, data handling, readiness, Guardian, governance, AI asset inventory, AI Gateway, or third-party/MCP questions through the admin/governance surfaces before promising a build path.

## Roles To Check

- Now Assist Center/Admin: `sn_na_center.nac_admin`, `sn_nowassist_admin.nsa_admin`, and sometimes `admin`, depending on the page/product.
- HRSD packaged skills: `sn_hr_core.admin` for HRSD setup; end users/agents need the HR roles configured in the skill access/display setup.
- Journey generation for managers: `sn_jny.admin` and `sn_nowassist_admin.nsa_admin`.
- Now Assist Skill Kit authoring: `sn_skill_builder.admin`.
- Skill Kit custom model administration: `sn_skill_builder.sb_model_admin`.
- AI Agent Studio execution tests: `sn_aia_admin` plus access required by the tested AI agent and every downstream component ACL.
- AI Search / Genius Results: `ais_admin` for search profile work; `esc_admin` can use the Employee Center setup page for portal/mobile Now Assist Genius Results.
- Data privacy policies: `sn_generative_ai.data_steward`.

## Installation And Environment Checklist

1. Confirm license/product tier and regional availability. Some products, model providers, and skills are unavailable or constrained in certain regions, in-country SKUs, regulated markets, or restricted data centers.
2. Use Now Assist Center or Now Assist Admin to install required plugins. The center identifies required plugins from entitlements.
3. For HRSD, install/activate Now Assist for HRSD: `sn_hr_gen_ai`. Dependencies called out by docs include Human Resources Scoped App: Core (`com.sn_hr_core`), Now Assist Platform (`com.sn.now.platform`), and NA-TD/NA-TA dependent apps for NA-HR (`sn_egd_core`, `sn_int_schedule`).
4. For AI Search Genius Results, install/activate Now Assist in AI Search: `sn_ais_assist`. This may be installed automatically with some Now Assist feature plugins, but verify it directly.
5. If using Skill Kit/custom skills, update the Now Assist product plugins and Generative AI Controller together so custom skills remain compatible.
6. On domain-separated instances, install/update from the global domain and verify the installer user is in the global domain. Skills are generally global-domain records, but runtime data access should stay domain-aware.

## Now Assist Admin Setup Flow

1. Navigate to **Now Assist Center** or **Now Assist Admin**.
2. Install the required Now Assist plugins.
3. Review **Account** for license/entitlement details.
4. Review **Model providers**, **Model versions**, and **Manage integrations**. Provider options can be set at instance, skill group, and skill levels depending on AI Control Tower policy.
5. Configure safety/privacy controls:
   - Prompt injection attack protection.
   - Offensiveness detection/logging/blocking.
   - Sensitive topic filters, especially for Virtual Agent/HR.
   - Privacy policies / data de-identification.
   - Data sharing and data overflow processing.
   - Multilingual service if non-English user text must be supported.
6. Activate the Now Assist panel if skills should be available through conversational panel experiences or follow-up questions from search result cards.
7. Activate each packaged skill from **Now Assist Admin > Skills**. For each skill, review guided setup sections:
   - Trigger.
   - Input.
   - Availability.
   - Access.
   - Display.
8. Test with representative records, user roles, HR criteria/security, and UI surfaces before enabling broadly.

## Now Assist For HRSD

Core app/plugin: `sn_hr_gen_ai`.

Packaged skills documented for HRSD include:
- Chat reply recommendation.
- Chat summarization.
- Sidebar discussion summarization.
- Case summarization.
- Resolution notes generation.
- Knowledge article generation.
- Email recommendation.
- Sensitivity detection.
- Journey generation for managers.
- Journey summarization for managers.
- Employee information summarization.
- Manager insights.

Supported UI notes from docs:
- Agent Workspace for HR Case Management: case summarization, chat summarization, resolution notes generation, knowledge article generation, sensitivity detection, email reply recommendation.
- Core UI: case summarization, knowledge article generation, sensitivity detection.

Model-provider note:
- The HRSD configure page states Now LLM Service is currently the only provider for HRSD skills.
- The HRSD supporting-info page also lists Now LLM Service, Azure OpenAI, AWS Anthropic, and Google Gemini as supported models.
- Treat this as release/region/version-sensitive. In Vår Energi, inspect Now Assist Admin and AI Control Tower before committing to a model-provider design.

Common HRSD skill inputs/triggers:
- Chat summarization triggers can include VA-to-live-agent handoff, `/summarize` quick action, short description update, chat wrap-up, bulleted summary, and task creation.
- Case summarization reads HR Case (`sn_hr_core_case`) fields such as description, priority, short description, state, additional comments, and work notes. It is not available for Cancelled or Suspended cases.
- Resolution notes generation reads HR Case (`sn_hr_core_case`) short description, description, state, additional comments, and work notes.
- Case sentiment analysis reads Case (`case`) fields such as short description, description, priority, state, creation date, and activities, and outputs sentiment value/trend/reasoning.
- Knowledge article generation reads HR Case (`sn_hr_core_case`) inputs such as short description and description.

Journey generation for managers:
- Requires `sn_jny.admin` and `sn_nowassist_admin.nsa_admin`.
- Navigate to **Now Assist Admin > Skills > Employee > HRSD**.
- Activate **Journey Generation for Managers**.
- Guided setup starts with trigger selection; use toggles to define which actions trigger journey generation.
- Display can be in-product, Now Assist panel, or both. If panel is unavailable, activate the Now Assist panel first.

Implementation caution for HRSD:
- Employee relations, sensitive cases, and HR profile data are high-risk. Configure availability/access narrowly and validate with real HR roles, HR criteria, COE security, domain separation, and data privacy policies.
- Never assume a generated summary is a system of record. Treat generated text as assistive output and preserve normal HR case audit/work notes practices.

## Now Assist Skill Kit

Use Skill Kit for custom generative AI skills when OOTB Now Assist skills are insufficient.

Authoring flow:
1. Confirm Now Assist plugins and Generative AI Controller are current.
2. Assign `sn_skill_builder.admin` to the AI developer.
3. Navigate to **Now Assist Skill Kit > Home**.
4. Create a skill or clone a ServiceNow skill.
5. Configure prompt(s), model, temperature, request/response token limits, and tools/retrievers/web search as needed.
6. Configure deployment settings:
   - Workflow, Product, Feature.
   - Deployment locations: Now Assist panel, UI Action, Flow action, Now Assist context menu, Virtual assistants, UI Builder.
7. Configure security controls:
   - ACL: any authenticated user or selected roles.
   - Role restrictions for execution.
8. Test prompt output, evaluate against realistic records, finalize, publish.
9. Activate the published skill in Now Assist Admin.

Notes:
- Deployment settings for cloned ServiceNow skills are locked; create a skill from scratch when custom deployment metadata is required.
- Selecting a deployment location in Skill Kit only makes it available for admin activation. It does not automatically activate the skill.
- UI Action deployment creates an inactive UI Action by default.
- Flow deployment exposes the skill through the **Execute Skill** action in Workflow Studio.

## Now Assist Asset Model

| Asset | What it is | Best fit | Avoid when |
| --- | --- | --- | --- |
| Now Assist panel / assistant / “copilot” experience | A user-facing conversational or contextual surface | Human-led questions, follow-ups, review, and invoking skills or agents | The requirement is only a backend automation |
| Now Assist skill | One bounded generative capability with a prompt, inputs, model, retriever/tool, and deployment locations | Summarize, draft, classify, extract, recommend, or transform | The task needs autonomous planning across several actions |
| AI agent | A specialized reasoning worker: description, role, List of steps, tools, security, triggers, and channels | Select and sequence tools to complete one discrete operational objective | A deterministic Flow can execute the same path reliably |
| Agentic workflow | A business objective and base plan that assigns one or more AI agents | Adaptive multi-step work across distinct specialists or domains | One agent with a small tool set is sufficient |
| AI Agent Orchestrator | ServiceNow runtime planner/coordinator using the workflow plan and agent proficiencies | Select workers, sequence/route work, collect missing context, and coordinate execution | Do not create a custom “orchestrator agent” merely to delegate |
| Tool | A bounded retrieval or action capability exposed to an AI agent | Read data, search, update, create, run automation, or call an external capability | It combines unrelated modes, hides authorization, or returns unbounded output |
| Trigger | Optional automatic invocation definition with table/condition/schedule/email context and output channel | Proactive, event-driven, or scheduled work | Chat-only invocation is sufficient |

The Orchestrator is part of the platform runtime. In a multi-agent design, the custom agents are workers with distinct, non-overlapping specialties. The agentic workflow supplies the base plan and available worker set; the Orchestrator chooses the plan and routes work.

## Agentic Or Deterministic Decision Gate

Use the least-agentic viable pattern:

1. Use a normal Flow, subflow, Business Rule, approval, decision table, or integration when inputs and path are known.
2. Add a packaged Now Assist skill when the need is a supported, bounded generation task.
3. Build a custom Skill Kit skill when one prompt/retrieval/generation capability is enough.
4. Build one AI agent when the job needs tool choice or adaptive sequencing but has one clear specialty.
5. Build an agentic workflow only when the outcome genuinely benefits from multiple specialized agents, variable planning, or coordination across domains.

An agentic wrapper does not replace records, ACLs, Flows, integrations, validation, audit, retry, or deployment engineering. Keep deterministic side effects inside deterministic components; let the LLM decide *which approved capability to use*, not reimplement the capability.

## End-To-End AI Agent Studio Build Runbook

### 1. Establish readiness and scope

Before opening Guided Setup, record:

- instance family, patch, Now Assist AI Agents Store app version, Now Assist product apps, Off Glide Conversation Server/Premium Chat status, entitlements, and available model providers
- measurable business outcome and baseline; for example, “correctly categorize eligible incidents and reduce manual triage time without changing priority or state”
- supported/unsupported inputs, source tables/content, allowed actions, maximum affected records, and authoritative system of record
- invoking persona, runtime identity, required roles, domain/COE/data restrictions, and denied persona
- chat, UI action, Virtual Agent, Now Assist panel, Workspace/Core UI background, scheduled, record/event, email, external A2A, or MCP channel
- interactive versus non-interactive execution; missing-information, no-result, access-denied, validation-failed, and transient-error behavior
- human approval points, rollback/deactivation path, evaluation dataset, acceptance thresholds, and assist budget

Inspect ready-made AI agents and agentic workflows first. Packaged assets may need activation and are often read-only; duplicate when customization is required unless the installed Store app version explicitly supports the intended modification.

### 2. Create a Chat AI agent

Navigate to **AI Agent Studio > Create and manage > AI agents > Add > Chat**. `sn_aia.admin` is required.

Define:

- **Name:** verb + business object + narrow outcome, such as `Categorize eligible ITSM incident`.
- **Description:** purpose, accepted input, returned output, record context, and hard scope boundary. This helps the Orchestrator decide when the agent is relevant.
- **AI agent role:** one or two sentences describing the specialist identity, business responsibility, and non-responsibilities. Keep roles distinct across agents.
- **List of steps:** the operational algorithm the worker follows. Version this field deliberately.
- **Unsupported model providers:** block providers that fail the use case or policy. If the instance default changes to an unsupported provider, the agent becomes unavailable.
- **Third-party access:** keep off unless the agent is intentionally exposed as a secondary agent and the security/data contract is approved.
- **Long-term memory and learning:** default off. Enable only for a named use case, approved categories, retention/privacy review, and regression testing; cross-conversation memory expands the data boundary.

### 3. Write production-grade instructions

Use this shape:

```text
Objective
- Complete <one measurable outcome> for <eligible records/users>.

Inputs and authority
- Required: <record identifier and context>.
- Treat <record/table/tool output> as authoritative.
- Never infer identifiers, permissions, approvals, or completion.

Procedure
1. Use <Lookup tool> once to retrieve <minimum fields>.
2. If not found or access is denied, report the exact condition and stop.
3. Validate <eligibility and required fields>.
4. Use <Search/analysis tool> only when <condition>.
5. If evidence is insufficient or conflicting, say "I don't have enough evidence to determine <value>" and stop or request <specific input>.
6. Present <proposed mutation> and evidence to the user when approval is required.
7. After approval, call <Mutating tool> exactly once with <stable identifier/idempotency key>.
8. Verify success from the tool's returned record identifier and state. Never claim success from intent alone.

Constraints
- Never change <protected fields/actions>.
- Never process more than <N> records.
- Never retry a mutating tool after an ambiguous result; re-read the target first.
- Do not call tools outside their documented purpose.

Completion
- Return <record number/link>, fields changed, evidence, and any remaining manual step.
```

Prompt rules:

- Use specific action verbs: Retrieve, Validate, Compare, Update, Create, Notify, Stop.
- Number steps and make each depend on a visible prior output.
- State tool names exactly; rename instructions if tools are renamed.
- Define positive, negative, no-result, ambiguous, unauthorized, and error paths.
- Define what “done” means, including a durable record/result—not merely a response.
- Include concise examples for ambiguous classifications or routing rules, not exhaustive business logic better held in a decision table.
- Say what the agent must not do. “Follow company policy” is not an enforceable boundary; name the protected fields/actions and use server-side controls.
- Do not use confidence percentages unless they are produced by a calibrated tool. Prefer explicit evidence/no-evidence rules.

### 4. Add tools and information

Each tool description is sent to the LLM. It must state:

- one action the tool performs
- when to use it and when not to use it
- required inputs, formats, and whether values come from a prior tool output/value override
- affected table/system and maximum scope
- returned fields and their meaning
- authorization/approval expectations
- idempotency/duplicate behavior
- recoverable versus terminal errors

Use structured, small outputs. Configure an output transformation only when downstream reasoning needs it. A Premium Chat widget transformation can cause an extra LLM call; skip it when direct field-to-widget mapping is sufficient.

| AI Agent Studio tool type | Use it for | Production guidance |
| --- | --- | --- |
| Record operation | Simple Create, Look up, Update, or Delete on one known table | Prefer lookups and bounded single-record writes. Use explicit conditions, fields, limits, and returned fields. Keep Delete supervised or avoid it. Inputs use `{{inputname}}`; camelCase input names are unsupported. |
| Flow action | One reusable Flow Designer action, including IntegrationHub operations | Preferred for a focused write or external call with typed inputs/outputs. The runtime user must pass the flow-action ACL. |
| Subflow | A reusable multi-step deterministic transaction | Preferred for approvals, orchestration, retries, idempotency, multi-record work, or integrations. The runtime user must pass the subflow ACL. |
| Script | A server-side JavaScript capability | Last resort. Use `GlideRecordSecure`, user-safe encoded queries, narrow limits, input validation, and a stable JSON-like output. Never embed secrets or make open-ended queries. |
| Now Assist skill | A published and activated packaged/custom generative skill | Use for bounded summarization, generation, extraction, or classification inside an agent. The runtime chain must pass the skill ACL; skills/tools run as Dynamic users. |
| Catalog item | Conversational request/order fulfillment | Preserve user criteria, variable validation, approvals, duplicate checks, and fulfillment Flow. Use Supervised mode for consequential orders. |
| Search retrieval | RAG over an AI Search profile and selected sources | Choose keyword, semantic, or hybrid deliberately; return only needed fields; tune result limit and threshold; test source ACLs and no-result behavior. |
| File upload | Static PDF, DOCX, or TXT context attached to the agent | Australia docs allow up to five files, 5 MB each. Anyone who can use the agent can see file information; treat this as governed published content, not a secret store. |
| Web search | Bing/Google-backed current public information | Domain-allowlist where possible. Google grounding uses global infrastructure and may not preserve the instance processing region; complete privacy/data-residency review. |
| Conversational topic | An LLM Virtual Agent topic that gathers structured user input | Useful for dates, choices, and guided clarifications. Do not duplicate deterministic catalog/VA logic in the agent prompt. |
| Knowledge Graph | Relationship-aware structured and unstructured instance context | Write a verb-led query instruction, restrict graph/tags/anchors, and decide whether the last five conversation turns should be included. |
| Desktop action | UI automation in external/desktop applications | Use only where APIs/integrations are unavailable; constrain allowed sites, use supervised execution for sensitive actions, and test environmental prerequisites. |
| MCP server tool | A capability discovered from an authenticated external MCP server | Authenticate first; approve server, tool, data egress, scopes, timeout, error contract, audit, and Guardian coverage. |

The documented Chat-agent tool picker does not expose an arbitrary direct REST-call tool. For external APIs, prefer a typed IntegrationHub/Flow action or subflow with a Connection and Credential Alias. Use an authenticated MCP server tool when MCP is the approved integration contract. Use a script only when neither supported path fits.

Execution mode:

- **Autonomous:** no human input is required for that tool call. Use for permissioned reads, low-risk reversible writes, and deterministic actions with strong validation and idempotency.
- **Supervised:** human review/input is required before execution. Use for deletion, approvals, user/role changes, financial/HR/legal decisions, external messages or orders, security remediation, bulk updates, ambiguous matches, and irreversible actions.

Do not rely on prompt text alone for human-in-the-loop. Set the tool to Supervised and preserve any Flow approval/control.

### 5. Configure security controls

AI agent security is a chain, not one ACL:

1. The agentic workflow ACL decides who may invoke the workflow.
2. Workflow identity and role mask determine its effective runtime roles.
3. The AI agent ACL is evaluated against those effective roles.
4. Agent identity and role mask further restrict effective roles.
5. Tool ACL, Flow/action/skill ACL, table/field ACL, application access, domain separation, and data policy are evaluated downstream.
6. Skills may apply another role mask.

Key distinctions:

- **Invocation ACL:** who can discover/invoke an agent or workflow; it does not grant runtime actions.
- **Dynamic user:** runs from the invoking context. Role masking is the intersection of invoking roles and approved roles and can only remove privileges.
- **AI user:** dedicated fixed identity. Role masking does not apply to the AI user. Use only for a documented service-identity requirement with narrowly assigned roles; it can otherwise become an elevation path.
- **Tools/skills:** always execute as Dynamic users in the downstream chain, even when an upstream workflow/agent uses an AI user.

Australia Patch 3 adds deny-by-default wildcard behavior for fresh/reset instances for `gen_ai_agent`, `gen_ai_workflow`, `gen_ai_skill`, `Flow`, and `flow_action`. Every custom asset should have an explicit ACL regardless of whether an older instance still permits wildcard access. AI Agent Studio creates Allow If ACLs; “users with specified roles” means any listed role can allow invocation. Use direct ACL administration only when a stronger Deny Unless design is intentionally required and tested.

Security baseline:

- default to Dynamic user and a minimal approved-role list at workflow and agent levels
- test one allowed and one denied invoking persona with **Test access**/Access Analyzer
- test table and field ACLs with non-admin users, including restricted/domain/HR COE records
- use Supervised mode for consequential tools and enable UI validation for AI-initiated record updates where compatible
- keep Guardian prompt-injection detection on; start offensiveness detection in Log during validation and use Block and log where policy requires
- remember Guardian complements ACLs, authorization, data classification, privacy policy, and tool validation; it does not replace them
- configure sensitive-topic filters for supported HRSD/CSM Virtual Agent conversations
- review model/provider region, data sharing/overflow, de-identification, external web search, MCP/A2A data egress, memory, and log retention

Australia Patch 2 UI-validation controls are property-gated. Verify `glide.ai_record_activity.validation.feature.enabled` and the relevant channel gates before relying on required-field/UI validation for Now Assist panel, skill/Virtual Agent, or agentic record updates. Server-side ACLs, data policies, Flow validation, and tool validation remain required.

### 6. Configure triggers and channels

Triggers are optional. Chat-only agents/workflows do not need one. For automatic execution, select an available trigger, give it a precise objective, bind a table where applicable, require at least one selective condition, select the output channel, and keep it inactive until all tests pass.

Australia documentation calls out scheduled and email triggers in addition to table/condition-based definitions. Scheduled triggers process 10 records by default via `sn_aia.max_scheduled_trigger_query`; do not raise this without volume, assist, runtime, and side-effect analysis. Email triggers operate on existing reply/email records rather than unseen inbound mail; confirm the exact table in the installed version because the agent and workflow topics differ in current docs.

Channel model:

- **AI agent:** can be exposed through selected assistants in Now Assist for Virtual Agent; set processing/completion messages and activate only after testing.
- **Agentic workflow:** can be exposed in the Now Assist panel and through generated UI actions on selected tables/conditions. Core UI/Workspace AI Workflows panel uses `com.glide.agentic_processes_view.enabled=true`.
- **Background/non-interactive:** use the AI Agent Background Channel when Workspace/Core UI invocation must continue without live fallback questions. Define a final visible outcome and failure message.
- **Interactive:** use when missing context may be requested from the user or supervised tools need user input.
- **External:** A2A/secondary-agent and MCP exposure require separate authentication, ACL, governance, audit, and data-contract review.

Triggered execution output can appear in the Now Assist panel or Virtual Agent; the panel user needs `now_assist_panel_user`. Agentic workflow execution/progress and supervised questions can also be reviewed in the Core UI/Workspace AI Workflows panel.

Australia Patch 3 runaway-trigger kill switch:

- Default thresholds are five fires per record per 24 hours, 25 distinct breaching records, and three consecutive breach windows/days.
- `kill_switch.mode` ships as `warn_only`; `enforce` warns on days 1–2 and disables the trigger on day 3. Re-enabling resets the cycle.
- Keep alert owners current. Treat the kill switch as a backstop, not a substitute for selective conditions, idempotency, and volume tests.

### 7. Build an agentic workflow

Navigate to **AI Agent Studio > Create and manage > Agentic workflows > New**.

Define:

- **Name/description:** the business outcome, trigger context, and final artifact/state.
- **List of steps/base plan:** sequential starting condition, named worker assignment, decision points, user-visible/supervised steps, failure paths, and completion state.
- **Agents:** assign only workers used by the plan. ServiceNow recommends no more than roughly 8–10 even though the platform can associate more; smaller, non-overlapping teams improve routing and cost.
- **Security:** configure workflow invocation ACL and identity/role mask, then reconcile every worker/tool downstream.
- **Trigger/channels:** optional automation plus Now Assist panel/UI action availability.

Example base plan:

```text
1. Use Incident Context Worker to retrieve and validate the incident. Stop if missing, closed, unauthorized, or out of scope.
2. Use Resolution Evidence Worker to search only approved knowledge, similar resolved incidents, active outages, and recent changes. Return citations and explicitly report conflicts/no evidence.
3. Show the proposed categorization and resolution plan to the user. Do not change priority, state, assignment, or resolution fields yet.
4. If the user approves, use Incident Action Worker to execute the approved subflow exactly once.
5. Re-read the incident. Report the final field values, generated task/change/problem identifiers, and any action that failed or still needs a human.
```

Do not create a separate worker for every tiny step. Split only when specialties, data boundaries, security contexts, or tool sets are genuinely different.

### 8. Test and evaluate

Minimum test matrix before activation:

| Layer | Required evidence |
| --- | --- |
| Manual behavior | Test active and candidate List-of-steps versions with a specific safe record/task. Inspect plan, messages, decision log, selected tools, inputs, outputs, retries, and final record state. |
| Tool contract | Happy path, no result, multiple matches, invalid input, access denied, validation error, duplicate/idempotent replay, timeout, and ambiguous post-write response. |
| Security | **Test access** for allowed and denied invoking users. Access Analyzer must show workflow, agent, tool, Flow/action/skill, table, and field decisions as expected. |
| Evaluations | Use representative filtered datasets and an explicit Run as user. Measure overall task completeness, tool selection/performance, and tool-calling input correctness; add domain metrics for protected fields, approval compliance, and factual grounding. |
| Channel | Test Standard and Premium Chat when installed, Now Assist panel, Virtual Agent/assistant, Workspace/Core UI/UI action, and triggered/background mode separately as applicable. |
| Side effects | Verify durable record IDs, audit/history, flow contexts, approvals, external call logs, notifications, and downstream state. Clean safe test artifacts. |
| Consumption/latency | Record tool count, assist tier, execution duration, P90/P95 latency, retry/failure count, and whether output/widget transformations add avoidable calls. |

Automated agentic evaluations use execution logs and LLM judges. Default task-completion guidance is Excellent 90–100%, Good 70–89%, Moderate 50–69%, Poor 0–49%, but release criteria must include deterministic guardrail assertions. Never deploy a mutating agent merely because an LLM-judge score is high.

Debug in this order:

1. wrong/missing source records, knowledge, search profile, graph, or stale content
2. ACL/identity/role-mask/domain/data-policy failure
3. tool description, input mapping/value override, output size/format, or error contract
4. deterministic Flow/subflow/script/integration failure
5. overlapping agent roles or ambiguous workflow base plan
6. prompt wording/model-provider issue

Activity and execution plans expose tasks, messages, tool executions, versions, and final states. Fix the failing layer; do not keep lengthening the prompt to compensate for a broken tool or ACL.

### 9. Deploy and operate

1. Keep agents, workflows, and especially triggers inactive while building and transporting.
2. Name and test a candidate List-of-steps version; preserve the last known-good active version.
3. Confirm explicit ACLs, role masks, tool ACLs, Guardian, privacy/provider settings, UI validation, kill-switch mode, alert recipients, and operational owners.
4. Transport in the correct application/update set. Triggers contain instance-specific data: move them inactive, re-resolve target dependencies, and activate only after target tests.
5. In the target, test access and one safe behavior path before activating the agent/workflow/channel. Activate the trigger last.
6. Pilot with a narrow persona, table condition, channel, and volume. Keep high-impact tools supervised.
7. Monitor Now Assist Center and AI Agent Studio dashboards for executions, task completion, failure, latency, tool count, assist consumption/tier, Guardian events, and feedback.
8. Define rollback as trigger deactivation, agent/workflow deactivation, active-version revert, tool/Flow deactivation where safe, and bounded reversal of runtime data. Update-set backout does not reverse created/updated task data or external effects.

## Real-Action Design Patterns

### Update a record

- Simple, one-table, one-record update: bounded Record operation with stable identifier and exact allowed fields.
- Multi-field business transaction: Flow action/subflow with validation, authorization, idempotency, audit, and typed output.
- Never let the LLM write an arbitrary encoded query or arbitrary field/value map to a mutating tool.
- Re-read after write and report the actual final state.

### Create a ticket/request

- Use a Catalog item tool when conversational ordering and catalog governance fit.
- Use a dedicated subflow for incident/case/task creation when the input contract and deduplication logic are custom.
- Return the created record number/sys_id/link and `already existed` versus `created` status.

### Run a Flow or integration

- Expose the smallest existing action or subflow, not an entire generic automation toolbox.
- Put Connection and Credential Alias, retries, timeouts, response validation, and idempotency inside the Flow/IntegrationHub layer.
- Keep external calls supervised until data egress, authorization, and duplicate behavior are proven.

### Call an external API or agent

- Preferred: typed IntegrationHub action/subflow.
- Approved MCP ecosystem: authenticated MCP client/server tool with least scope, explicit descriptions, Guardian/data controls, and audit.
- Agent-to-Agent: external agent configuration with explicit identity, protocol, timeout, and responsibility boundaries.
- Do not pass secrets through prompts, tool inputs generated by the LLM, logs, or record fields.

## Consumption And Cost Discipline

ServiceNow meters Now Assist in **assists**, not raw token billing to the customer. Contract entitlements are pooled at account level; the current ServiceNow Assist Overview says both production and sub-production use consumes assists, usage aggregates daily, and the entitlement period resets annually from the applicable purchase/contract date. Always verify the current contract and legal consumption schedule.

Current published agentic-workflow tiers:

| Tool invocations in one agentic workflow run | Tier | Assists |
| --- | --- | --- |
| 0–4 | Small | 25 |
| 5–8 | Medium | 50 |
| 9–20 | Large | 150 |

One action is one tool invocation. The published boundary says a workflow ends at completion, 20 actions, or one hour of inactivity; actions beyond 20 begin another chargeable workflow. Treat test/evaluation and sub-production runs as billable consumption unless the contract says otherwise.

Reduce consumption without degrading control:

- prefer a deterministic Flow or one skill for fixed paths
- keep agent roles narrow and workflow worker count small
- remove duplicate/overlapping tools and ambiguous descriptions that cause retries
- return only necessary fields/records and cap search results
- use value overrides from prior structured outputs rather than another reasoning/search call
- skip LLM output/widget transformations when deterministic mapping is enough
- do not split one deterministic transaction across many tiny tools solely for architecture aesthetics
- monitor top-consuming assets, average tool executions, retries, latency, and tier transitions
- configure assist-spike/failure/latency notifications and the runaway-trigger kill switch

## Common Failure Modes

- **Agent uses the wrong tool:** overlapping names/purposes, missing negative-use cases, or vague inputs. Split multipurpose tools and tighten descriptions.
- **Agent loops or repeats a write:** ambiguous success output, no idempotency, instructions permit retry, or trigger re-fires on the agent's own update. Return a durable result, re-read before retry, exclude AI-completed records in trigger conditions, and use kill-switch monitoring.
- **Agent claims success without a side effect:** instructions define conversational output as completion. Require a returned record identifier and post-write verification.
- **Admin tests pass, users fail:** invocation ACL passed but role masking/downstream tool or table ACL failed. Use Test access with the actual persona.
- **AI user becomes a privilege bridge:** fixed identity has broad roles and low-privilege callers can invoke it. Narrow the AI user, invocation ACL, agent/tool ACLs, and approved use cases; prefer Dynamic user.
- **Prompt becomes a policy engine:** long instructions duplicate decision tables, Flow logic, ACLs, or catalog policies. Move deterministic rules to deterministic components.
- **Too many agents/tools:** Orchestrator routing is ambiguous, latency rises, and assist tier increases. Merge only cohesive steps into a subflow; remove workers without distinct expertise.
- **RAG hallucinates or returns restricted content:** unhealthy index/content, wrong search profile/source, excessive result set, or ACL mismatch. Fix retrieval and test denied/no-result queries.
- **Production trigger fan-out:** broad condition, recursive record update, schedule volume, or inactive-on-source/active-on-target mismatch. Pilot narrow, activate trigger last, and monitor the first runs.
- **Guardian assumed to provide authorization:** Guardian filters content risks; it does not decide whether a record update or external call is allowed.

## Reference Implementations

### Incident triage and controlled resolution

Use a single agent for categorization only. Use an agentic workflow when investigation spans separate context, evidence, and action specialists.

Workers and tools:

- **Incident Context Worker:** bounded incident lookup, caller/CI lookup, active outage/change lookup
- **Resolution Evidence Worker:** hybrid AI Search over approved KB and similar resolved incidents; Knowledge Graph for service/CI relationships
- **Incident Action Worker:** supervised `Apply approved incident triage` subflow; optional supervised `Create problem candidate` subflow

Action-subflow contract:

- inputs: incident sys_id, proposed category/subcategory/CI, approved resolution text, approving user, idempotency key
- validates: incident still eligible, allowed fields only, referenced records active/visible, approval present, no prior matching execution
- outputs: status (`updated`, `already_complete`, `validation_failed`, `not_authorized`), incident number/sys_id, changed fields, related task numbers, error message

Hard rules: never change priority, state, assignment, or resolution without an explicit approved path; never infer a CI from a weak match; cite evidence; stop on conflicting data.

### HR case handler

Use Dynamic user identity with HR-specific approved roles, COE security, HR criteria, and domain separation. Do not expose as Public or broadly Authenticated.

Tools:

- restricted HR case lookup returning only necessary fields
- HR knowledge search profile scoped to published, permissioned HR content
- activated HR summarization/sensitivity skill where licensed
- supervised `Route HR case` subflow using a decision table and allowed assignment groups
- supervised catalog/Journey subflow for approved employee services

Instructions must refuse to infer medical, disciplinary, compensation, protected-class, legal, or employment conclusions. On sensitive-topic detection, route to a qualified human. Generated summaries are not the system of record; preserve case audit and access controls.

### Employee onboarding workflow

Use an agentic workflow only when the process must adapt across HR, identity, facilities, hardware/software, and manager context. Keep provisioning itself deterministic.

Workers:

- **Onboarding Context Worker:** validate employee, start date, location, department, manager, employment type, and existing onboarding case
- **Entitlement Planner:** decision table/Knowledge Graph to derive the approved standard bundle; no free-form entitlement invention
- **Provisioning Worker:** supervised or policy-approved idempotent subflows/catalog items for accounts, groups, devices, software, facilities, and approvals
- **Journey Coordinator:** create/update Journey/onboarding tasks and summarize exceptions

Use employee sys_id + start date + bundle version as an idempotency key. Return existing versus created request numbers. Never assign privileged groups, order nonstandard items, or bypass approvals because the LLM judged them “reasonable.”

## MCP Caution

- Adding an MCP server in AI Agent Studio can use OAuth 2.1, API key, or an existing Connection and Credential Alias path. Authenticate before exposing tools to an AI agent.
- Treat MCP tools like integrations: validate authentication, least privilege, tool descriptions, input/output contract, error behavior, auditability, timeout, rate limits, data egress, Guardian coverage, and revocation before autonomous use.
- Australia MCP Server Console exposes governed ServiceNow capabilities to external clients. That is a separate inbound architecture from an AI Agent Studio MCP client calling an external server; model both trust directions explicitly.

## Now Assist In AI Search / Genius Results

Now Assist in AI Search (`sn_ais_assist`) combines AI Search retrieval with LLM generated/selected answer cards. It can appear in Service Portal, Virtual Agent, Employee Center, global search, and workspace search depending on search-profile configuration.

Genius Result types:
- **Now Assist Multi-Content Response Genius Results**: newer/recommended Platform workflow skill. Synthesizes answers from multiple sources and supports citations and follow-up questions.
- **Now Assist Q&A Genius Results**: legacy/maintenance-mode path that generates answers from knowledge article results using Now LLM Service.
- **External Content Q&A Genius Results**: answers from external content, for example SharePoint Online documents.
- **Now Assist Actions Genius Results**: legacy/maintenance-mode path that selects and displays relevant Catalog Items and Virtual Agent topics.

Multi-Content Response details:
- Can synthesize from knowledge articles, catalog items, Knowledge Graph schema node records, enhanced chat/Virtual Agent results, and external content documents/attachments.
- Answer cards include citations.
- In portal, workspace, and enhanced Virtual Agent experiences, answer cards can show **Ask a follow-up** and open the Now Assist panel.
- For global/workspace search, activating Multi-Content Response on a search profile overrides other Genius Result configurations for that profile.
- Topic citations in global/workspace search need the Now Assist panel active and a search source derived from the Skill/topics indexed source linked to the search profile.
- By default, docs state Multi-Content Response uses Azure OpenAI with Now LLM Service fallback; admins can select a different provider in Now Assist Admin where available.

Legacy Q&A/Actions details:
- Q&A sends eligible knowledge article results to Now LLM Service and displays source-linked answer cards.
- Actions sends selected Catalog Item and Virtual Agent topic content to Now LLM Service for ranking/filtering. Service Portal supports Catalog Items; Virtual Agent supports Catalog Items and VA topics.
- Both Q&A and Actions are in maintenance mode from Now Assist in AI Search 11; use Multi-Content Response when the release and search experience support it.

Enablement paths:
- Portal/mobile quick setup: **Self-Service > AI Search > Now Assist in AI Search Setup**, then select Now Assist Genius Results checkboxes for applications/search profiles. Documented profiles include Employee Center, Service Portal, Employee Center Pro Kiosk, and Now Mobile.
- Search-profile setup: AI Search Admin / Search Profiles. Link Genius Result configurations to the relevant search profile, verify search sources, publish the profile, and test in the target portal/workspace/global search.

Configuration checks:
- Search profiles must include the right search sources, synonyms/stop words/typo handling, Genius Result configs, and result improvement rules.
- For HRSD/Employee Center, validate both knowledge and catalog content quality. Genius Results are only as good as indexed, permissioned content.
- English is native. Additional languages generally require Dynamic Translation or multilingual setup depending on the feature.
- In domain-separated environments, users should only receive answers from data in their domain; verify with non-admin users.

## Verification Plan For Vår Energi

1. Confirm target instance/release/patch and Now Assist entitlements.
2. In Now Assist Center/Admin, record installed plugins and available product cards.
3. Verify HRSD plugin `sn_hr_gen_ai`, AI Search plugin `sn_ais_assist`, Now Assist Platform, and any required Skill Kit / Controller plugins.
4. Review Account, model providers, model versions, and region/provider availability.
5. Review Guardian/privacy settings before enabling skills with HR data.
6. Activate one low-risk skill first, preferably case summarization or a search Genius Result in a limited profile.
7. Test with:
   - Admin.
   - HR case writer/agent.
   - Manager/employee role where relevant.
   - Sensitive/employee-relations cases where availability should be restricted.
   - Domain-separated or HR criteria constrained data if used.
8. For Genius Results, test exact, broad, ambiguous, no-result, restricted-content, and non-English queries.
9. For AI agents, test one known record/task manually, one access-denied or restricted-role path, the selected workflow/agent version, tool execution/error behavior, and automated evaluations when result quality must be compared across cases.
10. Capture final configuration records, roles, plugin versions, search profiles, workflow/agent versions, model/provider assumptions, and rollback/deactivation steps.

## Vår Energi AI Search Assist Lessons

- For General Inquiry AI Search Assist in Vår Energi DEV, `aisa_rp_config.search_app` overrides the older `cxs_rp_config` contextual-search behavior in Employee Center. On 2026-06-16, OOTB `ESC AISA Long text to query Search Application` used profile `[AI Search Assist - Long Text to Query] - KB and Catalog`, whose sources were HR General Knowledge plus generic Service Portal Catalog. If non-HR catalog items appear in the record producer suggestions, use or create a search application/profile that maps only to the HR knowledge source. Match the ServiceNow search-application pattern by adding one `sys_search_filter` Source Facet Bucket per mapped source; for HR-only General Inquiry that means a single `Knowledge` bucket for `[AISA - Long Text to Query] - knowledge`. After creating a new `ais_search_profile`, publish it before portal testing; `state=new` profiles can look fully configured but will not drive the AI Search Assist runtime. Expect ServiceNow to auto-capture companion suggestion reader groups in the same Global update set.
- For Vår Energi DEV HRSD case summarization, do not trust `sn_nowassist_skill_config_status.active=true` alone. On 2026-06-25 the skill status and panel settings were active, but the live `sn_hr_gen_ai.HRSDSkillUtils` Script Include had reverted to the empty OOTB extension while update history still contained the 2026-05-29 capability-ID injection fix. Verify the live wrapper script and `new sn_hr_gen_ai.HRSDSkillUtils().canUserExecuteInProductSkill(...)` after Now Assist app deactivate/activate, repair, or update activity.
- On 2026-06-30, Vår Energi DEV had Employee Center Genius Results turned on for the `esc` portal: `sp_portal.url_suffix=esc` uses `ESC Portal Default Search Application` (`sys_search_context_config=7296910f53171010069addeeff7b12e7`), which uses AI Search, hybrid search, Genius Results limit 10, and published `ESC Portal Default Search Profile` (`ais_search_profile=fd6491cb53171010069addeeff7b123f`) mapped to active `Now Assist Multi-Content Response` (`ais_genius_result_configuration=088c73a5430302104eaff03a5ab8f22f`).
- In Vår Energi DEV on Australia Patch 2 Hotfix 2, the visible Employee Center Now Assist search page is `sp_page.id=nowassistselfservice`, not the legacy `sp_page.id=search` layout. It renders OOTB widget `Now Assist Self Service Widget` with `<now-assist-full-page-wrapper-app render-type="ENHANCED_CHAT">`; the answer-card presentation is therefore largely controlled by the packaged Now Assist full-page component and deployment/channel branding, not by the old `Search Page` Service Portal widget. Treat screenshots from older docs/releases as layout references, not exact acceptance criteria.

## Official Sources

- ServiceNowDocs repository and release map: https://github.com/ServiceNow/ServiceNowDocs and `llms.txt`
- ServiceNowDocs AI publication: `markdown/intelligent-experiences/index.md`
- ServiceNow Assist Overview and current consumption schedule (effective 2026-07-10): https://www.servicenow.com/content/dam/servicenow-assets/public/en-us/doc-type/legal/sn-assist-overview.pdf
- Now Assist AI Agents Australia release notes: https://www.servicenow.com/docs/r/release-notes/now-assist-ai-agents-rn.html
- Agentic AI security and governance: https://www.servicenow.com/docs/r/platform-security/now-assist-security.html
- Configure AI agents: `markdown/intelligent-experiences/configuring-ai-agents.md`
- AI Agent Studio: `markdown/intelligent-experiences/ai-agent-studio.md`
- Create an AI agent: `markdown/intelligent-experiences/configure-next-best-action-agent.md`
- Define agent specialty: `markdown/intelligent-experiences/define-specialty.md`
- Add tools and information: `markdown/intelligent-experiences/add-tool-aia.md`
- Record, Flow action, subflow, script, Skill, catalog, retrieval, Knowledge Graph, and MCP tools: `markdown/intelligent-experiences/add-database-op-ai-agent.md`, `add-flow-action-ai-agent.md`, `add-sub-flow-ai-agent.md`, `add-script-ai-agent.md`, `add-skill-ai-agent.md`, `add-catalog-ai-agent.md`, `add-retriever-ai-agent.md`, `add-knowledge-graph.md`, and `add-mcp-server-tool.md`
- Create an agentic workflow and define its requirements: `markdown/intelligent-experiences/configure-use-case-ai-agents.md`, `define-key-requirements.md`
- Writing guidelines and examples: `markdown/intelligent-experiences/gg-creating-aia.md`, `example-aia.md`, `example-aw.md`
- Security chain, ACLs, identities, and role masking: `markdown/intelligent-experiences/aia-security-implementation.md`, `acls-and-rolemasking.md`, `aia-role-masking.md`, `aia-acl-configuration.md`
- Trigger, channel, UI action, and in-product execution: `markdown/intelligent-experiences/add-trigger-aia.md`, `add-trigger-aw.md`, `channels-access-aia.md`, `channels-access-aw.md`, `in-product-agentic-ai.md`
- Runaway-trigger kill switch: `markdown/intelligent-experiences/aia-kill-switch.md`
- Guardian for AI agents: `markdown/intelligent-experiences/enable-aia-na-guardian.md`
- Manual AI agent execution test: `markdown/intelligent-experiences/test-ai-agent.md`
- Access testing and version control: `markdown/intelligent-experiences/test-aia-access.md`, `test-aw-access.md`, `version-control.md`
- Agentic evaluations: `markdown/intelligent-experiences/agentic-evals.md`
- Evaluation execution/results: `markdown/intelligent-experiences/execute-aia-eval.md`, `aia-eval-metrics.md`
- Agentic runtime properties: `markdown/intelligent-experiences/na-aia-reference.md`
- Add MCP server in AI Agent Studio: `markdown/intelligent-experiences/add-mcp-client-on-ai-agent-studio.md`
- AI Control Tower: `markdown/intelligent-experiences/ai-control-tower/ai-control-tower-landing.md`
- Configure Now Assist settings in Now Assist Center: https://www.servicenow.com/docs/r/intelligent-experiences/now-assist-center-configure-admin-settings.html
- Install and configure Now Assist plugins: https://www.servicenow.com/docs/r/intelligent-experiences/install-configure-essential-now-assist-plugins.html
- Configure Now Assist for HRSD: https://www.servicenow.com/docs/r/employee-service-management/now-assist-for-hrsd/configure-now-assist-hr.html
- Supporting information for Now Assist for HRSD: https://www.servicenow.com/docs/r/employee-service-management/now-assist-for-hrsd/support-info-hr-assist.html
- Skill inputs and triggers for Now Assist for HRSD: https://www.servicenow.com/docs/r/employee-service-management/now-assist-for-hrsd/now-assist-hrsd-skill-inputs.html
- Enable the Now Assist Journey generation skill: https://www.servicenow.com/docs/r/employee-service-management/journey-designer/enable-jny-gen.html
- Now Assist in AI Search: https://www.servicenow.com/docs/r/platform-administration/ai-search/now-assist-ais.html
- Now Assist Multi-Content Response Genius Results: https://www.servicenow.com/docs/r/platform-administration/ai-search/now-assist-multi-content-qna-genius-results.html
- Now Assist Actions Genius Results: https://www.servicenow.com/docs/r/platform-administration/ai-search/now-assist-catalog-ordering-gr.html
- Enable Now Assist genius results: https://www.servicenow.com/docs/r/employee-service-management/employee-experience-foundation/na-qa-activate.html
- Create a skill: https://www.servicenow.com/docs/r/intelligent-experiences/now-assist-skill-kit/create-new-skill.html
- Configure Now Assist Skill Kit: https://www.servicenow.com/docs/r/intelligent-experiences/now-assist-skill-kit/configuring-now-assist-skill-kit.html
- Configure skill deployment settings: https://www.servicenow.com/docs/r/intelligent-experiences/now-assist-skill-kit/configure-skill-settings.html
- Configure security controls for a skill: https://www.servicenow.com/docs/r/intelligent-experiences/now-assist-skill-kit/nask-access-control.html
- Manage AI models: https://www.servicenow.com/docs/r/intelligent-experiences/manage-large-language-models.html
- Configure Now Assist privacy policies: https://www.servicenow.com/docs/r/intelligent-experiences/configure-privacy-policies.html
