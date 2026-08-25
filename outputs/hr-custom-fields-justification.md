# HR Case Custom Field Justification

Date: 25 August 2026  
Instances reviewed: Vår Energi DEV and PROD (read-only investigation)  
Table: `sn_hr_core_case`

## Executive conclusion

`u_inquiry_category` is a justified, minimal extension of the OOTB HR Case model. It stores a Vår Energi-specific classification inside the existing OOTB General Inquiry service. No OOTB HR Case field represents the required 11-value classification at this level.

`u_proposed_solution_at` and `u_proposed_solution_reminder_sent` have a clear functional purpose in the current custom scheduled-job design, but they should not be presented as the preferred OOTB-first architecture yet. DEV has an active OOTB **HRI Case User Acceptance** subflow that already notifies, waits for the case to leave Awaiting Acceptance, and auto-closes on timeout. The custom implementation overlaps that mechanism. The two process fields should therefore be approved only as a temporary exception, or retained after a documented proof that the supported OOTB subflow cannot be copied/configured to meet the 3- and 7-business-day requirements.

## Field decisions

| Field | Purpose | OOTB gap | Recommendation |
| --- | --- | --- | --- |
| `u_inquiry_category` | Stores the employee's mandatory General Inquiry category on the HR case. | OOTB `topic_category`/`topic_detail` classify the HR service itself; General Inquiry resolves to the OOTB topic detail **General**. They do not store the requested subcategory selected by the employee. | Retain. |
| `u_proposed_solution_at` | Records the exact time the case enters Awaiting Acceptance so a scheduled processor can calculate 3 and 7 business days from the proposal. | OOTB `opened_at`, `closed_at`, and `sys_updated_on` do not represent this transition. However, the OOTB acceptance subflow already owns a timed execution context. | Refactor toward the OOTB subflow first; retain only if the native flow cannot expose the required business-time anchor. |
| `u_proposed_solution_reminder_sent` | Makes the polling job idempotent so the 3-day reminder is sent once. It resets when a new proposal cycle starts or the case leaves Awaiting Acceptance. | There is no OOTB HR Case Boolean for this custom notification. However, a single Flow/subflow execution can naturally enforce once-only progression without a record flag. | Prefer Flow execution state; retain only if polling remains the approved design. |

## Justification for `u_inquiry_category`

PROD stories `STRY0010046` and `STRY0010047` require a mandatory category selection and a fixed list of 11 categories so HR can standardize triage and reporting. In DEV, the General Inquiry producer variable **What is the inquiry about?** is mandatory and maps directly to `sn_hr_core_case.u_inquiry_category`.

This field is needed because the existing OOTB classification has a different meaning:

- `hr_service`, `topic_category`, and `topic_detail` identify the service and its service taxonomy. For General Inquiry, the OOTB topic detail is **General**.
- The requested values such as Payroll, Vacation and Leave, Benefits and Rewards, and HR Systems/Access classify demand *within* that one General Inquiry service.
- Reusing `topic_category` would corrupt the HR service taxonomy. Creating 11 separate HR services or topic details would multiply catalog content, routing, security, reporting, and maintenance for what is only one intake question.
- Keeping the answer only as a catalog variable would make agents and reports parse producer/question data instead of using a normal case column. A mapped case field supports lists, reports, routing rules, exports, integrations, and retention controls through supported dictionary behavior.

The extension is deliberately small: one 40-character choice field and 11 controlled choices, with no script attached to the field. It is already present in PROD and DEV, and 63 DEV HR cases currently have it populated.

### Architect-ready wording

> We introduced `u_inquiry_category` as a minimal extension to the OOTB General Inquiry HR service. OOTB HRSD fields classify the selected HR service and its topic taxonomy; they do not persist Vår Energi's required inquiry subcategory. The business requires one General Inquiry service with 11 controlled demand categories for triage and reporting. Mapping the mandatory producer answer to a case field avoids duplicating HR services and avoids reporting against transient catalog question data. The field therefore preserves the OOTB service model while adding only the organization-specific data element that the standard model does not provide.

## Original rationale for the proposed-solution fields

PROD stories `STRY0010053`, `STRY0010054`, and `STRY0010055` require this sequence:

1. Notify the employee when HR proposes a solution.
2. Send one reminder after 3 business days if the employee has not commented.
3. Auto-close after 7 business days without an employee comment and add closure notes.

