const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ctx = {Class:{create:()=>function(){}}};
vm.createContext(ctx);
vm.runInContext(JSON.parse(fs.readFileSync(__dirname+'/compendia-language-after.json','utf8').replace(/^\uFEFF/,'')).script,ctx);
const sync=Object.create(ctx.VECompendiaKnowledgeSync.prototype);
sync.getKnowledgeBaseSysId=()=> 'kb';
sync.targetWorkflowState=()=> 'draft';
sync.toGlideDateTime=x=>x;
sync.normalizeContent=x=>x;
sync.buildMeta=()=>'';
sync.tagNames=()=>'';
for(const [slug,language] of Object.entries({'employee':'en','leadership-portal':'en','personal':'nb','personal-offshore':'nb'})){
 assert.equal(sync.languageForHandbook(slug),language);
 const page={id:1,_handbook_slug:slug,modified:'2026-09-18',content:'Test'};
 const values={language,kb_knowledge_base:'kb',workflow_state:'draft',text:'Test',u_compendia_page_id:slug+':1',u_compendia_modified:page.modified};
 const existing={getValue:k=>values[k]};
 assert.equal(sync.needsSync(page,existing),false);
 values.language=language==='en'?'nb':'en';
 assert.equal(sync.needsSync(page,existing),true);
 const mapped={};
 sync.mapPageToArticle(page,{slug,name:slug},'kb',null,{setValue:(k,v)=>mapped[k]=v});
 assert.equal(mapped.language,language);
}
assert.throws(()=>sync.languageForHandbook('unknown'),/mapping missing/);
console.log('Passed all four mappings, unchanged/mismatched language detection, article mapping, unknown handbook rejection.');
