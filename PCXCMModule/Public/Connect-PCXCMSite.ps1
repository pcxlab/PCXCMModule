function Connect-PCXCMSite {
    param (
        [string]$SiteCode = $(Get-PCXCMSiteCode),
        [string]$ProviderMachineName = $(Get-PCXCMProviderMachineName)
    )

    # Optional: Add custom parameters for debugging or strict error handling
    $initParams = @{}
    # $initParams.Add("Verbose", $true)
    # $initParams.Add("ErrorAction", "Stop")

    # Import the ConfigurationManager module if not already loaded
    if ((Get-Module ConfigurationManager) -eq $null) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
    }

    # Connect to the site's drive if not already connected
    if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    }

    # Set the current location to the site drive
    Set-Location "$($SiteCode):\" @initParams
}
