# ServiceNow CMDB and CSDM Field Guide (2026)

## Purpose and version baseline

Use this reference for architecture, implementation, governance, diagnosis, migration, and day-to-day work involving ServiceNow Configuration Management Database (CMDB), Service Graph, and Common Service Data Model (CSDM).

The version baseline is ServiceNow **Australia (2026)** and **CSDM 5**, with durable practices separated from release- or Store-app-dependent behavior. Always verify the target instance family, installed CMDB Workspace/Service Graph Workspace version, Store apps, roles, tables, and licensing before proposing or changing configuration. CSDM guidance is broader than the physical schema installed in any one instance.

Primary anchors:

- [ServiceNow CMDB documentation (Australia)](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_ITILConfigurationManagement.html)
- [ServiceNow CSDM documentation (Australia)](https://www.servicenow.com/docs/r/servicenow-platform/common-service-data-model-csdm/csdm-landing-page.html)
- [Official CSDM 5 white paper announcement and attachment](https://www.servicenow.com/community/common-service-data-model/csdm-5-finally-get-the-csdm-5-white-paper-here/ta-p/3254967)
- [Australia CMDB release notes](https://www.servicenow.com/docs/r/release-notes/cmdb-rn.html)
- [CMDB design guidance](https://www.servicenow.com/content/dam/servicenow-assets/public/en-us/doc-type/resource-center/white-paper/wp-cmdb-design-guidance.pdf)

## Executive summary

1. **CMDB is an operational graph, not a universal inventory.** It stores configuration items (CIs), their attributes, and the relationships needed to support agreed outcomes such as incident routing, change impact, service health, vulnerability response, asset reconciliation, and technology risk.
2. **CSDM is the placement and semantics contract for that graph.** It is ServiceNow's prescriptive data-model guidance, not a SKU, code package, reporting suite, or automatic repair tool. It tells teams which OOTB records, references, and relationships to use so products work together.
3. **Start with outcomes and a narrow scope.** Choose one or two important services, the principal CI classes needed for those services, and two or three workflows that will consume the data. Do not load every source or model the entire enterprise before proving value.
4. **Route every automated CI write through IRE.** Identification prevents duplicates; reconciliation determines which sources may update which attributes. Prefer Discovery and certified Service Graph Connectors, then IntegrationHub ETL, then explicitly IRE-aware custom ingestion. Direct table writes are a data-quality defect even when they appear to work.
5. **Make ownership executable.** Each in-scope class, service, source, and lifecycle policy needs an accountable owner, working steward, authoritative-source contract, health threshold, remediation SLA, and exception path.
6. **Health scores are signals, not the objective.** Configure completeness, correctness, compliance, and relationship health for principal classes and critical services. Drive root-cause remediation of sources, rules, and processes rather than repeatedly repairing individual records.
7. **Separate portfolio, service, and runtime concepts.** A Business Application is a logical portfolio record and is not an operational Incident/Change target. A Service Instance/Application Service represents a deployed service. An Application CI is discovered software running on a host. Business and Technology Management Services describe consumer and provider outcomes.
8. **CSDM 5 is both conceptual and physical.** It adds seven domains, Ideation & Strategy, expanded product/lifecycle guidance, new Service Instance types, SBOM, and AI entities. Several additions were introduced as model-only classes or Store-app content. Verify actual tables before designing around them.
9. **AI increases the cost of weak data.** Natural-language search, autonomous workflows, deduplication recommendations, and impact analysis can act faster, but they inherit missing owners, duplicate CIs, incorrect relationships, and excessive permissions. IRE, ACLs, lifecycle control, evaluations, and human approval are AI prerequisites.
10. **Measure operational outcomes.** A successful CMDB reduces assignment delay, change-analysis effort, outage blast-radius uncertainty, audit effort, integration rework, and technology risk. Population count alone is not success.

## 1. Core concepts and differences

### 1.1 CMDB, CI hierarchy, and relationships

The CMDB is the ServiceNow capability for building a logical representation of assets, services, technology, and their dependencies. A CI is a component placed under configuration control because its state or relationships matter to a defined process. The base CI table is `cmdb_ci`; child tables inherit attributes through the class hierarchy. Examples include hardware, servers, applications, services, business applications, network devices, and database instances.

The class hierarchy provides:

- shared attributes at the highest sensible parent class;
- class-specific attributes and identification behavior below it;
- independent classes whose CIs have their own identity;
- dependent classes whose identity includes a hosting or containment relationship;
- inheritance of ACLs, dictionary settings, health rules, and reconciliation behavior that must be evaluated before extending a class.

Do not create a custom class merely because a team uses a different name. First compare the definition, attributes, identification needs, lifecycle, and product behavior of OOTB classes. When a new class is genuinely required, extend the closest semantic parent and define identification, reconciliation, health, dependency, lifecycle, and ownership rules before population. ServiceNow requires identification and reconciliation rules when creating a class through CI Class Manager. See [CMDB classifications and class dependency](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_CMDBClassifications.html) and [CI Class Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ci-class-manager-landing-page.html).

A CMDB relationship is a record joining a parent CI, a child CI, and a relationship type in `cmdb_rel_ci`. Relationships are directional even when displayed with both descriptors, for example `Runs on::Runs`, `Depends on::Used by`, or `Contains::Contained by`. They enable dependency traversal, service mapping, impact calculation, root-cause analysis, and dependent-CI identification. References such as owner, company, model, service portfolio, or published offering are not interchangeable with `cmdb_rel_ci` relationships.

Relationship rules:

- Use prescribed CSDM relationships and OOTB relationship types.
- Model only relationships that support a consumer, workflow, report, control, or identification rule.
- Preserve the direction ServiceNow expects; impact analysis commonly traverses relationships in reverse.
- For infrastructure, ask “what would Discovery do?” and match the discovered pattern when manual modeling is unavoidable.
- Avoid duplicate semantic edges, ambiguous custom relationship types, cycles without meaning, and relationship explosion.
- Treat dependent relationships as identity-bearing data; do not delete them casually.
- Track source and freshness for non-dependent relationships where lifecycle decisions depend on provenance.

ServiceNow explains the relationship structure and the IRE importance of dependent relationships in [CI relationships in the CMDB](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_CIRelationships.html).

### 1.2 CMDB versus Asset Management

An **asset** answers financial, contractual, custody, inventory, depreciation, and procurement questions. A **CI** answers operational, dependency, support, change, incident, health, and configuration questions. One real item can have both records, linked and synchronized through model-category and asset/CI mappings; many CIs have no asset, and some assets are not operational CIs.

Do not merge the concepts or independently maintain duplicate fields. Define which record drives lifecycle, verify mappings, and reconcile status semantics. In Australia, asset and CI updates synchronize only when the records point to each other and mappings exist; ServiceNow also provides an IRE-based option for creating certain hardware CIs from assets. See [Asset and CI management](https://www.servicenow.com/docs/r/it-asset-management/hardware-asset-management/c_ManagingAssets.html).

### 1.3 What CSDM is and is not

CSDM is ServiceNow's standard, shared set of service-related definitions and prescriptive modeling guidance. It spans CMDB and non-CMDB tables and supports consistent use across ITSM, ITOM, ITAM, Enterprise Architecture, SPM, CSM, SecOps/IRM, DevOps, and industry workflows.

CSDM is:

- a reference architecture and common language;
- guidance for OOTB tables, labels, references, relationships, and lifecycle;
- a compatibility contract used by ServiceNow product teams;
- an incremental maturity path rather than an all-at-once implementation.

CSDM is not:

- a product/SKU to activate;
- a process implementation method for every ServiceNow product;
- a report pack;
- code that repairs legacy data;
- a mandate to populate every table;
- permission to model every possible dependency.

Alignment matters because product workflows, analytics, impact calculation, portfolio views, natural-language queries, and AI/agentic workflows look for data in expected classes and relationships. Custom models can be made to work, but each product and upgrade then carries translation logic and technical debt. ServiceNow's CSDM documentation identifies the framework as the standard for products using CMDB and ties it to accurate, consistent reporting.

### 1.4 Conceptual versus physical model

The **conceptual model** describes business meaning: a business capability is enabled by applications and services; a deployed service instance depends on technical functions and infrastructure; offerings expose commitments to consumers. The **physical model** is the actual table, reference, choice, relationship type, installed class model, and plugin in a specific instance.

Never assume a conceptual CSDM 5 box is immediately usable as a table. For each entity, verify:

1. the target release and patch;
2. the table and label in `sys_db_object`;
3. the Store app or plugin that supplies it;
4. licensing and subscription-unit implications;
5. UI and API support;
6. IRE, health, lifecycle, and impact-analysis support;
7. the product team that creates and consumes it.

The CSDM 5 white paper explicitly described new Service Instance siblings and AI classes as “model only” at release, with some classes requiring manual maintenance and not initially participating in Event Impact Analysis. Treat that as architectural direction and verify later release evolution.

### 1.5 CSDM 5 domains

| Domain | Purpose | Typical entities | Primary questions |
| --- | --- | --- | --- |
| Foundation | Referential context supporting every other domain | Company, business unit, department, location, users/groups, product models, contracts, CMDB groups, lifecycle, teams, value streams | Who, where, which organization/product, and under what lifecycle or contract? |
| Ideation & Strategy | Early ideas, goals, targets, strategic priorities, and planning | Product idea, planning item, goal, target, strategic priority | Why should we invest and what outcome is intended? |
| Design & Planning | Logical enterprise architecture and application portfolio | Business capability, business process, Business Application, Information Object | What does the enterprise need and how is it logically designed? |
| Build & Integration | Development and integration artifacts | DevOps change model, SDLC Component, AI System Digital Asset, product features | What is being engineered and integrated? |
| Service Delivery | Deployed operational services and enabling technology | Service Instance/Application Service, Technology Management Service and offering, Dynamic CI Group, API, Application, infrastructure, AI Function/Application, OT | What is deployed, how does it run, and who operates it? |
| Service Consumption | Consumer-facing services, offerings, commitments, and catalogs | Business Service, Business Service Offering, request/product/sales catalogs | What outcome can a consumer request or receive, at what level? |
| Manage Portfolio | Cross-domain grouping, investment, ownership, and lifecycle oversight | Service portfolio and related product/application/service portfolios | What should be invested in, governed, rationalized, or retired? |

Foundation supports all domains. The end-to-end lifecycle generally flows **Ideation & Strategy -> Design & Planning -> Build & Integration -> Service Delivery -> Service Consumption**, while Manage Portfolio governs across it. The domains are functional groupings, not a requirement to build a single linear hierarchy.

### 1.6 Foundation, Crawl, Walk, Run, Fly

| Stage | Practical scope | Exit evidence |
| --- | --- | --- |
| Foundation | Govern companies, business units, departments, locations, groups/users, models, contracts, lifecycle, and CMDB groups needed by the pilot | Referential sources and owners are agreed; duplicate organizational/location structures are controlled; reporting dimensions work |
| Crawl | Model a small application scope: Business Applications, deployed Application Services, discovered Applications and hosts; SDLC Component only when useful | One or two critical applications have clear portfolio/runtime separation, owners, environments, sources, and ITSM use |
| Walk | Add provider-side Technology Management Services, offerings, and Dynamic CI Groups | Technical ownership and commitments drive assignment, change approval, grouping, or data synchronization |
| Run | Add Business Service portfolios, Business Services, Business Service Offerings, and their dependencies on service instances | Business impact and subscriber/consumer context are visible in ITSM and service-owner reporting |
| Fly | Add remaining value/capability/information/catalog and advanced portfolio/service constructs that support proven outcomes | Cross-domain reporting and automation produce measurable business outcomes without manual translation |

The stages are a prioritization heuristic, not a licensing sequence. Bring an Information Object, business capability, or other later-stage entity forward when an immediate compliance or business requirement justifies it. The [CSDM Data Foundations dashboard](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/csdm-data-foundations-dashboard.html) organizes indicators by these stages.

## 2. Architecture and comprehensive best practices

### 2.1 Scope from outcomes, not available data

Start with a decision or workflow that is currently slow, risky, or inaccurate. Examples:

- calculate business services affected by a proposed change;
- route incidents to the right provider group;
- identify infrastructure supporting a regulated service;
- reconcile hardware operations with financial asset records;
- measure technology end-of-life risk by business capability;
- trace a vulnerability from component to customer-facing offering.

For each outcome, identify the minimum services, classes, relationships, fields, sources, freshness, and consumers needed. Designate principal classes to keep CI selectors, health jobs, reports, and governance focused. Australia CMDB Success Advisor for Data Foundations uses principal classes and recommends starting with targeted business outcomes rather than all CMDB data ([CMDB Success Advisor](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/cmdb-sa.html)).

### 2.2 Population method decision hierarchy

| Method | Use when | Strengths | Key controls and pitfalls |
| --- | --- | --- | --- |
| Discovery | The infrastructure/device/application can be observed directly | Automated attributes, classes, running software, TCP/dependency relationships, freshness | Credentials/MID coverage, schedules, patterns, ranges, class mapping, duplicate identifiers, licensing, decommission detection |
| Service Mapping | A service instance needs an operational dependency map | Entry-point/top-down discovery, tag/query/manual population options, service impact | Define service boundary and owner first; avoid mapping everything; validate entry points and load balancers; manual maps decay |
| Service Graph Connector | A supported external platform is already authoritative | Certified mappings, guided setup, RTE/IRE, upgrade path, dashboards | Verify current Store version, supported source version, source keys, schedule, subscription implications, and connector ownership |
| IntegrationHub ETL | A custom structured external feed must populate CMDB | Staging, transforms, sample test, RTE-generated IRE payloads, integration dashboard | Define discovery source before mapping; map classes and relationships; reconcile authoritative fields; test deletions and error paths |
| Import Sets / classic transform maps | A bounded file or legacy feed cannot use IH-ETL | Familiar and flexible | IRE is not automatically guaranteed; explicitly invoke supported IRE processing, stage and validate, never use simple coalesce/direct inserts as an identity strategy |
| IRE API / custom integration | Near-real-time or application-specific ingestion needs code | Explicit payload and error handling | Idempotency, stable source-native keys, batched/asynchronous calls, complete relationships for dependent CIs, retry/dead-letter design |
| Manual creation | Low-volume logical records such as services or approved exceptions | Human context and governance | Use Workspace Create CI/Service Instance or another IRE-enforcing path; require owner, source, reason, review date; prohibit manual infrastructure at scale |

ServiceNow lists Discovery, IntegrationHub ETL, Import Sets, external CMDB integrations, and manual creation as supported population paths in [Populating the CMDB](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_OptionsToPopulateCMDB.html). IntegrationHub ETL combines Robust Transform Engine (RTE) and IRE, while classic import sets require more deliberate IRE handling ([IntegrationHub ETL](https://www.servicenow.com/docs/r/servicenow-platform/integration-hub-etl/integrationhub-etl.html)).

Population principles:

- Prefer observation for operational facts, authoritative business sources for ownership/referential data, and service owners for intentional logical models.
- Use one named discovery source per integration behavior, not a generic label shared by unrelated feeds.
- Define authoritative attributes at class and field level before enabling a second source.
- Retain source-native IDs/correlation IDs without treating them as universal identity.
- Include lifecycle signals: `last_discovered`, source status, deletion/tombstone behavior, and what “missing from source” means.
- Stage, sample, preview, and reconcile before scheduling full loads.
- Count inserts, updates, no-change, partial/incomplete, errors, reclassifications, duplicates, and relationship operations per run.
- Never make a source “win” every field merely because it arrived first.

### 2.3 Identification and reconciliation

IRE is the centralized gate for incoming CMDB data. **Identification** determines whether an incoming item matches an existing CI or should be inserted. **Reconciliation** determines whether the incoming discovery source may update the CI or individual attributes. IRE data-source rules can prevent a source from inserting a class while still allowing it to update known CIs. Dependent relationship rules identify CIs whose identity requires a parent/container.

For every in-scope class:

- document identifier entries in priority order and their real-world uniqueness;
- distinguish independent and dependent identification;
- define inclusion rules only with a proven reason;
- create reconciliation rules for contested attributes such as serial number, model, IP, support group, environment, owner, location, and lifecycle;
- define data refresh rules and source-staleness behavior;
- test insert, update, unchanged, incomplete, duplicate, reclassification, and unauthorized-source cases;
- retain sample payloads and IRE results for regression testing without retaining secrets.

Weak identifiers create duplicates; overly broad identifiers merge distinct things. Reconciliation cannot repair a bad identity decision. Conversely, a perfect identifier does not prevent a lower-quality source from overwriting fields unless reconciliation is designed.

See [Identification and Reconciliation Engine](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ire.html) and [configuring IRE](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/configuring-ire.html).

**Australia: Dynamic IRE.** Dynamic IRE can replace manually maintained static identification rules for `cmdb_ci_hardware` descendants. It is not a universal replacement for IRE design. Start in simulation on non-production, compare insert/update/incomplete outcomes and parity, exclude unsuitable custom classes, and commit only after source owners accept the results. Dynamic IRE's algorithms are not customer-editable. See [Dynamic IRE](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/dynamic-ire.html).

### 2.4 Relationship and service-model design

Use the smallest graph that answers the required questions. A practical application/service slice is:

```text
Business Capability
      | Provided by
Business Service -- Published as --> Business Service Offering
      | (offering depends on / is used by)
Service Instance / Application Service
      | Depends on
Application / Database / Middleware
      | Runs on / Hosted on
Infrastructure CIs

Business Application -- Uses --> Application Service
Technology Management Service -- Published as --> Technology Management Offering
Technology Management Offering -- Contains --> Dynamic CI Group or Service Instance
```

The exact relationship must follow current CSDM and consuming-product guidance. Do not infer that every vertical line is a `cmdb_rel_ci` relationship; some are references or many-to-many tables.

Specific distinctions:

- **Business Application:** logical application portfolio record; not version/environment-specific and not an operational Incident/Problem/Change CI.
- **Application Service / Service Instance:** deployed logical service, often separated by environment, region, or deployment; operational ITSM target.
- **Application CI:** running/installed software on a host, generally discovered; not the enterprise application inventory.
- **Business Service:** consumer/outcome view and operational service CI.
- **Technology Management Service:** provider view of the function used to manage technology.
- **Service Offering:** a variation/tier of a service with scope, availability, support, commitments, or pricing. ServiceNow recommends at least one offering for an operational business or technology management service.
- **Dynamic CI Group:** query-driven collection; use it for governed grouping, not as a substitute for every dependency map. Avoid relating the same CI through multiple groups to conflicting Technology Management Offerings because copied group/ownership data can overwrite.

### 2.5 Naming and semantic standards

Names should be human-readable, stable, and meaningful within the class. Do not use names as the only identifier.

| Entity | Recommended pattern | Avoid |
| --- | --- | --- |
| Business Application | Recognized product/application name | Environment, server, version, department prefix unless part of the actual identity |
| Application Service | `<Business application> - <environment> - <region/variant>` | A generic `Production`, hostnames, or inconsistent abbreviations |
| Business Service | Consumer outcome language, such as `Employee payroll` | Internal platform/team jargon |
| Business Service Offering | `<Service> - <tier/geography/consumer segment>` | Duplicate names with no contextual display fields |
| Technology Management Service | Provider capability, such as `Database management` | A list of individual servers or vendor products |
| Technology Management Offering | `<Technology service> - <support/environment tier>` | Encoding every commitment in the name |
| CMDB Group / Dynamic CI Group | Scope + criterion + purpose | Manual lists named after a temporary project |

Define controlled vocabularies for environment, region, lifecycle, criticality, and service classification. Prefer references/choices over parsing names. Do not add custom status values until lifecycle mappings, product behavior, reports, and migration have been assessed.

### 2.6 Data health and remediation

CMDB Health evaluates:

- **Completeness:** mandatory and recommended attributes are populated.
- **Correctness:** duplicate, orphan, and stale conditions meet class-specific rules.
- **Compliance:** audit/certification expectations are satisfied.
- **Relationship health:** duplicate, orphan, stale, suggested, hosting, containment, and other relationship rules are satisfied.

Configure health per principal class, health group, or critical service. OOTB scheduled jobs may be disabled initially; activate only the metrics and schedules needed, run an initial baseline, and understand aggregation before publishing targets. OOTB has no recommended fields until configured. Compliance requires audits/certificates to be activated. See [Overview of CMDB Health](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/overview-cmdb-health.html) and [CMDB Health KPIs and metrics](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/r_CMDBHealthMetrics.html).

Health operating loop:

1. Scope a principal class/service and define why the metric matters.
2. Baseline the numerator, denominator, exclusions, and oldest failures.
3. Assign a data owner and remediation SLA.
4. Segment failures by class, source, owner, location, lifecycle, and age.
5. Fix the upstream cause: mapping, IRE rule, source value, lifecycle policy, form control, or operating process.
6. Re-run or await the relevant job and confirm the denominator did not change deceptively.
7. Trend the failure count and operational outcome, not only the percentage score.

Rules of thumb:

- A global 98% score can hide a failed Tier-1 service. Report critical services and principal classes separately.
- A mandatory field is a database contract and may block creation; a recommended field is usually better for progressive completeness.
- Do not set every visible field as recommended. Each field must have an owner, trusted source, consumer, and achievable freshness.
- Exclude retired, ephemeral, or source-managed classes through governed rules, not ad hoc dashboard filters.
- Health thresholds must distinguish long-lived hardware, short-lived cloud/container resources, and intentionally logical records.
- Relationship health is as important as attribute health when the outcome is impact analysis.

### 2.7 Duplicates, stale CIs, and lifecycle

**Duplicate response:** stop the source or rule that continues creating duplicates before merging records. Determine the main CI using authoritative evidence, preview the effects on attributes, relationships, assets, and related tasks, then use the supported De-duplication Dashboard/templates or Duplicate CI Remediator. A merge is a data change with business-rule and related-record implications. Australia can use Now Assist to recommend the main CI and merge selections, but a human should review the reasoning before remediation. See [Duplicate CI remediation](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/de-duplication-tasks.html).

**Stale response:** “not recently updated” is not synonymous with “delete.” Classify the CI:

- source failure or credential/range gap -> repair discovery and preserve;
- temporarily offline or seasonal -> retain with appropriate operational state;
- decommissioned but auditable -> retire;
- retired and no longer needed operationally -> archive for defined retention;
- invalid, orphaned, or expired beyond retention -> delete through an approved policy;
- ephemeral cloud/container resource -> use a deliberately shorter class-specific policy.

CMDB Data Manager provides policy-driven bulk **retire, archive, delete, attestation, certification, and related-entry cleanup**. Retire keeps the CI available to views and health; archive removes it from active tables/maps but permits restoration during retention; delete is not restorable through the policy. Active retirement definitions are required for targeted classes in retire/archive/delete policies. Policies can require approval, use exclusions, account for dependent CIs, and create tasks grouped by Managed by Group. Preview exact targets before publishing. See [Working with CMDB Data Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/cmdb-data-management.html) and [Retirement definitions](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/life-cycle-rules.html).

### 2.8 Governance and ownership

Minimum governance roles:

| Role | Accountability |
| --- | --- |
| Executive/service-management sponsor | Funds the product, resolves cross-business ownership, holds outcomes |
| CMDB product owner / Configuration manager | Accountable for roadmap, scope, policy, operating model, and value |
| Class data owner | Approves class definition, identifiers, sources, fields, health, lifecycle, and exceptions |
| Data steward | Monitors quality, investigates tasks, coordinates remediation, and reports trends |
| Source/integration owner | Maintains connection, mapping, source contract, schedule, errors, and source-side fixes |
| Service owner | Owns service outcome, criticality, offering, consumer commitments, and model approval |
| Technology service owner/provider | Owns provider service, groups, technical commitments, and operational dependencies |
| Platform/CMDB administrator | Configures supported controls, roles, jobs, workspaces, and diagnostics |
| Security/data protection | Approves ACL, domain, sensitive fields, retention, and audit controls |

Class ownership is not satisfied by populating `owned_by`. Use a class/source contract reviewed on a fixed cadence. Governance must cover:

- inclusion/exclusion criteria and business purpose;
- OOTB versus approved extension policy;
- identifiers, dependent relationships, and IRE rules;
- authoritative sources by attribute;
- required/recommended fields and acceptable values;
- naming and relationship standards;
- lifecycle states, staleness, retirement, archive, deletion, and exceptions;
- quality thresholds and remediation SLAs;
- ACLs, domain separation, and sensitive data;
- release/change approval for model and integration configuration;
- data consumer register and regression tests.

**Access control:** use the granular CMDB roles and table/field ACLs; do not rely on form hiding or reference qualifiers as security. Separate read, editor, class-owner, deduplication, query-builder, and admin capabilities. Test with real non-admin personas. Australia expanded `sn_cmdb_admin` and `sn_cmdb_editor` access so CMDB work no longer inherently needs broadly elevated roles; validate upgraded role mappings against the Australia release notes. Use domain separation only when it matches a genuine legal/tenant boundary and test health, AI, integration, and reporting behavior per domain.

**Remediation SLAs:** set service levels by criticality, for example duplicate Tier-1 CI within five business days, failed source run within four hours, missing Tier-1 owner within two days, and overdue attestation within ten days. Targets are examples, not defaults; measure age and recurrence.

### 2.9 Maintenance and performance

- Keep the class model shallow and OOTB-aligned; every class adds rules, ACLs, health, lifecycle, forms, reports, and integration mappings.
- Scope health and dashboard collection to principal classes and useful health groups.
- Schedule Discovery, ETL, health, certification, and lifecycle jobs to avoid overlapping resource peaks.
- Use selective/indexed conditions, bounded query depth, and small result sets. Test Query Builder structures and V2 engine support on the target release.
- Monitor `cmdb_ci`, high-volume child tables, `cmdb_rel_ci`, relationship-source data, import staging, IRE errors, duplicate tasks, and archive growth.
- Treat ephemeral cloud-native classes differently from long-lived assets; do not apply one global stale threshold.
- Eliminate redundant feeds and unused custom fields/classes before tuning queries around them.
- Run CMDB quick start tests after family upgrades and Store-app/integration upgrades.
- Use CMDB 360/multisource views to understand which sources updated which attributes; Australia removed the legacy Multisource Report Builder in favor of CMDB 360.

### 2.10 Integration with platform modules

| Module | CMDB/CSDM value | Required discipline |
| --- | --- | --- |
| Incident | Relevant CI/service/offering, assignment context, affected service, outage and subscriber impact | Keep Business Application out of operational CI selection; use principal classes and governed support groups |
| Problem | Trend recurring failures by CI/service, relate root cause and known error to topology | Prevent duplicate CI fragmentation; preserve task links during deduplication |
| Change | Primary/affected CIs, reverse-traversed impacted services, risk and approvals | Relationship direction and service maps must be trustworthy; validate calculated and manual affected CIs |
| Request/Catalog | Service offerings exposed as consumable catalog items, provisioning updates CIs/subscriptions | Separate request catalog representation from the operational service graph; make provisioning idempotent |
| Discovery/Service Mapping/Event Management | Populates runtime topology, service instances, and event impact | Correct credentials, patterns, entry points, service boundaries, and stale behavior |
| ITAM/HAM/SAM | Financial asset and software entitlement context linked to operational CIs and product models | Govern model categories, asset-CI mapping, state sync, normalization, and source authority |
| Enterprise Architecture/SPM | Capabilities, applications, information, portfolios, lifecycle, cost, and technology risk | Maintain logical-vs-runtime separation and prescribed Business Application-to-Service Instance relationships |
| SecOps/IRM/BCM | Vulnerability, control, risk, resilience, and regulatory impact roll up to services/processes | Information sensitivity, criticality, ownership, and dependency coverage must be reliable |
| CSM/FSM/SOM | Customer-facing service, offering, sold product/install base item, and operational CI context | Distinguish customer entitlement/install base from shared technical CIs; verify CSDM version guidance |
| DevOps/Change Velocity | Connect build artifacts and deployments to Business Applications/Service Instances and automate change evidence | Do not use build-domain records as operational incident CIs; preserve traceability across releases |

For Change, ServiceNow can populate impacted services from the primary CI and display affected CIs and service offerings through task-to-CMDB associations; see [Associated CIs on a change request](https://www.servicenow.com/docs/r/it-service-management/change-management/c_AffectedCIsAndImpactedServices.html).

## 3. Practical implementation and operating guide

### 3.1 Step-by-step implementation

#### Step 0: Charter outcomes and constraints

- Select one or two business-critical services and named owners.
- Select two or three consuming workflows and current pain baselines.
- Confirm release, plugins/Store apps, licensing, environments, security boundary, and delivery model.
- Define success in operational terms, not record counts.
- Inventory current CMDB/custom tables, sources, classes, relationships, health, integrations, ACLs, and consumers.

Deliverable: one-page outcome charter and current-state risk summary.

#### Step 1: Establish governance

- Appoint CMDB product owner, class owners, stewards, source owners, and service owners.
- Approve a class/source contract template and exception process.
- Define model-change authority and data-remediation SLAs.
- Define least-privilege roles and non-admin test personas.
- Agree lifecycle and retention with Security/Records/Asset teams.

Deliverable: RACI, governance cadence, policy set, and decision log.

#### Step 2: Build only the necessary Foundation

- Identify authoritative sources for companies, business units, departments, locations, users/groups, models, contracts, and lifecycle values.
- Rationalize duplicate hierarchies and controlled vocabularies before loading CIs.
- Populate and validate the dimensions needed by pilot reports and assignment.
- Create CMDB groups only for a durable monitoring, health, population, or lifecycle purpose.

Deliverable: governed reference data with owners and freshness targets.

#### Step 3: Design the target slice

- Map concepts to OOTB tables and record why each is needed.
- Separate Business Application, Service Instance, Application, Business Service, Technology Management Service, and offerings.
- Draw required references and relationships with direction.
- Define naming, environment, criticality, lifecycle, and ownership conventions.
- Document any custom class/field with alternatives considered and consumers.

Deliverable: conceptual diagram plus physical mapping and data dictionary.

#### Step 4: Configure class controls

- Inspect each class in CI Class Manager.
- Configure/test static identification rules or simulate Dynamic IRE where applicable.
- Define reconciliation and data refresh rules per source and attribute.
- Configure required/recommended fields, orphan/stale rules, suggested/dependent relationships, audits, and retirement definitions.
- Configure ACLs and principal-class scope.

Deliverable: approved configuration specification and automated test cases.

#### Step 5: Implement population pipelines

- Prefer certified connector/Discovery patterns before custom ingestion.
- Configure source, staging, transforms, class mapping, relationships, IRE, schedule, error handling, and lifecycle signal.
- Run a sample/dry test and review every inserted, updated, ignored, incomplete, duplicate, and relationship result.
- Prove idempotency by running the same input again.
- Prove authority by submitting conflicting source values.
- Prove deletion/missing-source behavior with a safe test CI.

Deliverable: source contract, runbook, test evidence, and dashboard/alert ownership.

#### Step 6: Model the pilot service vertically

- Register the Business Application and deployed Service Instance/Application Service.
- Map the runtime dependencies to the necessary infrastructure.
- Add provider-side Technology Management Service/offering when it drives support or change behavior.
- Add Business Service/offering when consumer impact or commitments are required.
- Verify owner, group, lifecycle, criticality, environment, and relationship direction.

Deliverable: one complete service slice that a service owner can explain.

#### Step 7: Validate in consuming workflows

- Incident: CI picker relevance, assignment, affected service, outage/subscriber behavior.
- Change: affected CIs, calculated impacted services, approval and conflict/risk behavior.
- Problem: CI/service aggregation and deduplication survival.
- ITOM: map, events, health, and stale/decommission behavior.
- ITAM: asset linkage, model, state sync, and lifecycle.
- Reporting/AI: Query Builder, PA/dashboard results, and natural-language query accuracy where licensed.

Test intended and unauthorized personas, negative cases, scale, and upgrade-sensitive behavior.

Deliverable: acceptance evidence tied to business outcomes.

#### Step 8: Activate health and lifecycle operations

- Baseline CSDM/CMDB Data Foundations and CMDB Health for the pilot scope.
- Tune jobs, rules, thresholds, and exclusions.
- Create remediation queues and owner SLAs.
- Publish attestation/retirement/archive/delete policies only after preview and approval.
- Establish weekly operational and monthly governance reviews.

Deliverable: health scorecard, backlog, lifecycle policies, and escalation path.

#### Step 9: Scale by repeatable waves

- Convert pilot decisions into reusable class/source/service templates.
- Prioritize the next services by criticality, workflow benefit, source readiness, and owner readiness.
- Onboard sources/classes only when governance and consumers are ready.
- Track technical-debt removal and retire legacy sources/tables deliberately.
- Reassess scope after every release and Store-app upgrade.

Deliverable: wave roadmap and quantified value realization.

### 3.2 Day-to-day tool routing

| Need | Preferred tool/surface | Use and caution |
| --- | --- | --- |
| Central CMDB work | Service Graph Workspace (Australia direction) or CMDB Workspace | Search/explore, health, governance, dedup, Data Manager, CMDB 360, recent activity; feature availability depends on Store version and role |
| Class/schema/rules | CI Class Manager | Class hierarchy, fields, IRE, health, dependent/suggested relationships, Service Mapping definitions; inspect before extending |
| Relationship visualization/editing | Unified Map | Current graphical editor; minimize levels/filter before editing; saving can delete relationship records even though CI records remain |
| Legacy relationship editing | CI Relationship Editor | Useful from CI form; use suggested relationships; Unified Map is the newer alternative |
| Graph analysis | CMDB Query Builder | Query classes, non-CMDB tables, references, and relationships; save bounded queries and test execution-mode limitations |
| Service topology | Unified Map, Service Mapping maps, Dependency Views | Choose by purpose: governed relationship edit, operational service map, or impact exploration |
| Multisource evidence | CMDB 360 | Compare source contributions and attribute provenance; preferred over the removed Multisource Report Builder in Australia |
| Integration | SGC Central, IntegrationHub ETL, CMDB Integrations Dashboard | Configure connectors/ETL, inspect runs and errors, verify RTE/IRE output; guided setup for some older connectors is being deprecated in favor of SGC Central |
| Data quality | CMDB Health, Relationship Health, CSDM/CMDB Data Foundations, CMDB Success Advisor | Use outcome/principal-class scope; confirm collector jobs and denominators |
| Duplicates | De-duplication Dashboard/templates; Duplicate CI Remediator | Fix root cause first; preview related records; use Now Assist recommendations only with review |
| Lifecycle/attestation | CMDB Data Manager | Preview, exclusions, approval, retirement definitions, dependent CI behavior, task ownership, retention |
| Service/application architecture | Enterprise Architecture Workspace and CSDM views | Logical portfolio and cross-domain modeling; do not confuse diagrams with committed CMDB records |

Australia positions [Service Graph Workspace governance](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/sg-workspace-governance-view.html) as the consolidated route to these tools. The classic CI Relationship Editor remains supported, while [Unified Map](https://www.servicenow.com/docs/r/servicenow-platform/unified-map/unified-map-editing-map.html) provides the current map-editing experience.

### 3.3 Common challenges and solutions

| Symptom | Likely causes | Correct response |
| --- | --- | --- |
| Duplicate servers after adding a connector | Direct/coalesced writes, weak identifiers, source key mismatch, missing dependent relation, inconsistent serial normalization | Stop new inserts; compare payloads; correct class/identifier/transform; re-test IRE; then remediate duplicate tasks |
| A trusted value keeps being overwritten | Missing/wrong reconciliation definition, discovery-source reuse, source ordering assumption | Define authority at class/attribute level; simulate conflict; verify IRE decision and CMDB 360 provenance |
| High completeness but poor incident routing | Metrics cover easy fields, support groups lack owners, CI selector contains irrelevant classes | Designate principal classes; make actionable fields recommended/required; improve source/process; measure correct assignment |
| Business Applications selected on incidents | Legacy form/reference qualifier or concept confusion | Filter operational CI classes; select Application Service/Service Instance; retain Business Application for portfolio/design |
| Manual service map decays | No source, owner, attestation, or change trigger | Prefer Service Mapping/tag/query population; otherwise assign owner and recurring attestation, and include map updates in change acceptance |
| “Stale” cloud CIs grow rapidly | Global threshold, missing deletion signal, ephemeral source behavior | Class-specific freshness and lifecycle; connector tombstone/deletion design; short approved retire/archive policy |
| Relationship explosion and slow queries | Modeling every observation, duplicated edges, deep generic relations | Tie edges to use cases; use standard patterns; remove root cause; limit traversal depth and query scope |
| Custom class breaks product features | Wrong inheritance, no identifiers, unsupported assumptions, product filters only OOTB classes | Re-evaluate OOTB class; document consumers; add full class controls; regression-test product and upgrade behavior |
| Conflicting technical-service group data | A CI is included through multiple Dynamic CI Groups tied to different offerings | Enforce one governing Technology Management Offering per CI through these groups; redesign overlapping criteria |
| Health dashboard is empty or misleading | Jobs disabled/not run, compliance not activated, wrong scope/exclusions, stale aggregation | Configure and run collectors; validate sample CI outcome; document denominator and refresh time |
| Lifecycle policy sends tasks to admin | `Managed by Group` missing or policy ownership not designed | Fix ownership coverage before publish; preview assignment; add exception steward and SLA |
| CSDM program stalls in workshops | Trying to model the whole enterprise, no workflow consumer, owner gaps | Return to one service, one outcome, one source contract, and an eight-to-twelve-week vertical slice |
| AI search/agent returns confident wrong context | Duplicate/missing records, bad relationships, overly broad roles, semantic ambiguity | Fix data contract and ACLs; restrict scope/actions; test with evaluation datasets; require approval for consequential writes |

### 3.4 Success metrics and KPIs

Use a balanced scorecard. Every percentage must declare scope, population, exclusions, freshness, and source.

| Dimension | Metric / formula | Why it matters |
| --- | --- | --- |
| Coverage | In-scope authoritative components represented / known in-scope components | Detects missing coverage without incentivizing universal population |
| Ingestion integrity | CI creates/updates processed by IRE / all automated CI creates/updates | Finds bypass paths |
| Duplicate rate | Duplicate CIs / evaluated independent CIs | Identity health; segment by class/source |
| Stale rate | CIs failing class-specific freshness / active in-scope CIs | Pipeline/lifecycle health |
| Required completeness | CIs with all required fields / evaluated CIs | Minimum usable contract |
| Owner coverage | Active principal CIs/services with accountable owner/group / active scope | Makes remediation and routing possible |
| Relationship conformance | CIs/services with required standard relationships / evaluated scope | Predicts impact/reporting reliability |
| Service coverage | Critical services with validated owner, offering, service instance, and map / critical services in scope | Measures useful vertical slices |
| Source freshness | Successful runs within source SLA / scheduled runs | Detects silent decay |
| Error escape | Unresolved integration/IRE errors older than SLA | Shows operational control |
| Remediation flow | Median/95th percentile age and recurrence of health/dedup tasks | Measures whether governance closes problems |
| ITSM adoption | Incidents/changes with valid CI and service context / eligible tasks | Measures process use, not just data presence |
| Assignment outcome | Correct first assignment and reassignment rate by CI/service | Connects ownership quality to user value |
| Change outcome | Changes with validated affected CIs and calculated services; change failure by model quality | Connects topology to risk reduction |
| Operational value | MTTR, impact-assessment time, outage scope accuracy, audit effort | Demonstrates business value |
| Technical debt | Custom classes/fields/relationships with active consumers versus total | Creates a rationalization backlog |

Illustrative Tier-1 targets might be 100% accountable service ownership, >=98% required-field completeness, <0.5% duplicate rate, <2% stale rate, >=95% required-relationship conformance, and remediation within five business days. Do not copy these blindly; baseline first and set tighter/looser thresholds based on volatility, source capability, risk, and consequence.

### 3.5 Role-specific working tips

**Administrator**

- Confirm release, Store-app versions, scope, role, and current configuration before changing rules.
- Use CI Class Manager rather than scattered dictionary/rule edits.
- Keep writes IRE-aware; test ACLs as editor/user personas.
- Avoid global properties and scheduled-job changes until scope and performance are understood.
- Re-run quick start and pilot regression tests after upgrades.

**Configuration manager / CMDB product owner**

- Maintain outcome roadmap, principal-class scope, RACI, data contracts, exceptions, and health backlog.
- Chair source/class decisions with service and integration owners; do not accept “the CMDB team owns all data.”
- Publish trends and operational outcomes, not a single global health score.
- Treat custom-model and direct-write requests as architecture decisions.

**Service owner**

- Define consumer outcome, criticality, owner, offering/commitments, subscribers, and service boundary.
- Validate the production Service Instance and its dependency map regularly.
- Use outage/change/incident evidence to correct the model.
- Do not delegate semantic ownership entirely to Discovery or platform teams.

**Developer / integration engineer**

- Resolve tables/classes live and use stable source keys; never hard-code portable sys_ids.
- Use SGC/IH-ETL/IRE APIs and return actionable errors; make retries idempotent.
- Query narrow indexed fields; do not scan `cmdb_ci` or traverse unbounded graphs in transactions.
- Respect ACL/application access and use supported APIs; write automated insert/update/conflict/duplicate tests.
- Do not update `sys_class_name` or bulk reclassify CIs casually.

**Data steward / analyst**

- Work from oldest/highest-risk exceptions and group failures by root cause.
- Verify a sample against the source and consuming workflow before bulk remediation.
- Record why an exception is valid and when it expires.
- Use Query Builder/CMDB 360 and source evidence rather than guessing from a CI form.

## 4. Advanced and 2026 topics

### 4.1 CSDM 5 changes that matter

CSDM 5, published in 2025 and reflected across Yokohama/Australia-era products, is an incremental expansion rather than a replacement for CSDM 4. Major themes include:

- a new **Ideation & Strategy** domain and a portfolio-centric end-to-end lifecycle;
- expanded Value Stream and Business Process guidance;
- System Component, Software Component, Service Offering, AI, and other product-model concepts;
- Product Feature, Teams/multiple CI contact groups, and more explicit lifecycle stages/statuses;
- Software Bill of Materials (SBOM) alignment;
- DevOps Change data model availability through Store content;
- relabeling **Technical Service** to **Technology Management Service**, Technical Service Offering accordingly, and `cmdb_ci_service_auto` to **Service Instance**;
- Service Instance expansion beyond Application Service to Data/AI, Connection, Network, Facility, and Operational Process service instances;
- AI digital assets in Build & Integration and deployed AI Function/Application concepts in Service Delivery.

Key cautions:

- CSDM 5 guidance is not synonymous with every table being installed or product-ready.
- The white paper identified several new Service Instance extensions as data-model-only at introduction, without a dedicated UI and outside initial Event Impact Analysis.
- Some entities arrive via free Store model apps, licensed product plugins, or later Store versions.
- Labels can change while table names remain for compatibility; design against definitions/table names, not screenshots.
- Official product-specific “CSDM shapes” or workspace categories can lag or group shapes differently; use the CSDM 5 white paper plus the consuming product's current documentation and live schema.

### 4.2 AI-related configuration and digital assets

CSDM 5 separates design/build governance from runtime operation:

- **AI System Digital Asset** and related AI Model, Dataset, and Prompt digital assets describe governed build/integration artifacts.
- **AI Function** (`cmdb_ci_function_ai` in the white paper) represents cloud/SaaS AI functions.
- **AI Application** (`cmdb_ci_appl_ai_application`) represents deployable AI software running on supported platforms and extends Application.
- **Data Service Instance** can represent a deployed service boundary for data, model, training, inference, storage, or AI/ML services.
- Product models describe reusable catalog/specification concepts separately from deployed CIs.

Model only what supports a control or workflow. A useful AI service slice might relate an AI system/product model and governed digital assets to the Business Application/SDLC design, then represent the deployed AI Application/Function under a Data Service Instance that supports a business offering. Capture owner, provider, model/version, data sensitivity, region, lifecycle, controls, and upstream/downstream dependencies only where the installed schema and governance product support them.

Do not force third-party AI SaaS, internal models, prompts, datasets, agents, tools, and GPUs into one generic custom class. Verify the current AI Control Tower/Enterprise Architecture/CMDB model and decide which are assets, CIs, model records, or external catalog records.

### 4.3 Agentic IT implications

Australia-era Now Assist for CMDB can support natural-language graph searches (including relationships), CI/class explanations, governance guidance, IRE-aware CI creation, connector troubleshooting, and duplicate-resolution recommendations. The platform still requires human governance. The [Australia Now Assist for CMDB release notes](https://www.servicenow.com/docs/r/release-notes/now-assist-cmdb-rn.html) describe natural-language relationship searches, Dynamic IRE comparison, and deduplication assistance.

Agentic controls:

- Limit agents to the same ACL/domain/role boundaries as the requesting persona; inspect role masking.
- Separate read/search agents from create/update/remediate agents.
- Route CI creation through IRE and require mandatory identity attributes.
- Require preview and human approval for deduplication, reclassification, lifecycle, relationship deletion, and broad writes.
- Evaluate agents with known-good/known-bad cases: duplicate names, missing owner, ambiguous environment, cross-domain data, stale relationships, and unauthorized requests.
- Log proposed action, evidence, tool result, final change, and rollback reference.
- Measure false merges, incorrect CI selection, wrong impacted service, and unauthorized-data exposure, not just response quality.
- Treat model output as a recommendation unless the action has bounded scope, deterministic validation, and safe rollback.

The stronger the autonomy, the higher the required CMDB health, semantic clarity, access control, source provenance, and evaluation coverage.

### 4.4 Workflow Data Fabric alignment

Workflow Data Fabric (WDF) connects and governs enterprise data where it lives and makes it reusable by workflows, analytics, and AI. CMDB/CSDM and WDF complement rather than replace each other:

| CMDB/CSDM | Workflow Data Fabric |
| --- | --- |
| Operational/service graph and standard service semantics | Governed access to broader enterprise/external data through connections, data interfaces/products, contracts, catalog, lineage, and zero-copy options |
| Identity, source authority, lifecycle, and topology of CIs/services | Discoverability, access, trust, and reusable contracts for external/business data |
| Optimized for operational workflows, impact, service health, configuration control | Optimized for connecting/contextualizing data across systems for workflows, analytics, and agents |

Use WDF to add governed context such as customer, finance, shipment, supplier, or telemetry data without indiscriminately copying it into CMDB. Ingest an external object as a CI only when it meets CI criteria, belongs in the CSDM/CMDB schema, needs configuration control, and can follow IRE/lifecycle governance. A zero-copy data-fabric table is not automatically an authoritative CMDB source.

For AI, WDF supplies governed external context while CSDM supplies consistent service and operational meaning. Define join keys/data contracts deliberately and enforce ACL/lineage on both sides. See [Workflow Data Fabric Home](https://www.servicenow.com/docs/r/integrate-applications/exploring-workflow-data-fabric.html) and [key terms](https://www.servicenow.com/docs/r/integrate-applications/workflow-data-fabric/key-terms-wdf.html).

### 4.5 Migrating a legacy CMDB to CSDM

Treat migration as a product and dependency transformation, not a bulk copy.

1. **Back up and baseline.** Export required attributes/relationships and retain a restorable snapshot appropriate to the environment. Record counts, consumers, health, and business baselines.
2. **Map concepts and attributes.** Map each legacy table/class to an OOTB target. Classify custom attributes as OOTB/refactor, retain with justified use, or retire. Identify data-type, choice, reference, and lifecycle transformations.
3. **Inventory dependencies.** Find reports, PA indicators, business rules, scripts, flows, integrations, ACLs, reference qualifiers, forms, notifications, imports, APIs, table cleanup rules, and external consumers tied to the old table. This is usually the largest risk.
4. **Refactor the target and consumers.** Configure approved fields/rules/ACLs, update code/reports/integrations, and add regression tests before data movement.
5. **Migrate a small representative batch.** Use a supported reclassification/migration approach. A class change can preserve the CI identity and related tasks when tables share a hierarchy, but custom fields outside the target hierarchy can lose values. Never bulk-change `sys_class_name` without a tested, supported plan and rollback.
6. **Re-point population at the target.** Establish IRE and reconciliation first, prevent the old source path from recreating legacy records, and prove idempotency.
7. **Reconcile and validate.** Compare attributes, relationships, tasks, assets, service maps, health, reports, ACLs, integrations, and performance. Validate with service owners and non-admin personas.
8. **Cut over by wave.** Freeze the legacy write path, migrate bounded batches, monitor, and maintain a controlled rollback window.
9. **Retire legacy structures.** Remove or archive old sources/tables only after consumer telemetry, retention, audit, and rollback requirements are satisfied.

The CSDM 5 white paper describes five core steps—backup, attribute mapping, dependency analysis, attribute refactoring, and data migration—and warns that moving the CI does not automatically refactor its reports/rules/scripts. Use that as the minimum, then add source cutover, security, and operational verification.

### 4.6 Reporting, analytics, and business value

CSDM itself does not supply a universal report pack. Its value is that product reports, CMDB Query Builder, Performance Analytics, workspaces, and AI can find consistent data. Start with business questions:

- Which services and consumer groups are affected by this CI or change?
- Which critical services lack a validated map, owner, or offering?
- Which technologies approaching end of support enable regulated capabilities?
- Which source creates most duplicates or stale CIs?
- Which service has high incident volume but low topology/ownership quality?
- Which business outcomes or offerings rely on a vulnerable component?
- Which lifecycle/attestation tasks are overdue and what risk do they represent?

Use Query Builder for bounded graph queries, PA for trends and targets, CMDB Health/Data Foundations for quality, service/workspace analytics for process outcomes, and CMDB 360 for source provenance. Avoid one giant data warehouse-style report over `cmdb_ci`; create purpose-built data sets with declared graph depth and refresh.

Value-realization chain:

```text
Governed sources + IRE
        -> trustworthy CIs and relationships
        -> reliable service/consumer context
        -> better routing, impact, automation, risk and AI decisions
        -> less downtime, rework, audit effort, and technical debt
```

Report leading indicators (coverage, health, source errors, ownership, relationship conformance) alongside lagging outcomes (MTTR, reassignment, change failure, outage impact time, audit effort, and rationalization savings). Correlation is not causation; use pilot baselines and compare before/after cohorts where possible.

## 5. Checklists

### Governance checklist

- [ ] Named CMDB product owner and executive sponsor
- [ ] Owner and steward for every principal class
- [ ] Owner for every in-scope service and source
- [ ] Class/source contracts approved and reviewed on cadence
- [ ] OOTB-first extension policy and exception register
- [ ] Standard definitions, naming, choices, references, and relationships
- [ ] Identification, reconciliation, and refresh authority documented
- [ ] Lifecycle/retention, retirement definitions, and exception policy
- [ ] Least-privilege ACL/role model tested with non-admin personas
- [ ] Quality thresholds and remediation SLAs by criticality
- [ ] Model/integration change control and regression suite
- [ ] Consumer register for ITSM, ITOM, ITAM, EA/SPM, SecOps/IRM, CSM, analytics, and AI
- [ ] Monthly value/risk review and quarterly scope rationalization

### Implementation checklist

- [ ] Business outcome, baseline, and acceptance criteria agreed
- [ ] One or two pilot services selected with ready owners
- [ ] Release, Store apps, plugins, licensing, and security confirmed
- [ ] Current classes, customizations, sources, and dependencies inventoried
- [ ] Foundation data sources and hierarchies governed
- [ ] Conceptual-to-physical mapping approved
- [ ] Principal classes and service boundaries defined
- [ ] IRE insert/update/conflict/duplicate/dependent tests passed
- [ ] Source pipeline tested with sample, rerun, error, and missing-source cases
- [ ] Standard relationships and direction validated in map/query
- [ ] Incident/change/problem/asset/service behavior tested end to end
- [ ] Health rules/jobs baselined and tuned
- [ ] Data Manager policies previewed with ownership and approvals
- [ ] Non-admin, negative, performance, and upgrade regression tests passed
- [ ] Runbook, rollback, dashboards, and operational ownership handed over

### Health monitoring checklist

- [ ] Collector jobs enabled only for intended scope and scheduled appropriately
- [ ] Numerator, denominator, exclusions, and refresh time understood
- [ ] Completeness fields have real owners/sources/consumers
- [ ] Duplicate rate reviewed by class and source
- [ ] Staleness thresholds vary by lifecycle and volatility
- [ ] Orphan rules reflect required relationships, not arbitrary connectivity
- [ ] Relationship health and service view monitored where impact matters
- [ ] Compliance audits/certificates are active where reported
- [ ] Integration/IRE errors and source freshness monitored alongside health scores
- [ ] Remediation tasks have owner, SLA, age, escalation, and recurrence tracking
- [ ] Root-cause fixes verified after next health cycle
- [ ] Tier-1 services/classes reported separately from global score

### Common-pitfall prevention checklist

- [ ] No direct automated inserts/updates bypass IRE
- [ ] No Business Application used as an operational CI target
- [ ] No generic `cmdb_ci` import when a specific class exists
- [ ] No custom class/relationship/status without approved consumer and lifecycle
- [ ] No duplicate source authority left implicit
- [ ] No global stale/delete policy across unlike classes
- [ ] No unowned manual service maps
- [ ] No duplicate semantic relationships or reversed CSDM direction
- [ ] No mass dedup/delete/reclassification without preview, backup, and rollback
- [ ] No health target based solely on a global aggregate
- [ ] No CSDM stage implemented solely because a diagram contains it
- [ ] No AI write/remediation action without ACL, IRE, evaluation, and human-control design

## 6. Synthesized real-world patterns

These are composite examples, not claims about named customers.

### Case A: Global retailer with duplicate infrastructure

**Problem:** Discovery, SCCM, and a custom cloud import all created server CIs. Serial values were formatted differently, cloud VMs used inconsistent classes, and each source overwrote support group.

**Approach:** The team limited scope to production server principal classes, adopted the certified SCCM/cloud connectors, normalized identifiers in IntegrationHub ETL, assigned one discovery source per feed, designed field-level reconciliation, and ran Dynamic IRE simulation for hardware descendants. After the new-insert rate stabilized, they remediated duplicates using class templates and validated incidents/assets/relationships before merge.

**Value:** Duplicate recurrence became the primary KPI, not the one-time number removed. Assignment accuracy and asset/CI match rate improved because support and model authority were explicit.

### Case B: Bank migrating a custom application registry

**Problem:** A custom CI class mixed logical applications, environments, installed software, services, owners, and SLAs. Incident and Change referenced it everywhere, while EA expected Business Application and application-service relationships.

**Approach:** Records were classified into Business Applications, Application Services, discovered Applications, Business Services, and offerings. The team mapped fields, scanned table dependencies, refactored reports/ACLs/integrations, and migrated one application family at a time. Operational task selection moved to Application Service; legacy task references were regression-tested. The old source was re-pointed through IRE before each wave.

**Value:** The bank enabled application rationalization and change-impact reporting without maintaining a custom translation layer. The largest effort was consumer refactoring, not record movement.

### Case C: Manufacturer introducing OT and facility service context

**Problem:** Plant teams wanted to represent production lines, facilities, control systems, and shared network services. The early design proposed thousands of custom service CIs and every sensor relationship.

**Approach:** The MVP modeled one critical production process outcome, the relevant Business Service/offering, an operational service boundary, and only dependencies needed for outage/risk decisions. OOTB OT class models were evaluated before extensions. CSDM 5 Facility/Operational Process/Network Service Instance concepts were used as future-state guidance but not assumed present; plugin, UI, impact, and lifecycle support were verified before adoption.

**Value:** The graph stayed operationally useful and avoided a high-maintenance digital twin that CMDB consumers did not need.

### Case D: Enterprise AI service governance

**Problem:** Teams registered model endpoints, prompts, GPUs, vendors, and agents in a generic “AI CI” table. Risk, operations, and architecture used different definitions.

**Approach:** The enterprise separated product models and AI digital assets (design/build governance) from deployed AI Applications/Functions (runtime) and a Data Service Instance (operational service boundary). Business Application, Information Object, provider, region, sensitive datasets, and business offering were connected only through supported CSDM references/relationships. WDF exposed external model/provider and usage data through governed data products rather than copying everything into CMDB.

**Value:** AI agents and risk workflows received consistent service context while runtime identity, source, lifecycle, and access remained controlled.

## 7. Actionable templates

### 7.1 CMDB/CSDM scoping worksheet

| Field | Entry |
| --- | --- |
| Business outcome / decision | What will become faster, safer, or more accurate? |
| Baseline and target | Current time/error/risk and expected change |
| Executive sponsor | Name/role |
| Service owner | Name/group |
| Pilot service/offering | Consumer-facing name and scope |
| Consuming workflows | Incident, Change, Problem, Event, HAM, EA, IRM, AI, etc. |
| Principal CI classes | Minimum classes required |
| Required relationships | Parent, type, child, direction, consumer |
| Foundation dimensions | Company, location, group, model, department, contract, etc. |
| Authoritative sources | Source per class/attribute |
| Identification | Independent/dependent keys and priority |
| Reconciliation | Source authority by contested attribute |
| Freshness | Source schedule and stale threshold by class |
| Lifecycle | Create, update, missing-source, retire, archive, delete, retention |
| Health | Required/recommended fields, duplicate/orphan/stale/compliance rules |
| Security | Read/write personas, sensitive fields, domain boundary |
| Acceptance tests | Insert/update/conflict/duplicate, map, workflow, ACL, scale, rollback |
| Exclusions | Explicitly out of scope |

### 7.2 Class and source contract

```text
Class / table:
Business purpose and consumers:
Accountable owner / working steward:
Inclusion and exclusion criteria:
Expected volume and volatility:

Identity
- Independent or dependent:
- Identifier entries and priority:
- Hosting/containment dependency:
- Source-native key/correlation field:

Attribute authority
- Source A: fields, schedule, freshness, insertion rights
- Source B: fields, schedule, freshness, insertion rights
- Manual: allowed fields, role, approval, review date

Relationships
- Parent class | relationship | child class | source | consumer

Quality and lifecycle
- Required/recommended fields:
- Duplicate/orphan/stale/compliance thresholds:
- Missing-source behavior:
- Retirement definition:
- Archive/delete retention and approvals:
- Remediation SLA and escalation:

Security and validation
- Roles/ACL/domain:
- Positive, negative, conflict, scale, and regression tests:
- Last approval / next review:
```

### 7.3 Relationship decision record

```text
Business question supported:
From (parent) class:
Relationship/reference and direction:
To (child) class:
Why a CMDB relationship versus a reference/m2m:
Population source:
Freshness/deletion rule:
Consuming product/report/workflow:
Owner and attestation cadence:
Alternative considered:
```

### 7.4 Illustrative lifecycle policies

**Stale server retirement**

- Scope: production server principal classes, operational/installed, last successful discovery older than the approved threshold.
- Prerequisites: source health confirmed, class retirement definition active, owner/Managed by Group populated.
- Action: Data Manager Retire policy with approval by the managed group.
- Exclusions: legal hold, disaster-recovery standby, seasonal systems, active change/decommission project.
- Validation: preview count/sample, dependent CIs, assets, tasks, service impact, and source recurrence.
- SLA: owner decision within agreed days; unresolved tasks escalate to class steward.

**Archive retired infrastructure**

- Scope: CI already satisfying its class retirement definition for the retention period.
- Action: Archive policy with approval and defined archive retention.
- Controls: relationship/dependent-CI review, security/records approval, restoration test in non-production.

**Quarterly Business Application attestation**

- Scope: active business applications supporting critical capabilities.
- Attest: owner, lifecycle, criticality, information sensitivity, production service instances, and support contacts.
- Evidence: task completion rate, corrections made, overdue age, recurring failure reason.

**Duplicate remediation policy**

- Scope: duplicate tasks for a specific class/source pattern after root cause is fixed.
- Main-CI rules: authoritative source, active asset/reference, oldest valid identity only where justified.
- Merge: explicit attribute, relationship, and related-item behavior; preview required.
- Approval: class owner for batch/template changes; human review for AI recommendations.

These examples are starting points. Never publish a broad lifecycle or deduplication policy without exact target counts, samples, exclusions, approval, downstream analysis, and rollback/recovery planning.

### 7.5 Naming policy example

```text
1. Names are stable display values, not database identifiers.
2. Use approved full names and controlled abbreviations.
3. Business Applications do not include environment or runtime version.
4. Application Services use: <Business Application> - <Environment> - <Region/Variant>.
5. Business Services use consumer outcome language.
6. Offerings add only the dimension that changes commitment, scope, or entitlement.
7. Environment, region, tier, criticality, and lifecycle are stored in governed fields.
8. Duplicate display names require a contextual display strategy and owner approval.
9. Renames preserve identity and must be assessed against integrations/reports.
```

## 8. Recommended official resources

1. [CSDM 5 white paper (official ServiceNow Community post)](https://www.servicenow.com/community/common-service-data-model/csdm-5-finally-get-the-csdm-5-white-paper-here/ta-p/3254967) — canonical 2025 model, definitions, relationships, maturity, and migration guidance.
2. [Common Service Data Model documentation](https://www.servicenow.com/docs/r/servicenow-platform/common-service-data-model-csdm/csdm-landing-page.html) — release-specific configuration, implementation stages, lifecycle, tables, and product use.
3. [Configuration Management Database documentation](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_ITILConfigurationManagement.html) — current feature map.
4. [Australia CMDB release notes](https://www.servicenow.com/docs/r/release-notes/cmdb-rn.html) — Success Advisor, Service Graph Workspace, Dynamic IRE, granular roles, Query Builder, and upgrade notes.
5. [Identification and Reconciliation Engine](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ire.html) — identification, reconciliation, APIs, and troubleshooting.
6. [IntegrationHub ETL](https://www.servicenow.com/docs/r/servicenow-platform/integration-hub-etl/integrationhub-etl.html) and [Service Graph Connectors](https://www.servicenow.com/docs/r/servicenow-platform/service-graph-connectors/cmdb-sgc-available.html) — supported ingestion patterns.
7. [CMDB Health](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/overview-cmdb-health.html), [CSDM Data Foundations](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/csdm-data-foundations-dashboard.html), and [CMDB Success Advisor](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/cmdb-sa.html) — quality and outcome monitoring.
8. [CMDB Data Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/cmdb-data-management.html) — policy-based attestation and lifecycle operations.
9. [Service Graph Workspace](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/sg-workspace.html), [CI Class Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ci-class-manager-landing-page.html), and [CMDB Query Builder](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/use-cmdb-query-builder.html) — daily operating tools.
10. [Now Assist for CMDB](https://www.servicenow.com/docs/r/servicenow-platform/now-assist-for-configuration-management-database-cmdb/now-assist-landing-cmdb.html) and [Workflow Data Fabric](https://www.servicenow.com/docs/r/integrate-applications/create-integrations-applications.html) — 2026 AI and enterprise-data context.
11. [ServiceNow CMDB design guidance](https://www.servicenow.com/content/dam/servicenow-assets/public/en-us/doc-type/resource-center/white-paper/wp-cmdb-design-guidance.pdf) — implementation design principles.
12. ServiceNow University CSDM/CMDB training, Now Create implementation assets, the official CSDM/CMDB Community product hubs, and product-specific CSDM views — use as complements and match content to the target release.

## 9. PDI observation and verification rule

Read-only inspection on **2026-07-20** found Simen's PDI on **Australia Patch 1**. Core physical tables included `cmdb_ci`, `cmdb_rel_ci`, Business Application, Service Instance, Business Service, Technology Management Service, Offering, CMDB Group, IRE identifier/reconciliation tables, and duplicate tasks. Several CSDM 5 model entities—including the new Data/Connection/Network/Facility/Operational Process Service Instance siblings, AI Function/Application, SDLC Component, and some SPM/value-stream records—were not installed in that PDI.

This is intentionally a dated observation, not a portable schema assumption. Before CMDB/CSDM work, re-run release/table/plugin inspection and treat missing tables as a Store app/plugin/licensing question—not permission to create custom replacements.

## 10. Targeted follow-up prompts

1. “Design a CSDM 5 MVP for our `<service/application>`: give me the exact records, tables, relationships, owners, sources, and acceptance tests.”
2. “Diagnose duplicate `<CI class>` records from Discovery and `<connector/source>`; inspect our IRE identifiers, reconciliation rules, payloads, and propose a safe remediation plan.”
3. “Create a CMDB governance operating model and RACI for our organization, including class/source contracts, remediation SLAs, and a monthly scorecard.”
4. “Assess our legacy application/service model for migration to CSDM 5; inventory dependencies and produce a wave plan with rollback and validation.”
5. “Build a 2026 AI-service modeling pattern using CSDM 5, AI Control Tower/Enterprise Architecture, CMDB, and Workflow Data Fabric, clearly separating conceptual and installed physical objects.”
