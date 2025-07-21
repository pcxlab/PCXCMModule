function Get-SCCMSiteCode {
    [CmdletBinding()]
    param()
    try {
        $siteObj = Get-WmiObject -Namespace 'Root\SMS' -Class SMS_ProviderLocation -ComputerName '.'
        $code = if ($siteObj -is [array]) { $siteObj[0].SiteCode } else { $siteObj.SiteCode }
        return $code
    } catch {
        Throw "Error retrieving SCCM site code: $_"
    }
}
