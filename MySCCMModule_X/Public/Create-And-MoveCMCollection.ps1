# Define the function to create SCCM collections and move them 

Function Create-And-MoveCMCollection {
    param(
        [string]$CollectionName,
        [string]$LimitingCollection,
        [string]$FolderPath
    )
# Check if the collection already exists
    $existingCollection = Get-CMDeviceCollection -Name $CollectionName
if (-not $existingCollection) {
        # Collection does not exist, so create it
        New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollection > $null
        Write-Host "Collection '$CollectionName' with limiting '$LimitingCollection' Created successfully" -ForegroundColor $ColScuccess
    }
    else {
        Write-Host "Collection '$CollectionName' already exists." -ForegroundColor $ColInform
    }
# Get the collection object
    $collectionObject = Get-CMDeviceCollection -Name $CollectionName
# Get the site code (uncomment if required)
    # $siteCode = (Get-CMSite).SiteCode
# Check if $siteCode is defined (uncomment if required)
    # if (-not $siteCode) {
    #     Write-Host "Site code is not defined. Please make sure to uncomment and provide a value for $siteCode."
    #     return
    # }
# Construct the site folder path
    $siteFolderPath = "$siteCode" + ":\$FolderPath"
# Move the collection to the specified folder
    Move-CMObject -FolderPath $siteFolderPath -InputObject $collectionObject
    Write-Host "Collection '$CollectionName' is Moved to '$siteFolderPath\'"
}