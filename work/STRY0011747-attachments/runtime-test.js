(function () {
    var instance = gs.getProperty('instance_name');
    if (instance != 'varenergidev' && instance != 'varenergitest')
        throw 'Runtime test is restricted to DEV and TEST.';
    var originalUser = gs.getUserID();
    var impersonation = new GlideImpersonate();
    var created = [], results = [], errors = [];
    var group = new GlideRecord('sys_user_group');
    group.addQuery('name', 'Sopra Steria - Servicedesk IT - 1st Line');
    group.addActiveQuery();
    group.setLimit(2);
    group.query();
    if (!group.next()) throw 'Expected supplier group missing.';
    var groupId = group.getUniqueValue();
    if (group.next()) throw 'Supplier group ambiguous.';
    var connection = new GlideRecord('x_vaea2_supplier_0_connection');
    var integrationInstalled = connection.isValid();
    if (integrationInstalled) {
        connection.addQuery('groups', 'CONTAINS', groupId);
        connection.setLimit(1);
        connection.query();
        if (connection.hasNext()) throw 'Test supplier has an outbound connection.';
    }
    var person = new GlideRecord('sys_user');
    person.addQuery('user_name', 'alexander.nguyen@varenergi.no');
    person.addActiveQuery();
    person.setLimit(2);
    person.query();
    if (!person.next()) throw 'ITIL test persona missing.';
    var itilUser = person.getUniqueValue();
    if (person.next()) throw 'ITIL persona ambiguous.';
    var deniedUser = '';
    var candidate = new GlideRecord('sys_user');
    candidate.addActiveQuery();
    candidate.addQuery('user_name', 'NOT LIKE', 'admin');
    candidate.addQuery('user_name', 'CONTAINS', '@varenergi.no');
    candidate.setLimit(50);
    candidate.query();
    while (candidate.next() && !deniedUser) {
        var roles = new GlideRecord('sys_user_has_role');
        roles.addQuery('user', candidate.getUniqueValue());
        roles.addQuery('role.name', 'IN', 'admin,itil,security_admin,sn_request_write,sn_incident_write');
        roles.setLimit(1);
        roles.query();
        if (!roles.hasNext()) deniedUser = candidate.getUniqueValue();
    }
    if (!deniedUser) throw 'Denied persona missing.';
    function assert(ok, message) { if (!ok) throw message; }
    function attachments(id) {
        var a = new GlideRecord('sys_attachment');
        a.addQuery('table_sys_id', id);
        a.orderBy('file_name');
        a.query();
        var rows = [];
        while (a.next()) {
            var content = new GlideSysAttachment().getContentStream(a.getUniqueValue());
            var reader = new GlideTextReader(content), text = [], line;
            while ((line = reader.readLine()) !== null) text.push(String(line));
            rows.push({name:a.getValue('file_name'),size:a.getValue('size_bytes'),content:text.join('\n')});
        }
        return rows;
    }
    function parent(table, attachmentCount) {
        var p = new GlideRecord(table);
        p.initialize();
        p.short_description = 'STRY0011747 attachment validation';
        p.description = 'Synthetic parent description';
        p.impact = 2;
        p.urgency = 2;
        p.priority = 3;
        p.opened_by = itilUser;
        p[table == 'incident' ? 'caller_id' : 'requested_for'] = itilUser;
        p.setWorkflow(false);
        var id = p.insert();
        assert(!!id, 'Could not create synthetic parent.');
        created.push({table:table,id:String(id)});
        for (var i=0; i<attachmentCount; i++)
            new GlideSysAttachment().write(p, 'attachment-'+i+'.txt', 'text/plain', 'Synthetic attachment '+i+'\n');
        var journal = new GlideRecord('sys_journal_field');
        journal.initialize();
        journal.name = table;
        journal.element = 'comments';
        journal.element_id = id;
        journal.value = 'Synthetic existing parent comment';
        journal.setWorkflow(false);
        journal.insert();
        return String(id);
    }
    function call(table, id, attachmentParameter, supplierId) {
        var processor = new SupplierTaskAjax();
        var parameters = {
            sysparm_table:table,sysparm_parent:id,sysparm_supplier:supplierId || groupId,
            sysparm_short_description:'Edited supplier task title',sysparm_description:'Edited description',
            sysparm_work_notes:'Synthetic supplier work note'
        };
        if (attachmentParameter !== null) parameters.sysparm_include_attachments = attachmentParameter;
        processor.getParameter = function(name) {
            return parameters[name] === undefined ? null : parameters[name];
        };
        return String(processor.createTask());
    }
    function count(table, id) {
        var aggregate = new GlideAggregate(table);
        aggregate.addQuery(table == 'incident_task' ? 'incident' : 'request_item', id);
        aggregate.addAggregate('COUNT');
        aggregate.query();
        return aggregate.next() ? parseInt(aggregate.getAggregate('COUNT'),10) : 0;
    }
    try {
        ['incident','sc_req_item'].forEach(function(table) {
            [{count:2,param:'false'},{count:2,param:null},{count:0,param:'false'}].forEach(function(test) {
                var id = parent(table,test.count);
                var childTable = table == 'incident' ? 'incident_task' : 'sc_task';
                impersonation.impersonate(itilUser);
                assert(!gs.getUser().hasRole('admin') && gs.getUser().hasRole('itil'), 'Persona is not non-admin ITIL.');
                var response = call(table,id,test.param);
                impersonation.impersonate(originalUser);
                assert(response.indexOf('success:') === 0, 'Task creation failed: '+response);
                var child = new GlideRecord(childTable);
                child.addQuery(childTable == 'incident_task' ? 'incident' : 'request_item',id);
                child.setLimit(2);
                child.query();
                assert(child.next(),'Child task not found.');
                var childId=child.getUniqueValue();
                created.push({table:childTable,id:childId});
                assert(!child.next(),'Duplicate child task.');
                child.get(childId);
                assert(child.getValue('short_description') == 'Edited supplier task title','Edited title lost.');
                assert(child.getValue('description').indexOf('Edited description') === 0,'Edited description lost.');
                assert(child.getValue('assignment_group') == groupId,'Supplier assignment lost.');
                assert(child.getValue('impact') == '2' && child.getValue('urgency') == '2' && child.getValue('priority') == '3','Priority fields lost.');
                var journals = new GlideRecord('sys_journal_field');
                journals.addQuery('element_id',childId);
                journals.query();
                var comments=false, notes=false;
                while(journals.next()) {
                    if(journals.getValue('element') == 'comments' && journals.getValue('value') == 'Synthetic existing parent comment') comments=true;
                    if(journals.getValue('element') == 'work_notes' && journals.getValue('value') == 'Synthetic supplier work note') notes=true;
                }
                assert(comments && notes,'Comments/work notes regression.');
                var source=attachments(id), target=attachments(childId);
                assert(source.length == test.count && JSON.stringify(source) == JSON.stringify(target),'Attachment bytes/count differ.');
                var tx = new GlideRecord('x_vaea2_supplier_0_transaction_queue');
                if (tx.isValid()) {
                    tx.addQuery('document_id',childId);tx.setLimit(1);tx.query();
                    assert(!tx.hasNext(),'Unexpected outbound supplier transaction.');
                }
                results.push({table:table,parameter:test.param,attachments:target.length,nonAdmin:true,fields:true,journals:true,bytes:true,outbound:0});
            });
            var negativeId=parent(table,0), childTable=table == 'incident' ? 'incident_task' : 'sc_task';
            impersonation.impersonate(deniedUser);
            var denied=call(table,negativeId,'false');
            impersonation.impersonate(originalUser);
            assert(denied.indexOf('error: You do not have permission') === 0 && count(childTable,negativeId) === 0,'Deny persona was not rejected.');
            impersonation.impersonate(itilUser);
            var invalid=call(table,negativeId,'false','00000000000000000000000000000000');
            impersonation.impersonate(originalUser);
            assert(invalid == 'error: Select an active supplier group.' && count(childTable,negativeId) === 0,'Invalid supplier was not rejected.');
            results.push({table:table,deniedPersona:true,invalidSupplier:true});
        });
    } catch(e) { errors.push(String(e)); }
    finally {
        impersonation.impersonate(originalUser);
        created.reverse().forEach(function(item) {
            var c = new GlideRecord(item.table);
            if(c.get(item.id)) {
                var a = new GlideSysAttachment().getAttachments(item.table,item.id);
                while(a.next()) new GlideSysAttachment().deleteAttachment(a.getUniqueValue());
                c.setWorkflow(false);c.deleteRecord();
            }
            var journal = new GlideRecord('sys_journal_field');journal.addQuery('element_id',item.id);journal.setWorkflow(false);journal.deleteMultiple();
        });
    }
    var remaining=[];
    created.forEach(function(item){var c=new GlideRecord(item.table);if(c.get(item.id))remaining.push(item);});
    return JSON.stringify({instance:instance,integrationInstalled:integrationInstalled,tests:results,errors:errors,temporaryRecords:created.length,remaining:remaining,identityRestored:gs.getUserID()==originalUser,passed:errors.length===0&&remaining.length===0&&results.length===8});
})();
