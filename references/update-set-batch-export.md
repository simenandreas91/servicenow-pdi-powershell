# Complete and export an update-set batch

Use when the user asks to batch existing changes, complete the sets, and save an XML file. This authorizes packaging on the selected source instance, not deployment to another instance. Reuse the known update-set IDs and previous validation evidence; do not restart application diagnosis or repeat behavior tests unless the source changed.

## 1. Resolve and audit once

1. Use explicit connection arguments, for example `$connectionArgs = @{ Profile = 'pdi'; EnvPath = './.env' }` from the skill directory. Follow `environment-routing.md` for other instances.
2. Reuse the exact child IDs established during development. Read their `sys_update_set` records and their `sys_update_xml` rows once. Verify scope, latest payloads, expected names/counts, and absence of unrelated changes. If identity is uncertain, resolve candidates before writing. Use server pagination for inventories.
3. Search for an existing parent from this task before creating another. Resume by ID. If a child already belongs to another batch, stop and resolve the intended membership; do not silently reparent it.
4. Preserve the per-scope sets. Do not merge scopes or move customer-update rows. An empty parent is normal.

## 2. Create or reuse the Global parent

Prefer a direct Table API `POST` for this metadata-only operation: it does not require making the parent current or switching application preferences. For example, with the audited name and description in variables:

```powershell
$table = './scripts/Invoke-ServiceNowTable.ps1'
$parent = (& $table @connectionArgs -Method POST -Table sys_update_set -AsObject `
  -Fields 'sys_id,name,application,state,parent,base_update_set' -ExcludeReferenceLink `
  -BodyJson (@{ name = $batchName; description = $batchDescription
    application = 'global'; state = 'in progress' } | ConvertTo-Json)).result
$batchId = $parent.sys_id
```

Record `$batchId` immediately. Do not repeat POST after an uncertain response; find the result first. If selecting a current set is necessary for other work, use `Set-ServiceNowUpdateSetContext.ps1` with a new snapshot and restore it in `finally`.

## 3. Attach children, then complete

1. PATCH the exact parent with `base_update_set=$batchId` and leave `parent` empty.
2. PATCH each audited child with both `parent=$batchId` and `base_update_set=$batchId`. Preserve its application and existing customer updates.
3. Re-read `sys_id=<batchId>^ORparent=<batchId>` and compare membership against the audited IDs. Verify the parent's self-base after attaching children: on the observed PDI, the first parent PATCH returned an empty self-base, but attaching children populated it. Do not add a server-script workaround before checking this final state. If still empty, follow the constrained fallback in `development.md`.
4. Complete each in-progress child (`state=complete`), then complete the parent. Skip writes for already-complete records; do not reopen them. Verify all states and relationships fresh. Resolve other states rather than forcing them through this sequence.

## 4. Export the hierarchy with the batch helper

Resolve the actual Windows Downloads folder (it may be redirected), choose a new filename, then run:

```powershell
$folders = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
$downloads = [Environment]::ExpandEnvironmentVariables(
  $folders.'{374DE290-123F-4565-9164-39C4925E467B}')
$output = Join-Path $downloads ($batchName + ' - ' + (Get-Date -Format yyyy-MM-dd) + '.xml')
& ./scripts/Export-ServiceNowUpdateSetBatchXml.ps1 @connectionArgs `
  -BatchSysId $batchId -OutputPath $output
```

Use a filesystem-safe batch name in the filename. The helper requires an already-complete, one-level batch; it does not select a current set, change preferences, attach children, or complete records. It inventories source payloads, runs the native exporter once, logs in with a UI cookie session, downloads the native XML, and verifies its contents before publishing the file. It refuses to overwrite an existing destination.

### Why this path matters

- `Export-ServiceNowUpdateSetXml.ps1` calls `exportUpdateSet()`, which exports a single set. It cannot export the children of an empty parent.
- Native batch generation is `new UpdateSetExport().exportHierarchy(current)` in Global scope. Its return value is the temporary **remote parent ID**, not the local batch ID.
- Download through `export_base_update_set.do?sysparm_sys_id=<remoteParentId>&sysparm_delete_when_done=true&sysparm_is_remote=false`, with the authenticated UI session and `sysparm_ck` token. Basic authentication worked for Table API/Xplore but returned HTTP 401 for this processor on the observed PDI. Start with cookie login; do not retry Basic authentication repeatedly.
- The processor cleans up its generated remote export records. It does not delete the original local completed sets.
- If generation/download fails, preserve the remote ID and any downloaded file. Inspect those before retrying generation. The helper accepts `-RemoteBatchSysId` to resume an existing generated hierarchy; it never retries the mutating exporter automatically. A downloaded file may already be valid even if the request outcome was uncertain.

## 5. Verify and deliver

The helper checks `unload`, source identities/scopes, parent/base relationships, source-to-export update counts, and exact payloads. Native XML can repeat the parent record: compare **unique sys_ids** and require duplicate parent nodes to be identical. Preserve the native XML rather than rewriting it to remove the duplicate.

When inspecting XML in PowerShell, use `SelectSingleNode('payload').InnerText` for CDATA/text, and `.LocalName` for element tag names. `[string]$node.script` may return `System.Xml.XmlElement`; `$node.Name` may return a child `<name>` value.

Confirm the file exists in Downloads and report the child-set/update counts with a clickable file link. If any preferences were changed during packaging, restore and verify the snapshot. No preview or target commit is needed for an export-only request.

## Compatibility and validation boundary

The native exporter/processor and duplicate-parent behavior were observed on the configured PDI in September 2026. On a different release, inspect the existing **Export Update Set Batch to XML** UI action and `ExportBaseUpdateSet` processor if this path fails. Do not invent an XML hierarchy or modify the processor to make an export work. Skill maintenance itself does not authorize live export mutations; validate helper changes offline unless a live export is requested.
