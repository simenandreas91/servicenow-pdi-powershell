(function () {
    var ALLOW_WRITE = false;
    var ALLOW_RERUN = false;
    var PREFIX = 'DFLAB-20260809-A';
    var SOURCE = 'Manual via IRE';
    var FEED = 'CMDB Data Foundations Lab ' + PREFIX;

    if (!ALLOW_WRITE)
        throw 'Write disabled. Confirm the ITOM Visibility batch is complete and review the no-commit IRE matrix first.';

    var existing = new GlideAggregate('cmdb_ci');
    existing.addQuery('name', 'STARTSWITH', PREFIX);
    existing.addAggregate('COUNT');
    existing.query();
    var existingCount = existing.next() ? parseInt(existing.getAggregate('COUNT'), 10) : 0;
    if (existingCount > 0 && !ALLOW_RERUN)
        throw 'Prefix already has ' + existingCount + ' CIs. Set ALLOW_RERUN only for the planned idempotency test.';

    function exactSysId(table, field, value) {
        var gr = new GlideRecord(table);
        gr.addQuery(field, value);
        if (gr.isValidField('active'))
            gr.addQuery('active', true);
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
    var now = new GlideDateTime();
    var stale = new GlideDateTime();
    stale.addDaysUTC(-120);

    function sourceInfo(key, timestamp) {
        return {
            source_name: SOURCE,
            source_feed: FEED,
            source_native_key: PREFIX + '-' + key,
            source_recency_timestamp: (timestamp || now).getValue()
        };
    }

    var payload = {
        items: [
            {
                className: 'cmdb_ci_service_auto',
                internal_id: 'service-prod',
      values: {
        name: PREFIX + ' Commerce - Production',
        // Australia + current Visibility content enforces a unique, non-empty
        // cmdb_ci_service.number (labelled "SN App Service ID") on insert.
        number: PREFIX + '-SVC-001',
        short_description: 'Data Foundations production service instance',
                    environment: 'Production',
                    install_status: '1',
                    operational_status: '1',
                    owned_by: owner,
                    managed_by_group: supportGroup,
                    support_group: supportGroup
                },
                sys_object_source_info: sourceInfo('service-prod')
            },
            {
                className: 'cmdb_ci_appl',
                internal_id: 'app-api',
                values: {
                    name: PREFIX + '-APP-API',
                    running_process_command: '/opt/dflab/bin/commerce-api',
                    running_process_key_parameters: '--env=prod',
                    version: '1.0.0',
                    short_description: 'Commerce API runtime',
                    environment: 'Production',
                    install_status: '1',
                    operational_status: '1',
                    owned_by: owner,
                    managed_by_group: supportGroup,
                    support_group: supportGroup
                },
                sys_object_source_info: sourceInfo('app-api')
            },
            {
                className: 'cmdb_ci_linux_server',
                internal_id: 'server-good',
                values: {
                    name: PREFIX + '-SRV-GOOD',
                    serial_number: PREFIX + '-SN-001',
                    short_description: 'Healthy production server',
                    environment: 'Production',
                    install_status: '1',
                    operational_status: '1',
                    last_discovered: now.getValue(),
                    owned_by: owner,
                    managed_by_group: supportGroup,
                    support_group: supportGroup
                },
                sys_object_source_info: sourceInfo('server-good')
            },
            {
                className: 'cmdb_ci_linux_server',
                internal_id: 'server-incomplete',
                values: {
                    name: PREFIX + '-SRV-INCOMPLETE',
                    serial_number: PREFIX + '-SN-002',
                    install_status: '1',
                    operational_status: '1',
                    last_discovered: now.getValue()
                },
                sys_object_source_info: sourceInfo('server-incomplete')
            },
            {
                className: 'cmdb_ci_linux_server',
                internal_id: 'server-stale',
                values: {
                    name: PREFIX + '-SRV-STALE',
                    serial_number: PREFIX + '-SN-003',
                    short_description: 'Intentionally stale production server',
                    environment: 'Production',
                    install_status: '1',
                    operational_status: '1',
                    last_discovered: stale.getValue(),
                    owned_by: owner,
                    managed_by_group: supportGroup,
                    support_group: supportGroup
                },
                sys_object_source_info: sourceInfo('server-stale', stale)
            }
        ],
        relations: [
            {parent: 0, child: 1, type: 'Depends on::Used by'},
            {parent: 1, child: 2, type: 'Runs on::Runs'},
            // Intentional non-dependent topology defect. The source is corrected
            // and this exact relationship is removed during the remediation phase.
            {parent: 4, child: 0, type: 'Depends on::Used by'}
        ]
    };

    var output = JSON.parse(
        SNC.IdentificationEngineScriptableApi.createOrUpdateCI(SOURCE, JSON.stringify(payload))
    );

    var failed = [];
    (output.items || []).forEach(function (item, index) {
        if (item.errorCount > 0)
            failed.push('item[' + index + '] ' + JSON.stringify(item.errors || []));
    });
    (output.relations || []).forEach(function (rel, index) {
        if (rel.errorCount > 0)
            failed.push('relation[' + index + '] ' + JSON.stringify(rel.errors || []));
    });
    if (failed.length)
        throw 'IRE rejected the lab payload: ' + failed.join('; ');

    gs.info('DFLAB_CREATE=' + JSON.stringify({
        prefix: PREFIX,
        source: SOURCE,
        feed: FEED,
        existing_before: existingCount,
        items: output.items || [],
        relations: output.relations || [],
        summary: output.summary || {}
    }));
})();
