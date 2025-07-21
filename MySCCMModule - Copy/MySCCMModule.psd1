@{
    RootModule       = 'MySCCMModule.psm1'
    ModuleVersion    = '1.0.0'
    GUID             = '27614218-a996-40b8-9cba-785416c87c34'
    Author           = 'YourName'
    Description      = 'SCCM helper functions module'
    FunctionsToExport = @('Get-YearMonth', 'Get-AbbreviatedMonthName',
                          'Get-SCCMSiteCode', 'Get-SystemFQDN',
                          'Create-Folder','Create-And-MoveCMCollection',
                          'Add-CMDeviceCollectionQueryMembershipRuleWithQuery',
                          'Add-IncludeCollection','Add-ExcludeCollection')
    PrivateData      = @{
        PSData = @{
            Tags = @('SCCM','Helper')
        }
    }
}
