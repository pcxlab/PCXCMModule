function New-PCXCMCollectionInFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        [string]$LimitingCollection,

        [Parameter(Mandatory = $true)]
        [string]$FolderPath,

        [switch]$AutoCreateFolder
    )

    # Remove trailing backslash if any
    $FolderPath = $FolderPath.TrimEnd('\')

    if ($AutoCreateFolder) {
        $segments = $FolderPath -split '\\'
        $parentPath = ($segments[0..($segments.Length - 2)] -join '\')
        $folderName = $segments[-1]

        $created = New-PCXCMFolder -Path $parentPath -Name $folderName -AutoCreatePath
        if (-not $created) {
            Write-Host "Failed to create folder path '$FolderPath'. Aborting collection creation." -ForegroundColor $ColError
            return
        }
    }

    # Check if the collection already exists
    $existingCollection = Get-CMDeviceCollection -Name $CollectionName
    if (-not $existingCollection) {
        New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection > $null
        Write-Host "Collection '$CollectionName' with limiting '$LimitingCollection' created successfully." -ForegroundColor $ColSuccess
    } else {
        Write-Host "Collection '$CollectionName' already exists." -ForegroundColor $ColInform
    }

    # Move the collection to the specified folder
    $collectionObject = Get-CMDeviceCollection -Name $CollectionName
    #$siteFolderPath = "$SiteCode:\$FolderPath"
    $siteFolderPath = "$siteCode" + ":\$FolderPath"
    Move-CMObject -FolderPath $siteFolderPath -InputObject $collectionObject
    Write-Host "Collection '$CollectionName' moved to '$siteFolderPath'." -ForegroundColor $ColSuccess
}
