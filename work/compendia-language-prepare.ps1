$ErrorActionPreference='Stop'
$r=Get-Content "$PSScriptRoot/compendia-language-before.json" -Raw | ConvertFrom-Json
$s=[string]$r.script
$changes=@(
 @("    if (!existing) return true;", "    if (!existing) return true;`n    // Correct language metadata even when the source content has not changed.`n    if (String(existing.getValue('language')) != this.languageForHandbook(page._handbook_slug)) return true;"),
 @("    gr.setValue('article_type', 'text');", "    gr.setValue('article_type', 'text');`n    gr.setValue('language', this.languageForHandbook(handbook.slug));"),
 @("    if (slug == 'employee' || slug == 'leadership-portal') return 'en';`n    return 'no';", "    // The Customer API currently omits language; handbook identity is the source.`n    // ServiceNow's Norwegian Bokmal choice is nb, not the generic no code.`n    if (slug == 'employee' || slug == 'leadership-portal') return 'en';`n    if (slug == 'personal' || slug == 'personal-offshore') return 'nb';`n    throw 'Compendia language mapping missing for handbook: ' + slug;")
)
foreach($c in $changes){
 if(($s.Split([string[]]@($c[0]),[StringSplitOptions]::None)).Count -ne 2){throw 'Unexpected source: replacement must occur once'}
 $s=$s.Replace($c[0],$c[1])
}
@{script=$s}|ConvertTo-Json -Depth 4|Set-Content "$PSScriptRoot/compendia-language-after.json"
Write-Output 'Prepared language mapping, staging code correction, and mismatch detection.'
