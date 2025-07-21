# Safely get public and private files
$public  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

# Dot-source all functions
foreach ($file in $public + $private) {
    . $file.FullName
}

# Export only public functions
Export-ModuleMember -Function $public.BaseName
