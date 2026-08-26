# Environment and Credential Routing

Load this reference before connecting to a ServiceNow instance, selecting a profile, or performing environment-specific work.

Helpers load credentials from the nearest workspace `.env`. Prefer an explicit profile and env path when generic `SN_*` variables could target the wrong instance.

- `pdi`: Simen's PDI at `https://dev396302.service-now.com`; default for demonstrations and safe reproduction.
- For `pdi`, a workspace `.env` may provide `SN_PDI_INSTANCE` without duplicating credentials. When `SN_PDI_USER` or `SN_PDI_PASS` is absent there, the resolver may use the canonical private fallback at `%USERPROFILE%\.codex\servicenow-pdi.env`; workspace profile-specific values still take precedence.
- `vaar_dev`: Vår Energi DEV from `SN_VAAR_DEV`; use this for implementation and validation of Vår Energi stories. Legacy profile `other` remains an alias for `vaar_dev`.
- `vaar_test`: Vår Energi TEST from `SN_VAAR_TEST`; use it for transported configuration validation and UAT preparation.
- `vaar_prod`: Vår Energi PROD from `SN_VAAR_PROD`; keep it read-only without exact production-write authorization.
- Vår profiles accept `SN_VAAR_<ENV>_USER` / `SN_VAAR_<ENV>_PASS` when credentials differ by environment. For compatibility with the existing Vår credential file, every `vaar_*` profile also falls back to shared `SN_OTHER_USER` / `SN_OTHER_PASS` before generic `SN_USER` / `SN_PASS`. The legacy `other` profile can also resolve DEV from `SN_OTHER_INSTANCE`. Never print any credential form.
- Do not use `SN_OTHER_INSTANCE` as an implicit PROD or TEST destination. Configure `SN_VAAR_PROD` / `SN_VAAR_TEST` (or the corresponding `_INSTANCE` key), or pass the exact `-Instance` URL intentionally; only the legacy credentials are shared as a fallback.
- Invoke helpers with an explicit profile, for example `-Profile vaar_dev -EnvPath '<approved-env-path>'`. Use `-Instance` only for an intentional one-off override after verifying the returned environment.
- Values in the explicit `.env` are evaluated across canonical and compatible legacy keys before process/user environment variables. A named profile with no matching instance fails closed; it must never inherit generic `SN_INSTANCE` or a different environment's URL.
- FFI/Personellsikkerhet is on-premise and not directly reachable. Treat the PDI as the mirror unless the user provides reachable access or exported evidence. Never route FFI work to Vår Energi implicitly.

After connecting, verify the returned instance name/URL and current user before relying on results or writing. Never store credentials in the skill, references, cache, update sets, logs, or test data.