The current DEV implementation uses a Business Rule to stamp/reset `u_proposed_solution_at`, a daily scheduled job to calculate elapsed time on the HR business schedule, and `u_proposed_solution_reminder_sent` to prevent duplicate reminder events. The fields are internal control data; they are optional, non-audited, and reset when the case leaves Awaiting Acceptance.

If the scheduled polling design is retained, the justification is:

> The standard HR Case record does not store the timestamp at which a solution was proposed, and generic timestamps such as `sys_updated_on` change whenever the case is edited. A dedicated proposal timestamp provides a stable and queryable anchor for the contractual 3- and 7-business-day windows. The reminder Boolean records the one-time side effect already performed and makes a recurring scheduled processor idempotent. Both fields are narrowly scoped process state, reset for each proposal cycle, and avoid relying on audit-history parsing or ambiguous update timestamps.

## OOTB-first architecture finding

That rationale explains the existing design, but it does not by itself justify it as the final architecture.

DEV and PROD both contain the active OOTB Business Rule **Trigger Awaiting Acceptance Subflow**, which launches the published HR Core subflow **HRI Case User Acceptance** whenever an HR case enters state `20` (Awaiting Acceptance). The DEV component chain inspected in detail includes:

- Fire Event
- Wait For Condition while the case remains in Awaiting Acceptance, with timeout enabled
- Update Record to `state=3` on the timeout path
- follow-up events for acceptance/timeout outcomes

ServiceNow's HRSD documentation also describes Awaiting Acceptance as the native employee accept/reject stage and documents automatic closure when the employee does not respond. The precise default has varied across releases, so the installed Australia subflow is the source of truth for this environment: [Work an HR case](https://www.servicenow.com/docs/r/iMpltWWdX~aXgRlaoFVPCw/8dzIJ1UpE_uGE3Hmk_Q6YQ).

The current custom job duplicates part of this lifecycle. The June verification backdated `u_proposed_solution_at` and ran the processor, which proves the custom processor in isolation but does not prove coexistence with the native timer. A real-time case can be closed by OOTB before reaching the custom 3-day reminder or 7-day close.

## Recommendation

1. Keep `u_inquiry_category` and document it as an approved organization-specific data extension.
2. Do not promote the two proposed-solution fields and scheduled processor as-is until the native acceptance subflow is reconciled.
3. Prefer an OOTB-aligned Flow/subflow design: copy/extend the supported acceptance pattern, preserve accept/reject behavior, use the approved HR business schedule, add the 3-day reminder, and set the 7-day timeout. Let the flow execution provide once-only progression where possible.
4. If a proof of concept shows that the supported native design cannot provide the required business-time anchor or employee-comment test, retain `u_proposed_solution_at` as the smallest exception. Reassess whether the reminder Boolean is still needed when Flow context provides idempotency.
5. Run an elapsed-time test without backdating: enter Awaiting Acceptance, confirm exactly one acceptance flow, verify no earlier OOTB close, verify reminder at 3 business days, employee-comment suppression, close at 7 business days, and re-entry after rejection.

## Traceability

| Evidence | Finding |
| --- | --- |
| PROD `STRY0010046` | Mandatory inquiry category and question must be captured. |
| PROD `STRY0010047` | Fixed 11-category list for standardized triage and reporting. |
| DEV update set `STRY0010045-48,51 - General Inquiry HR Core` | Created the dictionary field, choices, label, and General Inquiry HR configuration. |
| Prior Codex task `019e408c-c038-71f1-a73e-a28c723d2e3a` | On 19 May 2026, the user explicitly asked to add a custom HR Case field to store the category choices; the result mapped the producer variable to it. |
| PROD `STRY0010053`-`STRY0010055` | Proposed notification, 3-business-day reminder, and 7-business-day auto-close requirements. |
| DEV update set `STRY0010053-55 - HR proposed solution auto-close` | Contains two dictionary fields plus the tracking Business Rule, scheduled processor, event, and notifications. |
| Prior Codex task `019ecf9e-e2eb-7da1-b4f7-731d81aa709f` | On 16 June 2026, validated the custom reminder/close processor and later corrected the Employee Center email link. This is the nearest retained task transcript for the proposed-solution implementation; the original 22 May creation transcript was not present in the local task archive. |
| PROD vs DEV comparison | PROD currently contains `u_inquiry_category` only. The two proposed-solution fields are DEV-only. |
