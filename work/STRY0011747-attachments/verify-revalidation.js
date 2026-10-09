(function(){
    if(gs.getProperty('instance_name')!='varenergitest')throw 'TEST only';
    var fixtures=[
        {table:'incident',id:'e92d2c8a44330314965df1f9b81ff3a1',child:'incident_task',parentField:'incident',title:'Supplier task - Incident attachment validation'},
        {table:'sc_req_item',id:'292dac8a44330314965df1f9b81ff39a',child:'sc_task',parentField:'request_item',title:'Supplier task - RITM attachment validation'}
    ];
    var proof=[];
    function content(id){
        var g=new GlideRecord('sys_attachment');g.addQuery('table_sys_id',id);g.orderBy('file_name');g.query();var r=[];
        while(g.next()){
            var reader=new GlideTextReader(new GlideSysAttachment().getContentStream(g.getUniqueValue()));
            var lines=[],line;while((line=reader.readLine())!==null)lines.push(String(line));
            r.push({name:g.getValue('file_name'),bytes:g.getValue('size_bytes'),content:lines.join('\n')});
        }
        return r;
    }
    fixtures.forEach(function(f){
        var p=new GlideRecord(f.table);if(!p.get(f.id))throw 'Parent missing';
        var c=new GlideRecord(f.child);c.addQuery(f.parentField,f.id);c.setLimit(2);c.query();if(!c.next())throw 'UI task missing';
        var cid=c.getUniqueValue(),number=c.getValue('number');if(c.next())throw 'Duplicate task';c.get(cid);
        if(c.getValue('short_description')!=f.title)throw 'Edited title lost';
        if(c.getValue('description').indexOf('TEST validation: copy all parent attachments automatically.')!==0)throw 'Edited description lost';
        if(c.getValue('description').indexOf('Caller: '+p[f.table=='incident'?'caller_id':'requested_for'].getDisplayValue())<0)throw 'Caller missing';
        ['impact','urgency','priority','service_offering'].forEach(function(field){if(p.isValidField(field)&&String(p.getValue(field)||'')!==String(c.getValue(field)||''))throw 'Inherited field differs: '+field;});
        var group=new GlideRecord('sys_user_group');if(!group.get(c.getValue('assignment_group'))||group.getValue('active')!='1'||!new SupplierTaskAjax()._isSupplierGroup(group))throw 'Supplier invalid';
        var j=new GlideRecord('sys_journal_field');j.addQuery('element_id',cid);j.query();var notes=false,comments=false;
        while(j.next()){
            if(j.getValue('element')=='work_notes'&&j.getValue('value')=='TEST validation for STRY0011747: automatic attachment copy.')notes=true;
            if(j.getValue('element')=='comments'&&j.getValue('value')=='Existing parent comment for TEST supplier-task validation.')comments=true;
        }
        var source=content(f.id),target=content(cid);
        if(source.length!=2||JSON.stringify(source)!=JSON.stringify(target)||!notes||!comments)throw 'UI outcome differs';
        proof.push({table:f.table,parent:p.getValue('number'),parentId:f.id,child:number,childId:cid,childTable:f.child,attachments:target.map(function(a){return {name:a.name,bytes:a.bytes};}),byteMatch:true,editedFields:true,inheritedFields:true,caller:true,workNotes:true,parentComments:true,validSupplier:true,ajax:true});
    });
    return JSON.stringify({instance:gs.getProperty('instance_name'),passed:true,tests:proof});
})();
