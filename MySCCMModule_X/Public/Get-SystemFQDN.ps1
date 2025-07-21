function Get-SystemFQDN {
    [CmdletBinding()]
    param()
    try {
        return [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
    } catch {
        Throw "Error retrieving FQDN: $_"
    }
}
