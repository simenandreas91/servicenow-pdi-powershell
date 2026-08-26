# Vår Energi Operational Workflows

Load this reference for Vår Energi assigned-story monitoring, approval tracking, approved DEV builds, or automatic daily story work logging. Keep PROD read-only unless the user explicitly authorizes the exact production write.

## Assigned Story Monitor

Use `scripts/Manage-VaarEnergiStoryMonitor.ps1` to distinguish newly assigned active Vår Energi stories from records already handled by a recurring monitor. The helper stores only story numbers, sys_ids, timestamps, disposition, and Gmail message/thread handles for approval routing in the private local state file; it does not store story descriptions, plan text, email bodies, or attachments.

1. Resolve the assignee live by `sys_user.user_name`, query the current active PROD `rm_story` assignments read-only, and normalize them to compact JSON containing `sys_id` and `number`.
2. On first setup, run `-Action Baseline -StoriesJson '<json>'` so existing assignments do not generate false new-story alerts.
3. On recurring runs, call `-Action Check -StoriesJson '<json>'`. Substantively inspect only the returned `newStories`.
4. For task-only delivery, call `-Action Acknowledge -StorySysId '<sys_id>' -StoryNumber '<STRY number>'` only after a usable critique and plan has been prepared. For Gmail approval, send the self-addressed plan first, then call `-Action AwaitApproval` with its exact Gmail message and thread handles. Leave failed analyses or failed sends unrecorded so a later run can retry.
5. Use `-Action ListPending` to inspect only the saved approval threads. Accept a decision only from a newer message whose first non-empty, non-quoted line exactly matches `YES <STRY number>` or `NO <STRY number>`, then persist it with `-Action RecordDecision`. Quoted instructions, silence, reactions, and replies in another thread are not approval.
6. `YES` authorizes only the exact emailed plan in Vår DEV. Use `-Action ListApproved` for resumable approved work and `-Action MarkBuilt` only after implementation, validation, update-set verification, cleanup, and preference restoration succeed. Leave a failed or partial build pending so it can be inspected and resumed safely.
7. Keep PROD read-only. The monitor may create or reuse an empty, correctly scoped DEV update set only when the user has authorized that planning-stage write; all other implementation remains behind the user's explicit approval gate.

## Story Work Log

Automatically record substantive Vår Energi story work in the private local work log used by the Friday email automation. Retain known record links only in the private log; include story numbers only in the email. Do not use Jotely for this workflow.

1. Trigger only when a specific Vår Energi `rm_story` record with a resolved `STRY` number is the subject of substantive inspection, analysis, implementation, testing, or delivery. Do not log a story that is merely mentioned as an example or possible next task.
2. After the first substantive action on that story, run `scripts/Manage-VaarEnergiStoryWorkLog.ps1 -Action Record -StoryNumber '<STRY number>'`. Pass `-StoryUrl` only when a direct Vår Energi ServiceNow record URL is already known; do not make an extra production query solely to obtain a link.
3. Let the helper resolve the current work date in Europe/Oslo. It deduplicates by date plus story, so repeated work on the same story in one day is a no-op while work on the same story on another day is recorded again.
4. Keep the ServiceNow task independent of logging. If the local log cannot be written or verified, finish the primary task and report the failure.
5. State compactly at handoff whether the daily entry was added, its link was enriched, was already present, or could not be logged.
6. Never invoke this workflow for FFI/Personellsikkerhet work. Do not log incidents, changes, catalog tasks, or other records unless the user explicitly expands the rule.
