# Vaar Energi Compendia Deployment and Full Sync Runbook

Use this runbook for Compendia promotion, full synchronization, reconciliation, or production recovery. Load safety-checklists.md first for production, update-set, integration, or bulk-data work.

## Why Full Syncs Take Time

A full run is more than creating knowledge articles. It must safely deploy metadata, validate the physical staging table, configure target-only secrets and properties, fetch four handbooks without exceeding Compendia rate limits, download attachments, avoid overlapping scheduler transactions, and reconcile the final state. Browser or Xplore timeouts do not prove that server-side work stopped.

## Preflight

1. Confirm the exact instance URL and authenticated user. Treat PROD as read-only until the requested production writes are explicitly authorized.
2. Record the expected source counts for each configured handbook from the Compendia list endpoints.
3. Inspect the update-set batch before promotion. Require one current Script Include and exclude secrets, environment-specific values, repair scripts, temporary runners, and unrelated form/layout noise.
4. Preview before commit and resolve conflicts from the proposed remote payload. Avoid reconstructing part of the package through Table API before committing the real remote update set.
5. Validate u_compendia_import_staging at all three layers: metadata exists, gs.tableExists()/GlideRecord recognizes it, and Table API can read it. If metadata exists but runtime access fails, inspect storage aliases and the generated sys_id dictionary row before changing integration code.

## Target-Only Configuration

Set secrets from the approved target credential source after update-set commit; never transport or report their values. Verify these non-secret controls:

- varenergi.compendia.sync.enabled: keep false until the smoke test is ready, then set true for live synchronization.
- varenergi.compendia.sync.auto_publish: false keeps synchronized articles in draft; true publishes them.
- varenergi.compendia.sync.max_per_run: use 100 for the current four-handbook implementation. A lower value can let recurring content-health work consume the run before later handbooks are reached.
- varenergi.compendia.author_user: resolve the dedicated Compendia user in the target and verify its Knowledge Admin role.
- Confirm the Compendia knowledge base, user criteria, scheduled job, and display_attachments behavior.

Do not edit the dryRun expression inside syncAll(limit, dryRun). Calling syncAll() performs a live run; only an explicit Boolean true argument enables dry-run behavior.

## Smoke Test

1. Fetch one known page and its detail payload from ServiceNow's outbound runtime.
2. Process one article into staging and kb_knowledge.
3. Verify the handbook-aware external key, category, article body, author, workflow state, source metadata, and target reference on the staging row.
4. For an article with files, verify attachment download, body links to sys_attachment, and display_attachments=true in Employee Center.
5. Inspect sanitized outbound HTTP logs and the staging error field.

## Full Sync

1. Capture a read-only baseline with Get-ServiceNowCompendiaSyncStatus.ps1.
2. Set sync.enabled=true only after the smoke test passes.
3. Use the existing scheduled job as the controlled runner. Do not create temporary job records or start a second run while a sys_trigger/scheduler transaction is claimed.
4. Run batches sequentially. Wait for each trigger to finish, then reconcile counts before deciding whether another batch is required.
5. Allow a cooldown between immediate batches. Treat HTTP 429 as transient and leave an existing target article for the next scheduled retry rather than looping aggressively.
6. Add a file ID to a skip property only after repeated source-side failure is proven and no valid cross-handbook or alias-matched alternative exists. Preserve a clear staging/log error for skipped source files.
7. Stop when every expected source page has a staging row and target article, and the remaining errors are either zero or understood source-side exceptions with existing targets.

## One-Command Reconciliation

Run from the skill directory:

    & .\scripts\Get-ServiceNowCompendiaSyncStatus.ps1 -Instance 'https://<target-instance>.service-now.com' -Profile other -EnvPath '<approved-env-path>'

The helper is read-only. It reports:

- article total, workflow states, author mismatches, and display_attachments exceptions;
- staging totals by handbook/state plus row-level errors;
- attachment totals, covered articles, and content types;
- non-secret runtime properties;
- scheduled-job mode and trigger state;
- reconciliation warnings.

## Handoff

1. Restore the scheduled job to active daily mode and its approved local run time. Verify a waiting daily trigger and next action.
2. Re-run the reconciliation helper without cache.
3. Report expected/source count, article count, staging processed/error counts, handbook breakdown, attachment count, workflow state, author, auto-publish setting, next scheduled run, and known source-side exceptions.
4. Do not claim that update-set backout removes synchronized articles or attachments. Runtime data rollback requires a separately approved, bounded data plan.
