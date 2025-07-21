function Get-PCXCMProviderMachineName {
    [CmdletBinding()]
    param ()

    try {
        $namespace = "root\SMS"
        $siteClass = Get-WmiObject -Namespace $namespace -Class SMS_ProviderLocation -ErrorAction Stop |
                     Where-Object { $_.ProviderForLocalSite -eq $true }

        if ($null -eq $siteClass) {
            Write-Error "Could not find a local SCCM provider in WMI under namespace '$namespace'."
            return $null
        }

        return $siteClass.Machine
    } catch {
        Write-Error "Failed to retrieve SCCM provider machine name from WMI. $_"
        return $null
    }
}

