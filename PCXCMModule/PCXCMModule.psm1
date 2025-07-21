# Load ConfigurationManager module globally if not already loaded
if (-not (Get-Module -Name ConfigurationManager)) {
    $cmModulePath = Join-Path -Path $env:SMS_ADMIN_UI_PATH -ChildPath "..\ConfigurationManager.psd1"
    
    if (Test-Path $cmModulePath) {
        Import-Module $cmModulePath -Global
    } else {
        Write-Warning "ConfigurationManager.psd1 not found. Please ensure the SCCM Admin Console is installed."
    }
}

# Load all private and public script files
$public  = @(Get-ChildItem "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in $private + $public) {
    . $file.FullName
}

# Export public functions
Export-ModuleMember -Function $public.BaseName

# Explicitly export internal color variables
Export-ModuleMember -Variable ColSuccess, ColError, ColInform
