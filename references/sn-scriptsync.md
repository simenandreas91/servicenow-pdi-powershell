# SN Utils and sn-scriptsync

Load this reference when a workspace contains synced ServiceNow source files or `.vscode/sn-agent-port.json`, or when using `sync_now` and `get_sync_status`.

When the workspace already contains a clear synced representation and `.vscode/sn-agent-port.json` identifies a healthy local Agent API:

1. Inspect the local source and the live record metadata. Treat each instance folder as a separate environment; do not propagate changes across them unless requested.
2. Edit the split source files with normal code tools and keep any aggregate record file consistent with the workspace convention.
3. Run local syntax/static checks.
4. Call `sync_now`, then require `get_sync_status` to show no pending writes.
5. Re-read the live record, confirm update-set capture, and test the rendered/runtime behavior.

Never print or persist the Agent API token. If local and live content disagree or ownership is unclear, stop writing and establish the source of truth. Use Table API/Xplore for record metadata, ACLs, runtime data, related records, and update-set verification.
