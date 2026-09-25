(function () {
 var out={instance:gs.getProperty('instance_name'),languages:[],triggers:[],errors:[]};
 var a=new GlideAggregate('kb_knowledge');
 a.addNotNullQuery('u_compendia_page_id');a.addAggregate('COUNT');a.groupBy('language');a.query();
 while(a.next())out.languages.push({language:String(a.language),count:a.getAggregate('COUNT')});
 var t=new GlideRecord('sys_trigger');t.addQuery('name','CONTAINS','Compendia');t.setLimit(10);t.query();
 while(t.next())out.triggers.push({id:String(t.sys_id),name:String(t.name),state:String(t.state),next:String(t.next_action),error:String(t.last_error)});
 var e=new GlideRecord('u_compendia_import_staging');e.addQuery('u_sync_state','error');e.setLimit(30);e.query();
 while(e.next())out.errors.push({key:String(e.u_external_key),error:String(e.u_error_message),updated:String(e.sys_updated_on)});
 return JSON.stringify(out);
})()
