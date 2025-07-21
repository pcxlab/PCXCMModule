# MySCCMModule.psm1
$public  = @(Get-ChildItem "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in $public + $private) { . $file.FullName }

Export-ModuleMember -Function $public.BaseName
