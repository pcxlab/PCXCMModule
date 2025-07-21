
# Multiple exclude collection  
function Add-ExcludeCollection {
    [CmdletBinding()]
    param (
        [string]$SelectCollectionName,
        [string[]]$ExcludeCollectionNames
    )
try {
        # Get the target collections
        $SelectCollection = Get-CMDeviceCollection -Name $SelectCollectionName
if (-not $SelectCollection) {
            throw "$SelectCollectionName could not be found to add any collection."
        }
# Loop through the source collection names and add them to the target collection
        foreach ($ExcludeCollectionName in $ExcludeCollectionNames) {
try {
                $ExcludeCollection = Get-CMDeviceCollection -Name $ExcludeCollectionName
if ($ExcludeCollection) {
                    Add-CMDeviceCollectionExcludeMembershipRule -CollectionId $SelectCollection.CollectionId -ExcludeCollectionId $ExcludeCollection.CollectionId
Write-Host "Successfully added '$($ExcludeCollectionName)' to '$($SelectCollectionName)' as Exclude Membership." -ForegroundColor $ColScuccess
                }
                else {
                    Write-Host "Source collection '$($ExcludeCollectionName)' not found." -ForegroundColor $ColInform
                }
}
            catch {
                Write-Host "Exclude collection '$ExcludeCollectionName' to '$SelectCollectionName' got an Error: $_" -ForegroundColor $ColError
            }
        }
    }
    catch {
        Write-Host "Exclude collection '$ExcludeCollectionName' to '$SelectCollectionName' got an Error: $_" -ForegroundColor $ColError
    }
}