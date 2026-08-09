# CMDB Query and Script Library

## Use and safety

Use these patterns with `cmdb-admin-development.md`. They were aligned to Australia documentation and schema-checked against Simen's Australia Patch 1 PDI on 2026-08-09. Recheck fields on another release/app version.

- Q00-Q04 and Q06-Q23 are read-only unless explicitly stated.
- Q05, Q21, and Q24 contain mutating patterns and are disabled/guarded by default.
- Replace every `CHANGE_ME_*` value. Validate table/field names before running.
- Keep queries selective and limits small. Do not run a broad scan of `cmdb_ci` in production.
- Run through `Invoke-ServiceNowXploreScript.ps1` or Scripts - Background only in an approved environment/scope. Use `GlideRecordSecure` for user-context APIs.
- Never print credentials, full sensitive payloads, credential records, or unrestricted CI dumps.
- Internal tables are queried for evidence only; never repair their rows directly.

## Contents

- **Q00-Q03:** schema, installed capabilities, identification, and reconciliation
- **Q04-Q07:** IRE simulation/write pattern and provenance/CMDB 360
- **Q08-Q11:** health, inclusion, principal classes, and life-cycle mapping
- **Q12-Q17:** reclassification and relationship diagnostics
- **Q18-Q20:** Data Manager and duplicate remediation
- **Q21-Q24:** Transform Maps, Discovery, Service Mapping, and Scripted REST
- **Q25-Q26:** Flow Designer and Table API patterns

## Q00 — Resolve a table by name or label and print active fields

Use first whenever a UI label or field is uncertain.

```javascript
(function () {
    var tableOrLabel = 'CHANGE_ME_TABLE_OR_LABEL';
    var tables = new GlideRecord('sys_db_object');
    var qc = tables.addQuery('name', tableOrLabel);
    qc.addOrCondition('label', 'CONTAINS', tableOrLabel);
    tables.orderBy('name');
    tables.setLimit(20);
    tables.query();

    while (tables.next()) {
        var tableName = tables.getValue('name');
        gs.info('TABLE ' + tableName + ' | ' + tables.getValue('label'));

        var fields = new GlideRecord('sys_dictionary');
        fields.addQuery('name', tableName);
        fields.addQuery('active', true);
        fields.addNotNullQuery('element');
        fields.orderBy('element');
        fields.query();
        while (fields.next()) {
            gs.info('  ' + fields.getValue('element') +
                ' | ' + fields.getValue('column_label') +
                ' | ' + fields.getValue('internal_type') +
                ' | ref=' + fields.getValue('reference'));
        }
    }
})();
```

PowerShell equivalent:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi -Table sys_db_object `
  -Query 'name=CHANGE_ME^ORlabelLIKECHANGE_ME' -Fields 'name,label,super_class' `
  -Limit 20 -ExcludeReferenceLink
