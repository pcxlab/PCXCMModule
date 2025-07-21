function Initialize-SCCMEnvironment {
    param (
        [string]$SiteCode,
        [string]$ProviderMachineName
    )

    $initParams = @{}
    # $initParams.Add("Verbose", $true)
    # $initParams.Add("ErrorAction", "Stop")

    if (-not (Get-Module ConfigurationManager)) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
    }

    if (-not (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    }

    Set-Location "$($SiteCode):\" @initParams
}
