function Get-PCXShortMonthName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][datetime] $Date
    )
    return $Date.ToString('MMM')
}