```

## Q01 — Verify installed CMDB tables and release-sensitive properties

```javascript
(function () {
    var names = [
        'cmdb_identifier', 'cmdb_identifier_entry',
        'cmdb_reconciliation_definition', 'cmdb_dynamic_reconciliation_definition',
        'cmdb_health_config', 'cmdb_health_result', 'cmdb_health_scorecard',
        'cmdb_multisource_data', 'cmdb_class_info', 'life_cycle_mapping',
        'cmdb_data_management_policy', 'reconcile_duplicate_task'
    ];

    var obj = new GlideRecord('sys_db_object');
    obj.addQuery('name', 'IN', names.join(','));
    obj.orderBy('name');
    obj.query();
    while (obj.next())
        gs.info(obj.getValue('name') + ' | ' + obj.getValue('label'));

    var propNames = [
        'glide.identification_engine.multisource_enabled',
        'glide.identification_engine.multisource_cmdb_ci_enabled',
        'glide.identification_engine.multisource_non_cmdb_ci_enabled',
        'glide.identification_engine.reclassification_restriction_rules_enabled',
        'glide.class.upgrade.enabled', 'glide.class.downgrade.enabled', 'glide.class.switch.enabled',
        'csdm.lifecycle.sync.between.ci.and.asset.activated',
        'com.snc.task.principal_class_filter'
    ];
    var prop = new GlideRecord('sys_properties');
    prop.addQuery('name', 'IN', propNames.join(','));
    prop.orderBy('name');
    prop.query();
    while (prop.next())
        gs.info('PROPERTY ' + prop.getValue('name') + '=' + prop.getValue('value'));
})();
```

An absent property can mean default behavior or an unavailable feature; verify documentation/plugin before creating it.

## Q02 — Inspect effective identification rules and ordered entries

```javascript
(function () {
    var targetClass = 'CHANGE_ME_CLASS';

    var identifiers = new GlideRecord('cmdb_identifier');
    identifiers.addQuery('applies_to', targetClass);
    identifiers.orderByDesc('active');
    identifiers.query();

    if (!identifiers.hasNext())
        gs.info('No rule defined directly on ' + targetClass + '; inspect ancestors in CI Class Manager.');

    while (identifiers.next()) {
        gs.info('IDENTIFIER ' + identifiers.getUniqueValue() +
            ' name=' + identifiers.getValue('name') +
            ' class=' + identifiers.getValue('applies_to') +
            ' active=' + identifiers.getValue('active') +
            ' independent=' + identifiers.getValue('independent'));

        var entries = new GlideRecord('cmdb_identifier_entry');
        entries.addQuery('identifier', identifiers.getUniqueValue());
        entries.orderBy('order');
        entries.query();
        while (entries.next()) {
            gs.info('  priority=' + entries.getValue('order') +
                ' active=' + entries.getValue('active') +
                ' search_table=' + entries.getValue('table') +
                ' criteria=' + entries.getValue('attributes') +
                ' main_criteria=' + entries.getValue('main_attributes') +
                ' hybrid_criteria=' + entries.getValue('hybrid_entry_ci_criterion_attributes') +
                ' allow_null=' + entries.getValue('allow_null_attribute') +
                ' exact_count=' + entries.getValue('exact_count_match') +
                ' fallback=' + entries.getValue('allow_fallback') +
                ' condition=' + entries.getValue('condition'));
        }
    }
})();
```

Interpretation:

- Zero direct rules does not prove zero effective rules; inspect the closest ancestor.
- Equal entry priorities are a defect because evaluation among them is not deterministic.
- A child-defined rule replaces the inherited rule for that child.

## Q03 — Inspect static and dynamic reconciliation rules

```javascript
(function () {
    var targetClass = 'CHANGE_ME_CLASS';

    var stat = new GlideRecord('cmdb_reconciliation_definition');
    stat.addQuery('applies_to', targetClass);
    stat.orderBy('priority');
    stat.query();
    while (stat.next()) {
        gs.info('STATIC name=' + stat.getValue('name') +
            ' active=' + stat.getValue('active') +
            ' priority=' + stat.getValue('priority') +
            ' source=' + stat.getValue('discovery_source') +
            ' attributes=' + stat.getValue('attributes') +
            ' update_null=' + stat.getValue('null_update') +
            ' condition=' + stat.getValue('condition'));
    }

    var dyn = new GlideRecord('cmdb_dynamic_reconciliation_definition');
    dyn.addQuery('applies_to', targetClass);
    dyn.orderBy('name');
    dyn.query();
    while (dyn.next()) {
        gs.info('DYNAMIC name=' + dyn.getValue('name') +
            ' active=' + dyn.getValue('active') +
            ' type=' + dyn.getValue('rule_type') +
            ' attributes=' + dyn.getValue('attributes') +
            ' condition=' + dyn.getValue('condition'));
    }

    var refresh = new GlideRecord('cmdb_datasource_staleness');
    refresh.addQuery('applies_to', targetClass);
    refresh.query();
    while (refresh.next())
        gs.info('REFRESH ' + refresh.getDisplayValue());

    var sourceRules = new GlideRecord('cmdb_ire_data_source_rule');
    sourceRules.addQuery('applies_to', targetClass);
    sourceRules.query();
    while (sourceRules.next())
        gs.info('IRE SOURCE RULE ' + sourceRules.getDisplayValue());
})();
```

Repeat for ancestors to establish derived behavior. Use CI Class Manager Preview Rule for the final precedence view.

## Q04 — No-commit IRE identification test

Global-scope example. `identifyCI` determines the operation without committing it.

```javascript
(function () {
    var source = 'ImportSet'; // Must be a valid cmdb_ci.discovery_source choice.
    var payload = {
        items: [{
            className: 'cmdb_ci_server',
            internal_id: 'test-server-001',
            values: {
                name: 'CMDB-IRE-SIM-001',
                serial_number: 'CMDB-IRE-SIM-SERIAL-001'
            },
            sys_object_source_info: {
                source_name: source,
                source_feed: 'CMDB Skill PDI Simulation',
                source_native_key: 'test-server-001',
                source_recency_timestamp: new GlideDateTime().getValue()
            }
        }]
    };

    // Global no-commit API takes the JSON payload as its argument on the
    // verified Australia Patch 1 runtime. The source still belongs in each
    // item's sys_object_source_info and must be a valid discovery_source choice.
    var raw = SNC.IdentificationEngineScriptableApi.identifyCI(JSON.stringify(payload));
    var out = JSON.parse(raw);
    gs.info(JSON.stringify({items: out.items, relations: out.relations, summary: out.summary}, null, 2));
})();
```

Do not copy the two-argument `createOrUpdateCI(source, json)` signature onto `identifyCI`; Australia Patch 1 attempts to parse the first argument as JSON. For a scoped application use the current `sn_cmdb.IdentificationEngine.identifyCIEnhanced` signature after verifying the family API reference. Identification Simulation is preferred for dependent payload generation and log review.

## Q05 — Guarded IRE create/update test (mutating)

Run only with explicit authorization in PDI/DEV after Q04. The guard is intentionally false.

```javascript
(function () {
    var ALLOW_WRITE = false;
    if (!ALLOW_WRITE)
        throw 'Write disabled. Review Q04 output, target class, source choice, and cleanup plan first.';

    var source = 'ImportSet';
    var uniqueKey = 'CHANGE_ME_UNIQUE_SOURCE_KEY';
    var payload = {
        items: [{
            className: 'cmdb_ci_server',
            internal_id: uniqueKey,
            values: {
                name: 'CHANGE_ME_UNIQUE_TEST_NAME',
                serial_number: 'CHANGE_ME_UNIQUE_SERIAL',
                short_description: 'Controlled PDI IRE validation record'
            },
            settings: {
                updateWithoutDowngrade: true,
                updateWithoutSwitch: true
            },
            sys_object_source_info: {
                source_name: source,
                source_feed: 'CMDB Skill PDI Test',
                source_native_key: uniqueKey,
                source_recency_timestamp: new GlideDateTime().getValue()
            }
        }]
    };

    var raw = SNC.IdentificationEngineScriptableApi.createOrUpdateCI(source, JSON.stringify(payload));
    var out = JSON.parse(raw);
    gs.info(JSON.stringify({items: out.items, relations: out.relations, summary: out.summary}, null, 2));

    if (!out.items || out.items.length !== 1 || out.items[0].errorCount > 0)
        throw 'IRE did not return one successful item; inspect the complete secured output and IRE logs.';
})();
```

Run twice with identical input. The second run must not insert a second CI.

## Q06 — Trace IRE source-native provenance

```javascript
(function () {
    var ciSysId = 'CHANGE_ME_CI_SYS_ID';
    var src = new GlideRecord('sys_object_source');
    src.addQuery('id', ciSysId);
    src.orderByDesc('last_scan');
    src.setLimit(50);
    src.query();
    while (src.next()) {
        gs.info('target_table=' + src.getValue('target_table') +
            ' ci=' + src.getValue('id') +
            ' source=' + src.getValue('name') +
            ' feed=' + src.getValue('source_feed') +
            ' last_scan=' + src.getValue('last_scan'));
    }
})();
```

No row can indicate a direct write, pre-IRE history, cleanup, or an ingestion path that did not supply source-object information. Prove which before concluding.

## Q07 — Inspect CMDB 360 raw source reports for one CI

```javascript
(function () {
    var ciSysId = 'CHANGE_ME_CI_SYS_ID';
    var ms = new GlideRecord('cmdb_multisource_data');
    var qc = ms.addQuery('ci', ciSysId);
    qc.addOrCondition('cmdb_reference', ciSysId);
    ms.orderByDesc('sys_updated_on');
    ms.setLimit(100);
    ms.query();
    while (ms.next()) {
        gs.info('class=' + ms.getValue('class') +
            ' source=' + ms.getValue('discovery_source') +
            ' updated=' + ms.getValue('sys_updated_on') +
            ' json=' + ms.getValue('json'));
    }
})();
```

The `col*` fields are performance slots mapped by `[cmdb_multisource_column_metadata]`; do not hard-code their meaning. Use `json` or the supported CMDB 360 query UI/API and metadata mapping.

Check collection exclusions:

```javascript
var deny = new GlideRecord('cmdb_multisource_deny_class');
deny.addQuery('active', true);
deny.query();
while (deny.next()) gs.info(deny.getDisplayValue());
```

## Q08 — Query CMDB Health metrics, scorecards, failures, and processing state

```javascript
(function () {
    var targetClass = 'CHANGE_ME_CLASS';

    var score = new GlideRecord('cmdb_health_scorecard');
    score.addQuery('class', targetClass);
    score.orderByDesc('evaluated_on');
    score.setLimit(50);
    score.query();
    while (score.next()) {
        var failed = parseInt(score.getValue('failed') || '0', 10);
        var total = parseInt(score.getValue('total') || '0', 10);
        var calculatedFailurePct = total ? Math.round((failed * 100) / total) : null;
        gs.info('SCORE class=' + score.getValue('class') +
            ' metric=' + score.getDisplayValue('metric') +
            ' score=' + score.getValue('score') +
            ' failed=' + failed +
            ' total=' + total +
            ' calculated_failure_pct=' + calculatedFailurePct +
            ' status=' + score.getValue('status') +
            ' evaluated=' + score.getValue('evaluated_on'));
    }

    var result = new GlideRecord('cmdb_health_result');
    result.addQuery('class_name', targetClass);
    result.addQuery('active', true);
    result.orderByDesc('last_evaluated_on');
    result.setLimit(100);
    result.query();
    while (result.next()) {
        gs.info('FAIL ci=' + result.getValue('ci') +
            ' metric=' + result.getDisplayValue('metric') +
            ' source=' + result.getValue('source') +
            ' discovery_source=' + result.getValue('discovery_source') +
            ' evaluated=' + result.getValue('last_evaluated_on') +
            ' description=' + result.getValue('description'));
    }

    var metricStatus = new GlideRecord('cmdb_health_metric_status');
    metricStatus.orderByDesc('sys_updated_on');
    metricStatus.setLimit(50);
    metricStatus.query();
    while (metricStatus.next())
        gs.info('METRIC STATUS ' + metricStatus.getDisplayValue());

    var processor = new GlideRecord('cmdb_health_processor_status');
    processor.orderByDesc('sys_updated_on');
    processor.setLimit(50);
    processor.query();
    while (processor.next())
        gs.info('PROCESSOR ' + processor.getDisplayValue());
})();
```

Use `failed` and `total` for the denominator; do not reverse-engineer a percentage from failure rows alone. Australia Patch 1 live evidence showed the raw `score` field equal to the failure percentage. A dashboard may invert it to a healthy percentage, so verify the current widget before naming or publishing it.

## Q09 — Inspect and preview health inclusion rules

The Australia Patch 1 PDI confirms the table and fields below.

```javascript
(function () {
    var targetClass = 'CHANGE_ME_CLASS';
    var rules = new GlideRecord('cmdb_health_config');
    rules.addQuery('applies_to', targetClass);
    rules.query();
    while (rules.next()) {
        gs.info('metric=' + rules.getDisplayValue('metric') +
            ' applies_to=' + rules.getValue('applies_to') +
            ' condition=' + rules.getValue('active_record_condition'));
    }

    // Preview one proposed condition directly on the target class.
    var proposedCondition = 'CHANGE_ME_ENCODED_QUERY';
    var ci = new GlideAggregate(targetClass);
    ci.addEncodedQuery(proposedCondition);
    ci.addAggregate('COUNT');
    ci.query();
    if (ci.next()) gs.info('Proposed included count=' + ci.getAggregate('COUNT'));
})();
```

Configure through CI Class Manager. Do not insert `cmdb_health_config` directly.

## Q10 — Inspect principal classes and task filtering

```javascript
(function () {
    var info = new GlideRecord('cmdb_class_info');
    info.addQuery('principal_class', true);
    info.orderBy('class');
    info.query();
    var count = 0;
    while (info.next()) {
        count++;
        gs.info('class=' + info.getValue('class') +
            ' managed_by_group=' + info.getDisplayValue('managed_by_group'));
    }
    gs.info('Principal class count=' + count);
    gs.info('Task types=' + gs.getProperty('com.snc.task.principal_class_filter', ''));
})();
```

The verified PDI returned zero principal classes on 2026-08-09. That is a finding, not authorization to mark classes.

## Q11 — Inspect life-cycle mappings and unmapped legacy values

```javascript
(function () {
    var targetClass = 'CHANGE_ME_CLASS';
    var legacyField = 'CHANGE_ME_LEGACY_FIELD';

    var map = new GlideRecord('life_cycle_mapping');
    map.addQuery('table', targetClass);
    map.orderBy('priority');
    map.query();
    while (map.next()) {
        gs.info('priority=' + map.getValue('priority') +
            ' active=' + map.getValue('active') +
            ' legacy=' + map.getValue('legacy_field_name') + '=' + map.getValue('legacy_field_value') +
            ' sub=' + map.getValue('legacy_subfield_name') + '=' + map.getValue('legacy_subfield_value') +
            ' control=' + map.getDisplayValue('life_cycle_control') +
            ' reverse=' + map.getValue('reverse_sync_choice'));
    }

    var values = new GlideAggregate(targetClass);
    values.addAggregate('COUNT');
    values.groupBy(legacyField);
    values.orderByAggregate('COUNT');
    values.query();
    while (values.next())
        gs.info(legacyField + '=' + values.getValue(legacyField) + ' count=' + values.getAggregate('COUNT'));
})();
```

Also inspect `life_cycle_control` for valid class/stage/status pairs before enabling synchronization.

## Q12 — Reclassification preflight (read-only)

```javascript
(function () {
    var ciSysId = 'CHANGE_ME_CI_SYS_ID';
    var targetClass = 'CHANGE_ME_TARGET_CLASS';

    var ci = new GlideRecord('cmdb_ci');
    if (!ci.get(ciSysId)) throw 'CI not found';
    var sourceClass = ci.getValue('sys_class_name');
    gs.info('CI=' + ci.getDisplayValue() + ' source=' + sourceClass + ' target=' + targetClass);

    function ownFields(tableName) {
        var out = {};
        var d = new GlideRecord('sys_dictionary');
        d.addQuery('name', tableName);
        d.addQuery('active', true);
        d.addNotNullQuery('element');
        d.query();
        while (d.next()) out[d.getValue('element')] = true;
        return out;
    }

    var sourceFields = ownFields(sourceClass);
    var targetFields = ownFields(targetClass);
    Object.keys(sourceFields).sort().forEach(function (f) {
        if (!targetFields[f] && ci.isValidField(f) && !ci.getElement(f).nil())
            gs.info('SOURCE-ONLY POPULATED ' + f + '=' + ci.getDisplayValue(f));
    });

    var restrictionTable = 'cmdb_ire_reclassification_restriction';
    var tableDef = new GlideRecord('sys_db_object');
    if (tableDef.get('name', restrictionTable)) {
        gs.info('Reclassification restriction table is installed. Resolve its active fields with Q00; field names vary by release/app version.');
        var restrictions = new GlideRecord(restrictionTable);
        if (restrictions.isValidField('active')) restrictions.addQuery('active', true);
        restrictions.setLimit(50);
        restrictions.query();
        while (restrictions.next()) gs.info('RESTRICTION ' + restrictions.getDisplayValue());
    } else {
        gs.info('No reclassification restriction table installed; verify property/plugin and current release documentation.');
    }

    var tasks = new GlideRecord('reclassification_task');
    tasks.addQuery('sys_created_on', '>=', gs.daysAgoStart(90));
    tasks.addQuery('description', 'CONTAINS', ciSysId);
    tasks.setLimit(20);
    tasks.query();
    while (tasks.next()) gs.info('TASK ' + tasks.getDisplayValue());
})();
```

Dictionary rows on one table do not fully represent inherited fields. Use this only to identify risk; complete the hierarchy/consumer analysis before any class change.

## Q13 — Inspect dependent relationship rules and missing dependency edges

```javascript
(function () {
    var targetClass = 'CHANGE_ME_DEPENDENT_CLASS';

    var host = new GlideRecord('cmdb_metadata_hosting');
    var hq = host.addQuery('parent_type', targetClass);
    hq.addOrCondition('child_type', targetClass);
    host.query();
    while (host.next())
        gs.info('HOST parent=' + host.getValue('parent_type') +
            ' rel=' + host.getDisplayValue('rel_type') +
            ' child=' + host.getValue('child_type') +
            ' reverse=' + host.getValue('is_reverse'));

    var contain = new GlideRecord('cmdb_metadata_containment');
    contain.addQuery('ci_type', targetClass);
    contain.query();
    while (contain.next())
        gs.info('CONTAIN class=' + contain.getValue('ci_type') +
            ' rel=' + contain.getDisplayValue('rel_type') +
            ' parent_rule=' + contain.getValue('parent_id') +
            ' reverse=' + contain.getValue('is_reverse') +
            ' always_include=' + contain.getValue('always_include'));

    var ledger = new GlideRecord('cmdb_dependent_ci_ledger');
    ledger.addQuery('sys_created_on', '>=', gs.daysAgoStart(30));
    ledger.orderByDesc('sys_created_on');
    ledger.setLimit(100);
    ledger.query();
    while (ledger.next()) gs.info('DEPENDENT LEDGER ' + ledger.getDisplayValue());
})();
```

Use Identification Simulation to prove the actual dependency chain; do not infer a missing edge solely from ledger presence.

## Q14 — Find duplicate and orphan relationship records

```javascript
(function () {
    var targetCi = 'CHANGE_ME_CI_SYS_ID';

    var dup = new GlideAggregate('cmdb_rel_ci');
    var q = dup.addQuery('parent', targetCi);
    q.addOrCondition('child', targetCi);
    dup.addAggregate('COUNT');
    dup.groupBy('parent');
    dup.groupBy('child');
    dup.groupBy('type');
    dup.addHaving('COUNT', '>', 1);
    dup.query();
    while (dup.next())
        gs.info('DUP parent=' + dup.getValue('parent') +
            ' child=' + dup.getValue('child') +
            ' type=' + dup.getValue('type') +
            ' count=' + dup.getAggregate('COUNT'));

    var orphan = new GlideRecord('cmdb_rel_ci');
    orphan.addEncodedQuery('parentISEMPTY^ORchildISEMPTY');
    orphan.setLimit(100);
    orphan.query();
    while (orphan.next()) gs.info('ORPHAN REL ' + orphan.getUniqueValue());
})();
```

Do not delete results from this diagnostic. Establish source/dependency/retention and exact downstream effects first.

## Q15 — Trace non-dependent relationship provenance

```javascript
(function () {
    var relationshipSysId = 'CHANGE_ME_REL_SYS_ID';
    var src = new GlideRecord('sys_rel_source');
    src.addQuery('target_relationship', relationshipSysId);
    src.orderByDesc('last_scan');
    src.query();
    while (src.next())
        gs.info('source=' + src.getValue('source_name') +
            ' feed=' + src.getValue('source_feed') +
            ' last_scan=' + src.getValue('last_scan'));
})();
```

Absence may be expected because `glide.identification_engine.populate_sys_rel_source` is not enabled by default. Dependent relationship provenance is handled differently.

## Q16 — Bounded relationship traversal

```javascript
(function () {
    var start = 'CHANGE_ME_CI_SYS_ID';
    var maxDepth = 3;
    var maxNodes = 200;
    var queue = [{id: start, depth: 0}];
    var seen = {};
    seen[start] = true;

    while (queue.length && Object.keys(seen).length < maxNodes) {
        var item = queue.shift();
        if (item.depth >= maxDepth) continue;

        var rel = new GlideRecord('cmdb_rel_ci');
        var qc = rel.addQuery('parent', item.id);
        qc.addOrCondition('child', item.id);
        rel.setLimit(maxNodes);
        rel.query();
        while (rel.next() && Object.keys(seen).length < maxNodes) {
            var parent = rel.getValue('parent');
            var child = rel.getValue('child');
            var other = parent === item.id ? child : parent;
            gs.info('depth=' + item.depth +
                ' parent=' + parent +
                ' type=' + rel.getDisplayValue('type') +
                ' child=' + child);
            if (!seen[other]) {
                seen[other] = true;
                queue.push({id: other, depth: item.depth + 1});
            }
        }
    }
    gs.info('visited=' + Object.keys(seen).length + ' capped_at=' + maxNodes);
})();
```

Narrow by relationship type/class for production analysis. This is not a transactional Business Rule pattern.

## Q17 — Compare actual relationship edges with hosting/containment metadata

```javascript
(function () {
    var relSysId = 'CHANGE_ME_REL_SYS_ID';
    var rel = new GlideRecord('cmdb_rel_ci');
    if (!rel.get(relSysId)) throw 'Relationship not found';

    gs.info('ACTUAL parent=' + rel.parent.sys_class_name +
        ' type=' + rel.getDisplayValue('type') +
        ' child=' + rel.child.sys_class_name);

    var host = new GlideRecord('cmdb_metadata_hosting');
    host.addQuery('rel_type', rel.getValue('type'));
    host.query();
    while (host.next())
        gs.info('HOST RULE ' + host.getValue('parent_type') + ' -> ' + host.getValue('child_type') +
            ' reverse=' + host.getValue('is_reverse'));

    var contain = new GlideRecord('cmdb_metadata_containment');
    contain.addQuery('rel_type', rel.getValue('type'));
    contain.query();
    while (contain.next())
        gs.info('CONTAIN RULE class=' + contain.getValue('ci_type') +
            ' parent_rule=' + contain.getValue('parent_id') +
            ' reverse=' + contain.getValue('is_reverse'));
})();
```

Use CI Class Manager/Metadata Editor for the authoritative inherited rule view.

## Q18 — Inspect Data Manager policy, executions, and task backlog

```javascript
(function () {
    var policyName = 'CHANGE_ME_POLICY_NAME';
    var p = new GlideRecord('cmdb_data_management_policy');
    p.addQuery('name', policyName);
    p.setLimit(10);
    p.query();
    while (p.next()) {
        gs.info('POLICY id=' + p.getUniqueValue() +
            ' type=' + p.getDisplayValue('cmdb_policy_type') +
            ' table=' + p.getValue('table') +
            ' filter=' + p.getValue('encoded_query') +
            ' approval=' + p.getValue('needs_review') +
            ' group=' + p.getDisplayValue('user_group') +
            ' subflow=' + p.getDisplayValue('subflow'));

        var ex = new GlideRecord('cmdb_data_management_policy_execution');
        ex.addQuery('cmdb_policy', p.getUniqueValue());
        ex.orderByDesc('start_time');
        ex.setLimit(20);
        ex.query();
        while (ex.next()) {
            gs.info('  EXEC ' + ex.getValue('number') +
                ' state=' + ex.getValue('execution_state') +
                ' records=' + ex.getValue('record_count') +
                ' tasks=' + ex.getValue('total_task_count') +
                ' open=' + ex.getValue('open_task_count') +
                ' unassigned=' + ex.getValue('unassigned_task_count') +
                ' completed=' + ex.getValue('completed_task_count') +
                ' percent=' + ex.getValue('percent_complete'));
        }
    }
})();
```

Preview candidates by running the policy table/filter as a separate `GlideAggregate` count and a small sample. Do not publish/run via direct table updates.

## Q19 — Inspect duplicate tasks and their member CIs

```javascript
(function () {
    var taskSysId = 'CHANGE_ME_DUP_TASK_SYS_ID';
    var task = new GlideRecord('reconcile_duplicate_task');
    if (!task.get(taskSysId)) throw 'Duplicate task not found';
    gs.info('TASK ' + task.getDisplayValue() +
        ' state=' + task.getValue('state') +
        ' duplicate_count=' + task.getValue('duplicate_count') +
        ' template=' + task.getDisplayValue('template'));

    var members = new GlideRecord('duplicate_audit_result');
    members.addQuery('follow_on_task', taskSysId);
    members.orderBy('duplicate_id');
    members.query();
    while (members.next())
        gs.info('  member=' + members.getValue('duplicate_ci') +
            ' table=' + members.getValue('table') +
            ' source=' + members.getValue('discovery_source_duplicate_ci') +
            ' depends_on=' + members.getValue('depend_on') +
            ' relationship=' + members.getDisplayValue('relationship'));

    var runs = new GlideRecord('cmdb_duplicate_ci_remediation');
    runs.addQuery('task', taskSysId);
    runs.orderByDesc('sys_created_on');
    runs.setLimit(20);
    runs.query();
    while (runs.next())
        gs.info('  RUN state=' + runs.getValue('state') +
            ' master=' + runs.getValue('master_ci') +
            ' merge_relations=' + runs.getValue('merge_relations') +
            ' error=' + runs.getValue('error') +
            ' message=' + runs.getValue('message'));
})();
```

Some releases/tasks link audit results differently. If no members return, use Q00 on `duplicate_audit_result` and inspect the task related list query rather than inventing a join.

## Q20 — Post-remediation validation for a main CI

```javascript
(function () {
    var mainCi = 'CHANGE_ME_MAIN_CI_SYS_ID';
    var duplicateCis = ['CHANGE_ME_DUPLICATE_SYS_ID'];

    var main = new GlideRecord('cmdb_ci');
    if (!main.get(mainCi)) throw 'Main CI not found';
    gs.info('MAIN ' + main.getDisplayValue() + ' class=' + main.getValue('sys_class_name'));

    duplicateCis.forEach(function (id) {
        var d = new GlideRecord('cmdb_ci');
        if (d.get(id))
            gs.info('DUP id=' + id + ' duplicate_of=' + d.getValue('duplicate_of') +
                ' class=' + d.getValue('sys_class_name'));
    });

    [{table: 'task_ci', field: 'ci_item'},
     {table: 'change_request', field: 'cmdb_ci'},
     {table: 'alm_asset', field: 'ci'}].forEach(function (spec) {
        var tableDef = new GlideRecord('sys_db_object');
        if (!tableDef.get('name', spec.table)) return;
        var gr = new GlideAggregate(spec.table);
        if (!gr.isValidField(spec.field)) {
            gs.info(spec.table + '.' + spec.field + ' is not valid; resolve the reference field with Q00');
            return;
        }
        gr.addQuery(spec.field, 'IN', duplicateCis.join(','));
        gr.addAggregate('COUNT');
        gr.query();
        if (gr.next()) gs.info(spec.table + '.' + spec.field + ' remaining duplicate refs=' + gr.getAggregate('COUNT'));
    });
})();
```

Field names vary by related table; validate each table's reference field with Q00. Also run Q14 and verify the next source ingestion.

## Q21 — Required onBefore Transform Script for classic CMDB imports (mutating)

This is the supported `CMDBTransformUtil` pattern. Use one transform map and do not use it for dependent CIs.

```javascript
(function runTransformScript(source, map, log, target) {
    var cmdbUtil = new CMDBTransformUtil();
    cmdbUtil.setDataSource('ImportSet'); // Use an approved, valid discovery_source choice.
    cmdbUtil.identifyAndReconcile(source, map, log);

    // Prevent the transform engine from performing a second/direct target insert.
    ignore = true;

    if (cmdbUtil.hasError()) {
        log.error('IRE failed for import row ' + source.getUniqueValue() + ': ' + cmdbUtil.getError());
        return;
    }

    log.info('IRE target sys_id=' + cmdbUtil.getOutputRecordSysId());
    log.info('IRE output=' + cmdbUtil.getOutputPayload());
})(source, map, log, target);
```

Do not log the output payload if it can contain secrets/sensitive fields. Use IH-ETL/RTE for dependent CIs and richer relationship payloads.

## Q22 — Correlate recent Discovery status and logs

```javascript
(function () {
    var statusNumber = 'CHANGE_ME_DISCOVERY_STATUS_NUMBER';
    var status = new GlideRecord('discovery_status');
    status.addQuery('number', statusNumber);
    status.setLimit(1);
    status.query();
    if (!status.next()) throw 'Discovery status not found';

    gs.info('STATUS ' + status.getValue('number') +
        ' schedule=' + status.getDisplayValue('dscheduler') +
        ' state=' + status.getValue('state') +
        ' progress=' + status.getValue('progress') +
        ' started=' + status.getValue('started') +
        ' completed=' + status.getValue('completed') +
        ' source=' + status.getValue('source'));

    var log = new GlideRecord('discovery_log');
    log.addQuery('status', status.getUniqueValue());
    log.orderBy('created_on');
    log.setLimit(200);
    log.query();
    while (log.next())
        gs.info('LOG result=' + log.getValue('result_code') +
            ' ci=' + log.getDisplayValue('cmdb_ci') +
            ' device=' + log.getDisplayValue('device_history') +
            ' ecc=' + log.getValue('sensor') +
            ' message=' + log.getValue('short_message'));
})();
```

Follow the `sensor` reference to a bounded `ecc_queue` record and inspect name/topic/state/agent/timestamps/error. Never print payloads containing credentials or sensitive command output.

## Q23 — Inspect Service Mapping service membership and direct topology

```javascript
(function () {
    var serviceSysId = 'CHANGE_ME_SERVICE_SYS_ID';
    var svc = new GlideRecord('cmdb_ci_service_auto');
    if (!svc.get(serviceSysId)) throw 'Service Instance not found';
    gs.info('SERVICE ' + svc.getDisplayValue() +
        ' class=' + svc.getValue('sys_class_name') +
        ' operational_status=' + svc.getValue('operational_status'));

    var assoc = new GlideRecord('svc_ci_assoc');
    assoc.addQuery('service_id', serviceSysId);
    assoc.setLimit(500);
    assoc.query();
    while (assoc.next())
        gs.info('MEMBER ' + assoc.getValue('ci_id') + ' | ' + assoc.getDisplayValue('ci_id') +
            ' ignore_errors=' + assoc.getValue('ignore_errors'));

    var rel = new GlideRecord('cmdb_rel_ci');
    var qc = rel.addQuery('parent', serviceSysId);
    qc.addOrCondition('child', serviceSysId);
    rel.setLimit(200);
    rel.query();
    while (rel.next())
        gs.info('EDGE ' + rel.getDisplayValue('parent') +
            ' --' + rel.getDisplayValue('type') + '--> ' + rel.getDisplayValue('child'));
})();
```

Service maps can use both associations and relationships. Compare map method, entry points, last discovery, pattern errors, and underlying CI health before changing membership.

## Q24 — Narrow Scripted REST IRE resource pattern (mutating)

Use only in an approved scoped/global application with its own role and ACL. This intentionally supports one class and an allowlisted field contract.

```javascript
(function process(request, response) {
    var body = request.body.data || {};
    var source = 'CHANGE_ME_VALID_DISCOVERY_SOURCE';
    var allowedClass = 'cmdb_ci_server';
    var allowed = ['name', 'serial_number', 'short_description'];

    if (!gs.hasRole('CHANGE_ME_INGEST_ROLE')) {
        response.setStatus(403);
        response.setBody({status: 'not_authorized'});
        return;
    }
    if (body.className !== allowedClass || !body.sourceNativeKey) {
        response.setStatus(400);
        response.setBody({status: 'validation_failed', message: 'Unsupported class or missing sourceNativeKey'});
        return;
    }

    var values = {};
    allowed.forEach(function (field) {
        if (Object.prototype.hasOwnProperty.call(body.values || {}, field))
            values[field] = String(body.values[field]);
    });
    if (!values.name || !values.serial_number) {
        response.setStatus(400);
        response.setBody({status: 'validation_failed', message: 'name and serial_number are required'});
        return;
    }

    var payload = {items: [{
        className: allowedClass,
        internal_id: String(body.sourceNativeKey),
        values: values,
        settings: {updateWithoutDowngrade: true, updateWithoutSwitch: true},
        sys_object_source_info: {
            source_name: source,
            source_feed: 'CHANGE_ME_FEED',
            source_native_key: String(body.sourceNativeKey),
            source_recency_timestamp: body.sourceTimestamp || new GlideDateTime().getValue()
        }
    }]};

    var out;
    try {
        out = JSON.parse(SNC.IdentificationEngineScriptableApi.createOrUpdateCI(source, JSON.stringify(payload)));
    } catch (e) {
        gs.error('CMDB ingest failed correlation=' + request.getHeader('X-Correlation-ID') + ' error=' + e.message);
        response.setStatus(500);
        response.setBody({status: 'transient_or_platform_error'});
        return;
    }

    var item = out.items && out.items[0];
    if (!item || item.errorCount > 0) {
        response.setStatus(422);
        response.setBody({status: 'ire_rejected', errors: item ? item.errors : []});
        return;
    }

    response.setStatus(item.operation === 'INSERT' ? 201 : 200);
    response.setBody({
        status: item.operation === 'NO_CHANGE' ? 'already_complete' : 'complete',
        operation: item.operation,
        sysId: item.sysId || item.sys_id,
        warnings: item.warnings || []
    });
})(request, response);
```

Productionize with rate limits, request size limits, correlation/dead-letter strategy, source authentication, replay tests, and non-admin ACL tests. Do not turn this into a generic CMDB write proxy.

## Q25 — Flow Designer ingestion/remediation pattern

Use a custom Action with these steps:

1. Inputs: source-native key, allowlisted class/fields, source timestamp, optional relationship objects.
2. Script step: validate input and caller/runtime identity; build IRE payload; call a tested Script Include.
3. Output contract: operation, CI sys_id, warnings, errors, correlation ID, retryable boolean.
4. Decision: retry only transient errors; send validation/IRE conflicts to a governed review queue.
5. For dedup/reclass/Data Manager actions, produce a preview and approval task; invoke supported platform workflow only after approval.
6. Verify final CI/relationships and log a non-sensitive result. A successful Flow context alone is not proof.

## Q26 — Narrow Table API queries with the bundled helper

```powershell
# Static reconciliation definitions for one class
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table cmdb_reconciliation_definition `
  -Query 'applies_to=cmdb_ci_server^active=true^ORDERBYpriority' `
  -Fields 'name,applies_to,discovery_source,priority,attributes,null_update,condition,active' `
  -Limit 100 -ExcludeReferenceLink

# Recent health failures for one class
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table cmdb_health_result `
  -Query 'class_name=cmdb_ci_server^active=true^ORDERBYDESClast_evaluated_on' `
  -Fields 'ci,metric,source,discovery_source,last_evaluated_on,description' `
  -Limit 100 -ExcludeReferenceLink

# Data Manager executions for one resolved policy sys_id
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table cmdb_data_management_policy_execution `
  -Query 'cmdb_policy=CHANGE_ME_POLICY_SYS_ID^ORDERBYDESCstart_time' `
  -Fields 'number,execution_state,record_count,total_task_count,open_task_count,unassigned_task_count,completed_task_count,percent_complete,start_time,end_time' `
  -Limit 20 -ExcludeReferenceLink
```

Always resolve sys_ids live from a stable name/table key. Do not paste credentials into commands, scripts, or this reference.
