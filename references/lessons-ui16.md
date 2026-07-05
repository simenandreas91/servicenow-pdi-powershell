# Creating a UI16 Popup/Modal

Use this follow-along checklist when creating a classic UI16 modal in ServiceNow, especially from a form field change or UI Action.

## When To Use This Pattern

- Use a UI16 `GlideDialogWindow` plus UI Page when classic forms need a lightweight popup with inputs and validation.
- Use a client-callable Script Include for the server save when the modal needs to update the record, journal fields, or related records.
- Do not use this pattern for Service Operations Workspace. Workspace needs declarative actions, UX modal/action patterns, or workspace-specific client APIs.

## Proven UI16 Modal Shape

1. Inspect an existing modal implementation in the same instance or app before creating new records.
   - Good pattern: a thin UI Action or Client Script opens `new GlideDialogWindow('<ui_page_name>')`.
   - Pass context with `dialog.setPreference('sysparm_record_sys_id', g_form.getUniqueValue())`.
   - Set a reasonable size, then call `dialog.render()`.

2. Create the UI Page.
   - Put the form in `<g:ui_form>`.
   - Use hidden inputs for values passed through preferences or `RP.getParameterValue`.
   - Use `processing_script` to pre-load current values from the target record.
   - Use `<g:ui_choicelist table="..." field="...">` for platform choice fields instead of hardcoded option lists.
   - Add buttons with `type="button"` to avoid accidental form submit.

3. Create a UI Page read ACL.
   - Table: `sys_security_acl`
   - `type=ui_page`
   - `operation=read`
   - `name=<ui_page_name>`
   - Keep it narrow to only the UI Page being added.

4. Create a client-callable Script Include for the save.
   - Extend `AbstractAjaxProcessor` in Global or `global.AbstractAjaxProcessor` in scoped apps.
   - Validate all inputs server-side.
   - Use `GlideRecord.canWrite()` and field-level `canWrite()` checks when the Ajax saves user-facing records.
   - Return compact strings such as `success` or `error: <message>` for the modal callback.

5. Wire the opener.
   - UI Action pattern:
     ```javascript
     function openExampleDialog() {
         var dialog = new GlideDialogWindow('example_modal');
         dialog.setTitle('Example');
         dialog.setPreference('sysparm_record_sys_id', g_form.getUniqueValue());
         dialog.setSize(500, 360);
         dialog.render();
     }
     ```
   - OnChange pattern:
     ```javascript
     function onChange(control, oldValue, newValue, isLoading, isTemplate) {
         if (isLoading || newValue != '<target_value>') {
             return;
         }
     
         if (typeof g_scratchpad != 'undefined' && g_scratchpad.exampleDialogOpen) {
             return;
         }
     
         if (g_form.isNewRecord && g_form.isNewRecord()) {
             alert('Save the record first.');
             g_form.setValue('<field>', oldValue || '');
             return;
         }
     
         if (typeof g_scratchpad != 'undefined') {
             g_scratchpad.exampleDialogOpen = true;
         }
     
         var dialog = new GlideDialogWindow('example_modal');
         dialog.setTitle('Example');
         dialog.setPreference('sysparm_record_sys_id', g_form.getUniqueValue());
         dialog.setPreference('sysparm_previous_value', oldValue || '');
         dialog.setSize(500, 360);
         dialog.render();
     
         setTimeout(function() {
             if (typeof g_scratchpad != 'undefined') {
                 g_scratchpad.exampleDialogOpen = false;
             }
         }, 1000);
     }
     ```

## Client Script Pitfalls

- `syntax_editor_macro` records expand only in syntax/code editor controls such as Background Scripts and script fields. Task `comments` and `work_notes` are `journal_input` fields, so syntax editor macros do not run there. For a journal-field snippet such as `[code]<a href="YOUR_URL_HERE">Display Text</a>[/code]`, use a record template, quick-message/response-template feature where available, or a narrow UI16/Workspace action that inserts text into the journal field.
- Avoid `window.<customFlag>` in UI16 Client Scripts. In some UI16 contexts, `window` can be null or resolve unexpectedly, causing errors such as `Cannot read properties of null`.
- Use `g_scratchpad.<flag>` for a short-lived duplicate-dialog guard, with `typeof g_scratchpad != 'undefined'` checks.
- On cancel, revert any changed form field if the modal was opened by an onChange script:
  ```javascript
  g_form.setValue('<field>', previousValue || '<safe_default>');
  ```
- If the modal is submitted successfully, destroy the dialog and reload the parent form so journal fields and derived values render consistently.

## Ajax Script Include Pitfalls

- GlideAjax parameters can behave like Java strings on the server. Coerce text parameters before JavaScript string methods:
  ```javascript
  var comment = this.getParameter('sysparm_comment');
  var commentText = comment ? String(comment) : '';
  if (!commentText || !commentText.replace(/\s/g, '')) {
      return 'error: Missing comment.';
  }
  ```
- Assign journal fields with the coerced text:
  ```javascript
  current.comments = commentText;
  ```
- Do not rely only on client validation. Repeat required checks in the Script Include.

## Choice Field Pitfalls

- Be careful when adding choices to inherited fields.
- If a child table gets any choices for an inherited field, the form may stop showing inherited parent-table choices. Example: adding only `On Hold` to `sc_req_item.state` caused UI16 to show only `On Hold` and raw value `1`.
- When adding a child-table choice to an inherited field, explicitly add the full intended choice set for the child table, including inherited states and labels.
- Verify the dropdown through `sys_choice` for the child table before handing off.

## Form Layout Notes

- Adding a dictionary field through Table API or script may add unintended form layout updates. Inspect captured `sys_update_xml`.
- If adding the field to a UI16 form layout, check `sys_ui_section` and `sys_ui_element` positions first.
- Avoid duplicate positions in `sys_ui_element`; shift later elements so layout order is deterministic.

## Testing Checklist

1. Verify created records:
   - Dictionary field
   - Choices
   - UI Page
   - UI Page ACL
   - Client Script or UI Action
   - Script Include
   - Form layout entry, if applicable

2. Test the server save path with a constrained temporary record.
   - Confirm target fields changed.
   - Confirm journal entries were written when expected.
   - Clean up temporary records and parent records.

3. Test the UI path in UI16.
   - Reload the form to clear cached client scripts and choices.
   - Open the modal.
   - Validate empty required fields.
   - Save valid values.
   - Confirm the form reloads and shows the updated values.

4. Confirm update set capture.
   - Ensure all rows are in the intended application scope.
   - Investigate possible form-layout noise.
   - Restore developer preferences before final response.

## RITM On Hold Example Pattern

- `sc_req_item.state` required explicit child-table choices for all visible states plus `On Hold`.
- `sc_req_item.u_on_hold_reason` was a normal choice field with values such as `internal` and `external`.
- UI16 onChange opened a `GlideDialogWindow` when state became `8`.
- UI Page collected `On Hold Reason` and a required customer-visible comment.
- Client-callable Script Include saved:
  ```javascript
  ritm.setValue('state', '8');
  ritm.setValue('u_on_hold_reason', onHoldReason);
  ritm.comments = commentText;
  ritm.update();
  ```
