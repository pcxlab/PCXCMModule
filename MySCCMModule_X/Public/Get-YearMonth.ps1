function Get-YearMonth {
    [CmdletBinding()]
    param()
    $now = Get-Date
    return "{0}-{1:00}" -f $now.Year, $now.Month
}
