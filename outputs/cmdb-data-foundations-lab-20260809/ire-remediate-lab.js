(function () {
    var ALLOW_WRITE = false;
    var PREFIX = 'DFLAB-20260809-A';
    var SOURCE = 'Manual via IRE';
    var FEED = 'CMDB Data Foundations Lab ' + PREFIX;

    if (!ALLOW_WRITE)
        throw 'Write disabled. Capture the pre-remediation health and topology evidence first.';

    function exactSysId(table, field, value) {
        var gr = new GlideRecord(table);
        gr.addQuery(field, value);
        gr.setLimit(2);
        gr.query();
        if (!gr.next())
            throw 'Required record not found: ' + table + '.' + field + '=' + value;
        var id = gr.getUniqueValue();
        if (gr.next())
            throw 'Required lookup is not unique: ' + table + '.' + field + '=' + value;
        return id;
    }

    var supportGroup = exactSysId('sys_user_group', 'name', 'Service Desk');
    var owner = exactSysId('sys_user', 'user_name', 'admin');
    var serviceId = exactSysId('cmdb_ci_service_auto', 'name', PREFIX + ' Commerce - Production');
    var staleId = exactSysId('cmdb_ci_linux_server', 'name', PREFIX + '-SRV-STALE');
    exactSysId('cmdb_ci_linux_server', 'name', PREFIX + '-SRV-INCOMPLETE');

    var now = new GlideDateTime();
    function sourceInfo(key) {
        return {
            source_name: SOURCE,
            source_feed: FEED,
            source_native_key: PREFIX + '-' + key,
            source_recency_timestamp: now.getValue()
        };
    }

    var payload = {
        items: [
            {
                className: 'cmdb_ci_linux_server',
                internal_id: 'server-incomplete',
                values: {
                    name: PREFIX + '-SRV-INCOMPLETE',
                    serial_number: PREFIX + '-SN-002',
                    short_description: 'Remediated production server',
                    environment: 'Production',
                    install_status: '1',
                    operational_status: '1',
                    last_discovered: now.getValue(),
                    owned_by: owner,
                    managed_by_group: supportGroup,
                    support_group: supportGroup
                },
                sys_object_source_info: sourceInfo('server-incomplete')
            },
            {
                className: 'cmdb_ci_linux_server',
                internal_id: 'server-stale',
                values: {
                    name: PREFIX + '-SRV-STALE',
                    serial_number: PREFIX + '-SN-003',
                    short_description: 'Refreshed production server',
                    environment: 'Production',
                    install_status: '1',
                    operational_status: '1',
                    last_discovered: now.getValue(),
                    owned_by: owner,
                    managed_by_group: supportGroup,
                    support_group: supportGroup
                },
                sys_object_source_info: sourceInfo('server-stale')
            }
        ]
    };

    var ireOutput = JSON.parse(
        SNC.IdentificationEngineScriptableApi.createOrUpdateCI(SOURCE, JSON.stringify(payload))
    );
    var failed = (ireOutput.items || []).filter(function (item) {
        return item.errorCount > 0;
    });
    if (failed.length)
        throw 'IRE rejected remediation: ' + JSON.stringify(failed);

    var relTypeId = exactSysId('cmdb_rel_type', 'name', 'Depends on::Used by');
    var wrong = new GlideRecord('cmdb_rel_ci');
    wrong.addQuery('parent', staleId);
    wrong.addQuery('child', serviceId);
    wrong.addQuery('type', relTypeId);
    wrong.setLimit(2);
    wrong.query();
    if (!wrong.next())
        throw 'Intentional incorrect relationship was not found; no relationship was deleted.';
    var wrongRel = {
        sys_id: wrong.getUniqueValue(),
        parent: wrong.getValue('parent'),
        child: wrong.getValue('child'),
        type: wrong.getValue('type')
    };
    if (wrong.next())
        throw 'More than one incorrect relationship matched; no relationship was deleted.';

    var deleteCheck = new GlideRecord('cmdb_rel_ci');
    if (!deleteCheck.get(wrongRel.sys_id))
        throw 'Incorrect relationship disappeared before deletion.';
    if (deleteCheck.getValue('parent') !== staleId ||
        deleteCheck.getValue('child') !== serviceId ||
        deleteCheck.getValue('type') !== relTypeId)
        throw 'Incorrect relationship changed before deletion.';
    deleteCheck.deleteRecord();

    var verify = new GlideRecord('cmdb_rel_ci');
    var relationRemoved = !verify.get(wrongRel.sys_id);
    if (!relationRemoved)
        throw 'Incorrect relationship still exists after the exact delete.';

    gs.info('DFLAB_REMEDIATE=' + JSON.stringify({
        prefix: PREFIX,
        items: ireOutput.items || [],
        removed_relationship: wrongRel,
        relationship_removed: relationRemoved
    }));
})();
