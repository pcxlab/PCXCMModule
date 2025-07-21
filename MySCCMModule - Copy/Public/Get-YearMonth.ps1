function Get-YearMonth {
    [CmdletBinding()]
    param()
    $now = Get-Date
    $year = $now.Year
    $month = $now.Month.ToString("00")
    return "$year-$month"
}
