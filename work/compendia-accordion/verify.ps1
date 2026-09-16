$ErrorActionPreference='Stop'
$root=Resolve-Path "$PSScriptRoot/../.."
$targets=@(
  @('vaar_dev','varenergidev'), @('vaar_test','varenergitest'),
  @('vaar_prod','varenergiprod'), @('other','varenergisandbox')
)
$script=@'
(function(){
 var g=new GlideRecord('kb_knowledge');g.addQuery('u_compendia_page_id','employee:1250551');g.setLimit(3);g.query();
 var out=[];while(g.next()){
  var html=String(g.text);var titles=[];var re=/<summary[^>]*>([\s\S]*?)<\/summary>/g;var m;
  while((m=re.exec(html))!==null)titles.push(m[1].replace(/<span[\s\S]*$/,'').replace(/<[^>]+>/g,''));
  out.push({number:String(g.number),sys_id:String(g.sys_id),state:String(g.workflow_state),titles:titles});
 }
 return JSON.stringify({instance:gs.getProperty('instance_name'),articles:out});
})()
'@
foreach($t in $targets){
 & "$root/scripts/Invoke-ServiceNowXploreScript.ps1" -Profile $t[0] -Instance "https://$($t[1]).service-now.com" -EnvPath 'C:\Users\simen\Documents\Codex\ServiceNow\.env' -Script $script
}
