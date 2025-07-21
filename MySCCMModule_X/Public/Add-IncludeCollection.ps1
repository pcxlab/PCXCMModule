# Add multiple collection function   
function Add-IncludeCollection {
    [CmdletBinding()]
    param (
        [string]$SelectCollectionName,
        [string[]]$IncludeCollectionNames
    )
try {
        # Get the target collections
        $SelectCollection = Get-CMDeviceCollection -Name $SelectCollectionName
if (-not $SelectCollection) {
            throw "$SelectCollectionName could not be found to add any collection."
        }
# Loop through the source collection names and add them to the target collection
        foreach ($IncludeCollectionName in $IncludeCollectionNames) {
try {
                $IncludeCollection = Get-CMDeviceCollection -Name $IncludeCollectionName
if ($IncludeCollection) {
                    Add-CMDeviceCollectionIncludeMembershipRule -CollectionId $SelectCollection.CollectionId -IncludeCollectionId $IncludeCollection.CollectionId
Write-Host "Successfully added '$($IncludeCollectionName)' to '$($SelectCollectionName)'." -ForegroundColor $ColScuccess
                }
                else {
                    Write-Host "Source collection '$($IncludeCollectionName)' not found." -ForegroundColor $ColInform
                }
}
            catch {
                Write-Host "Include collection '$IncludeCollectionName' to '$SelectCollectionName' got an Error: $_" -ForegroundColor $ColError
            }
        }
    }
    catch {
        Write-Host "Include collection '$IncludeCollectionName' to '$SelectCollectionName' got an Error: $_" -ForegroundColor $ColError
    }
}
