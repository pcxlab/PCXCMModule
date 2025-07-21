function Get-AbbreviatedMonthName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][datetime] $Date
    )
    return $Date.ToString('MMM')
}
