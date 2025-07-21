<#
.SYNOPSIS
    PowerShell Automated Collection Creation Script for SCCM deployments 
.DESCRIPTION
    This PowerShell script automates the process of creating collections for SCCM deployments. 
    It streamlines collection creation, query addition, membership management (including inclusion and exclusion), 
    and selection of limiting collections. The script includes robust error handling and informative user messages. 
    It also verifies the availability of specified include collections and organizes collections within console folders.
.FEATURES
    - Automated collection creation and management
    - Error handling with user-friendly messages
    - Verification of include collection availability
    - Organizes collections within console folders
    - Automatic date capture and conversion
.STATISTICS
    - Total Folders Created: xx
    - Total Collections Created: xx
    - Total Queries Created: xx
    - Total Include Memberships Created: xx
    - Total Exclude Memberships Created: xx
    - Total Collection Movements: xx
    - Total Lines of Code: <500 (subject to functional additions or deletions)
.AUTHOR
    RB HR
.TESTERS
    RB HR
.APROVALS
    Pre Reseles Beta Versions
.LASTMODIFIED
    10 Jan 2023
.NOTES
    Version: 2.4.9
- Last modified: 17 Jun 2025

SMS Collections_V25.01 = added index 0 to SiteCode - geting double index of SiteCode 
function Get-SCCMSiteCode Updated Index 
return $siteCode[0]

#>
# Program begins here... NJoy...
# Function to get Year and month Automatic  #...............................................................................................................................................................................
function Get-YearMonth {
    $now = Get-Date
    $year = $now.Year
    $month = $now.Month.ToString("00")
    return "$year-$month"
}
$yearMonth = Get-YearMonth
Write-Output "Current Year and Month: $yearMonth"
# Function to get the month name abbreviated Month Name  #...............................................................................................................................................................................
function Get-AbbreviatedMonthName {
    param(
        [datetime]$date
    )
$abbreviatedMonth = $date.ToString("MMM")
    return $abbreviatedMonth
}
$today = Get-Date
$abbreviatedMonth = Get-AbbreviatedMonthName -date $today
Write-Host "Abbreviated Month Name: $abbreviatedMonth"

# Forground Color code
$ColScuccess = "Green"
$ColError = "Red"
$ColInform = "Yellow"

# Site configuration
# $SiteCode = "EZY" # Site code 
# Get SCCM Site code

function Get-SCCMSiteCode {
    try {
        $siteCode = Get-WmiObject -Namespace "Root\SMS" -Class SMS_ProviderLocation -ComputerName "." | Select-Object -ExpandProperty SiteCode
        if ($siteCode -ne $null) {
            if ($siteCode -is [array]) {
                return $siteCode[0]
            } else {
                return $siteCode
            }
        } else {
            Write-Output "SCCM Site Code not found."
            return $null
        }
    } catch {
        Write-Error "Error retrieving SCCM Site Code: $_"
        return $null
    }
}

# Call the function and assign the result to a variable
$SiteCode = Get-SCCMSiteCode

# Check if the site code was retrieved successfully
if ($SiteCode -ne $null) {
    Write-Output "Assigned SCCM Site Code is: $SiteCode"
} else {
    Write-Output "Failed to retrieve SCCM Site Code."
    exit 0
}

# FQDN
# $ProviderMachineName = "SESRVER.eaz.net" # SMS Provider machine name

# Get FQDN
function Get-SystemFQDN {
    try {
        $fqdn = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName
        if ($fqdn -ne $null) {
            return $fqdn
        } else {
            Write-Output "FQDN not found."
            return $null
        }
    } catch {
        Write-Error "Error retrieving FQDN: $_"
        return $null
    }
}

# Call the function and assign the result to a variable
$ProviderMachineName = Get-SystemFQDN

# Check if the FQDN was retrieved successfully
if ($ProviderMachineName -ne $null) {
    Write-Output "Assigned FQDN is: $ProviderMachineName"
} else {
    Write-Output "Failed to retrieve FQDN."
    exit 0
}

# Test Site Config
# $SiteCode = "PS1" # Site code 
# $ProviderMachineName = "CM01.corp.pcxlab.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors
# Do not change anything below this line
# Import the ConfigurationManager.psd1 module 
if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}
# Connect to the site's drive if it is not already present
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}
# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams
# Function to create folder under sccm console #...............................................................................................................................................................................


function Create-Folder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [switch]$AutoCreatePath
    )

    $Path = $Path.Trim('\')
    $rootPath = "$($SiteCode):"
    $segments = $Path -split '\\'
    $currentPath = $rootPath

    try {
        if ($AutoCreatePath) {
            foreach ($folder in $segments) {
                $nextPath = Join-Path -Path $currentPath -ChildPath $folder
                if (-not (Test-Path $nextPath)) {
                    New-Item -Path $currentPath -Name $folder -ItemType Directory -ErrorAction Stop
                    Write-Verbose "Created path segment: $nextPath"
                }
                $currentPath = $nextPath
            }
        } else {
            $currentPath = Join-Path -Path $rootPath -ChildPath ($segments -join '\')
            if (-not (Test-Path $currentPath)) {
                throw "Path '$Path' does not exist. Use -AutoCreatePath to create it."
            }
        }

        $finalPath = Join-Path -Path $currentPath -ChildPath $Name

        if (-not (Test-Path $finalPath)) {
            New-Item -Path $currentPath -Name $Name -ItemType Directory -ErrorAction Stop
            Write-Host "✅ Folder '$Name' created at '$Path'." -ForegroundColor $ColScuccess
            return $true
        } else {
            Write-Host "ℹ️ Folder '$Name' already exists at '$Path'." -ForegroundColor $ColInform
            return $false
        }
    } catch {
        Write-Host "❌ Error creating folder '$Name' at '$Path': $_" -ForegroundColor $ColError
        return $false
    }
}

# Define the function to create SCCM collections and move them  #...............................................................................................................................................................................
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
# Create and move first SCCM collection
# Usage example
# Create-And-MoveCMCollection -CollectionName "MS Update - $yearMonth - EZY - Wkstn_RPA_NonProd [Install] EZY" -LimitingCollection "All EY RPA/BOT Machines EZY" -FolderPath "DeviceCollection\Security Management Services\Deployments\MS Update - $yearMonth - EZY - Wkstn & WVD"

#Function to Add Query membership   #...............................................................................................................................................................................
Function Add-CMDeviceCollectionQueryMembershipRuleWithQuery {
    Param(
        [string]$CollectionName,
        [string]$QueryExpression,
        [string]$RuleName
    )
Add-CMDeviceCollectionQueryMembershipRule -CollectionName $CollectionName -QueryExpression $QueryExpression -RuleName $RuleName
}

# Add multiple collection function   #...............................................................................................................................................................................
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

# Multiple exclude collection  #...............................................................................................................................................................................
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
#Add Exclde Membership

# Create folder 
Create-Folder -Path "$($SiteCode):\DeviceCollection\Security Management Services\Deployments" -Name "MS 365 Apps 2402P Update - $yearMonth - EZY - Wkstn"
# Create and move first SCCM collection
Create-And-MoveCMCollection -CollectionName "MS 365 Apps 2402P Update - $yearMonth - EZY - Wkstn [Install] EZY" -LimitingCollection "MS 365 Apps Semi-Annual Enterprise Channel (Preview) CDN" -FolderPath "DeviceCollection\Security Management Services\Deployments\MS 365 Apps 2402P Update - $yearMonth - EZY - Wkstn"
# Add multiple include collection
Add-IncludeCollection -SelectCollectionName "MS 365 Apps 2402P Update - $yearMonth - EZY - Wkstn [Install] EZY" -IncludeCollectionNames @("MS 365 Apps Semi-Annual Enterprise Channel (Preview) 2402 x86", "MS 365 Apps Semi-Annual Enterprise Channel (Preview) 2402 x64")
# Add Exclde Membership
Add-ExcludeCollection -SelectCollectionName "MS 365 Apps 2402P Update - $yearMonth - EZY - Wkstn [Install] EZY" -ExcludeCollectionNames @("Desktop Testing Team EZY")
#/          /          /          /          /          /          /          /          /          /          /          /          /          /          /          /          /          /          /

##################################


# Create folder 
Create-Folder -Path "DeviceCollection\Reusable Collections\" -Name "5 Percent Sets" -AutoCreatePath

# Add query to the collection
Create-And-MoveCMCollection -CollectionName "Phase Collection Testing 5% Phase1" -LimitingCollection "All Systems" -FolderPath "DeviceCollection\Test Collections\Deployments"

#DeviceCollection\Test Collections\Deployments
$WVDQuery = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ResourceId in (select resourceid from SMS_FullCollectionMembership where CollectionID IN ("EZY05506"))'

Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "Phase Collection Testing 5% Phase1" -QueryExpression $WVDQuery -RuleName "WVD machines"
# Create and move first SCCM collection


Create-Folder -Path "DeviceCollection\Test Collections\Deployments\ABV" -Name "Three1" -VerboseOutput\

Create-Folder -Path "DeviceCollection\Test Collections\Deployments\ABV\cas\we\longpath\missin" -Name "Three1" 


 
Create-Folder -Path "DeviceCollection\Test Collections\Deployments\" -Name "ThreeFol1"
Create-Folder -Path "DeviceCollection\Test Collections\Deployments" -Name "ThreeFol1"
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder" -Name "Xyz"
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\" -Name "Xyz" -AutoCreatePath
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder" -Name "Xyz" -AutoCreatePath


Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder" -Name "Xyzz"
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\" -Name "Xyzz"
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\" -Name "Xyzza"

Create-Folder -Path "DeviceCollection\Test Collections\Deep\Sub\Folder" -Name "MyFolder" -AutoCreatePath -Verbose
Create-Folder -Path "DeviceCollection\Test Collections\Missing" -Name "AnotherFolder"


# Works cleanly
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\" -Name "Xyzza"
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder" -Name "Xyzza"

# Also works now — trailing backslash removed internally
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\b\" -Name "Xyzza" -AutoCreatePath
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\b\c\d" -Name "Xyzza" -AutoCreatePath

Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder\" -Name "Xyzzb"
Create-Folder -Path "DeviceCollection\Test Collections\Missing\Subfolder" -Name "Xyzzb"


######################################


Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_01" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set1_DEC_1to13_HEX_01to0D = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%01" or SMS_R_System.SMSUniqueIdentifier like "%02" or SMS_R_System.SMSUniqueIdentifier like "%03" or SMS_R_System.SMSUniqueIdentifier like "%04" or SMS_R_System.SMSUniqueIdentifier like "%05" or SMS_R_System.SMSUniqueIdentifier like "%06" or SMS_R_System.SMSUniqueIdentifier like "%07" or SMS_R_System.SMSUniqueIdentifier like "%08" or SMS_R_System.SMSUniqueIdentifier like "%09" or SMS_R_System.SMSUniqueIdentifier like "%0A" or SMS_R_System.SMSUniqueIdentifier like "%0B" or SMS_R_System.SMSUniqueIdentifier like "%0C" or SMS_R_System.SMSUniqueIdentifier like "%0D"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_01" -QueryExpression $Percent05_Set1_DEC_1to13_HEX_01to0D -RuleName "Percent05_Set1_DEC_1to13_HEX_01to0D"

Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_02" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set2_DEC_14to26_HEX_0Eto1A = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%0E" or SMS_R_System.SMSUniqueIdentifier like "%0F" or SMS_R_System.SMSUniqueIdentifier like "%10" or SMS_R_System.SMSUniqueIdentifier like "%11" or SMS_R_System.SMSUniqueIdentifier like "%12" or SMS_R_System.SMSUniqueIdentifier like "%13" or SMS_R_System.SMSUniqueIdentifier like "%14" or SMS_R_System.SMSUniqueIdentifier like "%15" or SMS_R_System.SMSUniqueIdentifier like "%16" or SMS_R_System.SMSUniqueIdentifier like "%17" or SMS_R_System.SMSUniqueIdentifier like "%18" or SMS_R_System.SMSUniqueIdentifier like "%19" or SMS_R_System.SMSUniqueIdentifier like "%1A"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_02" -QueryExpression $Percent05_Set2_DEC_14to26_HEX_0Eto1A -RuleName "Percent05_Set2_DEC_14to26_HEX_0Eto1A"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_03" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set3_DEC_27to39_HEX_1Bto27 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%1B" or SMS_R_System.SMSUniqueIdentifier like "%1C" or SMS_R_System.SMSUniqueIdentifier like "%1D" or SMS_R_System.SMSUniqueIdentifier like "%1E" or SMS_R_System.SMSUniqueIdentifier like "%1F" or SMS_R_System.SMSUniqueIdentifier like "%20" or SMS_R_System.SMSUniqueIdentifier like "%21" or SMS_R_System.SMSUniqueIdentifier like "%22" or SMS_R_System.SMSUniqueIdentifier like "%23" or SMS_R_System.SMSUniqueIdentifier like "%24" or SMS_R_System.SMSUniqueIdentifier like "%25" or SMS_R_System.SMSUniqueIdentifier like "%26" or SMS_R_System.SMSUniqueIdentifier like "%27"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_03" -QueryExpression $Percent05_Set3_DEC_27to39_HEX_1Bto27 -RuleName "Percent05_Set3_DEC_27to39_HEX_1Bto27"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_04" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set4_DEC_40to52_HEX_28to34 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%28" or SMS_R_System.SMSUniqueIdentifier like "%29" or SMS_R_System.SMSUniqueIdentifier like "%2A" or SMS_R_System.SMSUniqueIdentifier like "%2B" or SMS_R_System.SMSUniqueIdentifier like "%2C" or SMS_R_System.SMSUniqueIdentifier like "%2D" or SMS_R_System.SMSUniqueIdentifier like "%2E" or SMS_R_System.SMSUniqueIdentifier like "%2F" or SMS_R_System.SMSUniqueIdentifier like "%30" or SMS_R_System.SMSUniqueIdentifier like "%31" or SMS_R_System.SMSUniqueIdentifier like "%32" or SMS_R_System.SMSUniqueIdentifier like "%33" or SMS_R_System.SMSUniqueIdentifier like "%34"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_04" -QueryExpression $Percent05_Set4_DEC_40to52_HEX_28to34 -RuleName "Percent05_Set4_DEC_40to52_HEX_28to34"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_05" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set5_DEC_53to65_HEX_35to41 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%35" or SMS_R_System.SMSUniqueIdentifier like "%36" or SMS_R_System.SMSUniqueIdentifier like "%37" or SMS_R_System.SMSUniqueIdentifier like "%38" or SMS_R_System.SMSUniqueIdentifier like "%39" or SMS_R_System.SMSUniqueIdentifier like "%3A" or SMS_R_System.SMSUniqueIdentifier like "%3B" or SMS_R_System.SMSUniqueIdentifier like "%3C" or SMS_R_System.SMSUniqueIdentifier like "%3D" or SMS_R_System.SMSUniqueIdentifier like "%3E" or SMS_R_System.SMSUniqueIdentifier like "%3F" or SMS_R_System.SMSUniqueIdentifier like "%40" or SMS_R_System.SMSUniqueIdentifier like "%41"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_05" -QueryExpression $Percent05_Set5_DEC_53to65_HEX_35to41 -RuleName "Percent05_Set5_DEC_53to65_HEX_35to41"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_06" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set6_DEC_66to78_HEX_42to4E = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%42" or SMS_R_System.SMSUniqueIdentifier like "%43" or SMS_R_System.SMSUniqueIdentifier like "%44" or SMS_R_System.SMSUniqueIdentifier like "%45" or SMS_R_System.SMSUniqueIdentifier like "%46" or SMS_R_System.SMSUniqueIdentifier like "%47" or SMS_R_System.SMSUniqueIdentifier like "%48" or SMS_R_System.SMSUniqueIdentifier like "%49" or SMS_R_System.SMSUniqueIdentifier like "%4A" or SMS_R_System.SMSUniqueIdentifier like "%4B" or SMS_R_System.SMSUniqueIdentifier like "%4C" or SMS_R_System.SMSUniqueIdentifier like "%4D" or SMS_R_System.SMSUniqueIdentifier like "%4E"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_06" -QueryExpression $Percent05_Set6_DEC_66to78_HEX_42to4E -RuleName "Percent05_Set6_DEC_66to78_HEX_42to4E"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_07" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set7_DEC_79to91_HEX_4Fto5B = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%4F" or SMS_R_System.SMSUniqueIdentifier like "%50" or SMS_R_System.SMSUniqueIdentifier like "%51" or SMS_R_System.SMSUniqueIdentifier like "%52" or SMS_R_System.SMSUniqueIdentifier like "%53" or SMS_R_System.SMSUniqueIdentifier like "%54" or SMS_R_System.SMSUniqueIdentifier like "%55" or SMS_R_System.SMSUniqueIdentifier like "%56" or SMS_R_System.SMSUniqueIdentifier like "%57" or SMS_R_System.SMSUniqueIdentifier like "%58" or SMS_R_System.SMSUniqueIdentifier like "%59" or SMS_R_System.SMSUniqueIdentifier like "%5A" or SMS_R_System.SMSUniqueIdentifier like "%5B"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_07" -QueryExpression $Percent05_Set7_DEC_79to91_HEX_4Fto5B -RuleName "Percent05_Set7_DEC_79to91_HEX_4Fto5B"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_08" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set8_DEC_92to104_HEX_5Cto68 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%5C" or SMS_R_System.SMSUniqueIdentifier like "%5D" or SMS_R_System.SMSUniqueIdentifier like "%5E" or SMS_R_System.SMSUniqueIdentifier like "%5F" or SMS_R_System.SMSUniqueIdentifier like "%60" or SMS_R_System.SMSUniqueIdentifier like "%61" or SMS_R_System.SMSUniqueIdentifier like "%62" or SMS_R_System.SMSUniqueIdentifier like "%63" or SMS_R_System.SMSUniqueIdentifier like "%64" or SMS_R_System.SMSUniqueIdentifier like "%65" or SMS_R_System.SMSUniqueIdentifier like "%66" or SMS_R_System.SMSUniqueIdentifier like "%67" or SMS_R_System.SMSUniqueIdentifier like "%68"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_08" -QueryExpression $Percent05_Set8_DEC_92to104_HEX_5Cto68 -RuleName "Percent05_Set8_DEC_92to104_HEX_5Cto68"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_09" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set9_DEC_105to117_HEX_69to75 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%69" or SMS_R_System.SMSUniqueIdentifier like "%6A" or SMS_R_System.SMSUniqueIdentifier like "%6B" or SMS_R_System.SMSUniqueIdentifier like "%6C" or SMS_R_System.SMSUniqueIdentifier like "%6D" or SMS_R_System.SMSUniqueIdentifier like "%6E" or SMS_R_System.SMSUniqueIdentifier like "%6F" or SMS_R_System.SMSUniqueIdentifier like "%70" or SMS_R_System.SMSUniqueIdentifier like "%71" or SMS_R_System.SMSUniqueIdentifier like "%72" or SMS_R_System.SMSUniqueIdentifier like "%73" or SMS_R_System.SMSUniqueIdentifier like "%74" or SMS_R_System.SMSUniqueIdentifier like "%75"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_09" -QueryExpression $Percent05_Set9_DEC_105to117_HEX_69to75 -RuleName "Percent05_Set9_DEC_105to117_HEX_69to75"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_10" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set10_DEC_118to130_HEX_76to82 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%76" or SMS_R_System.SMSUniqueIdentifier like "%77" or SMS_R_System.SMSUniqueIdentifier like "%78" or SMS_R_System.SMSUniqueIdentifier like "%79" or SMS_R_System.SMSUniqueIdentifier like "%7A" or SMS_R_System.SMSUniqueIdentifier like "%7B" or SMS_R_System.SMSUniqueIdentifier like "%7C" or SMS_R_System.SMSUniqueIdentifier like "%7D" or SMS_R_System.SMSUniqueIdentifier like "%7E" or SMS_R_System.SMSUniqueIdentifier like "%7F" or SMS_R_System.SMSUniqueIdentifier like "%80" or SMS_R_System.SMSUniqueIdentifier like "%81" or SMS_R_System.SMSUniqueIdentifier like "%82"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_10" -QueryExpression $Percent05_Set10_DEC_118to130_HEX_76to82 -RuleName "Percent05_Set10_DEC_118to130_HEX_76to82"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_11" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set11_DEC_131to143_HEX_83to8F = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%83" or SMS_R_System.SMSUniqueIdentifier like "%84" or SMS_R_System.SMSUniqueIdentifier like "%85" or SMS_R_System.SMSUniqueIdentifier like "%86" or SMS_R_System.SMSUniqueIdentifier like "%87" or SMS_R_System.SMSUniqueIdentifier like "%88" or SMS_R_System.SMSUniqueIdentifier like "%89" or SMS_R_System.SMSUniqueIdentifier like "%8A" or SMS_R_System.SMSUniqueIdentifier like "%8B" or SMS_R_System.SMSUniqueIdentifier like "%8C" or SMS_R_System.SMSUniqueIdentifier like "%8D" or SMS_R_System.SMSUniqueIdentifier like "%8E" or SMS_R_System.SMSUniqueIdentifier like "%8F"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_11" -QueryExpression $Percent05_Set11_DEC_131to143_HEX_83to8F -RuleName "Percent05_Set11_DEC_131to143_HEX_83to8F"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_12" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set12_DEC_144to156_HEX_90to9C = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%90" or SMS_R_System.SMSUniqueIdentifier like "%91" or SMS_R_System.SMSUniqueIdentifier like "%92" or SMS_R_System.SMSUniqueIdentifier like "%93" or SMS_R_System.SMSUniqueIdentifier like "%94" or SMS_R_System.SMSUniqueIdentifier like "%95" or SMS_R_System.SMSUniqueIdentifier like "%96" or SMS_R_System.SMSUniqueIdentifier like "%97" or SMS_R_System.SMSUniqueIdentifier like "%98" or SMS_R_System.SMSUniqueIdentifier like "%99" or SMS_R_System.SMSUniqueIdentifier like "%9A" or SMS_R_System.SMSUniqueIdentifier like "%9B" or SMS_R_System.SMSUniqueIdentifier like "%9C"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_12" -QueryExpression $Percent05_Set12_DEC_144to156_HEX_90to9C -RuleName "Percent05_Set12_DEC_144to156_HEX_90to9C"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_13" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set13_DEC_157to169_HEX_9DtoA9 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%9D" or SMS_R_System.SMSUniqueIdentifier like "%9E" or SMS_R_System.SMSUniqueIdentifier like "%9F" or SMS_R_System.SMSUniqueIdentifier like "%A0" or SMS_R_System.SMSUniqueIdentifier like "%A1" or SMS_R_System.SMSUniqueIdentifier like "%A2" or SMS_R_System.SMSUniqueIdentifier like "%A3" or SMS_R_System.SMSUniqueIdentifier like "%A4" or SMS_R_System.SMSUniqueIdentifier like "%A5" or SMS_R_System.SMSUniqueIdentifier like "%A6" or SMS_R_System.SMSUniqueIdentifier like "%A7" or SMS_R_System.SMSUniqueIdentifier like "%A8" or SMS_R_System.SMSUniqueIdentifier like "%A9"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_13" -QueryExpression $Percent05_Set13_DEC_157to169_HEX_9DtoA9 -RuleName "Percent05_Set13_DEC_157to169_HEX_9DtoA9"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_14" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set14_DEC_170to182_HEX_AAtoB6 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%AA" or SMS_R_System.SMSUniqueIdentifier like "%AB" or SMS_R_System.SMSUniqueIdentifier like "%AC" or SMS_R_System.SMSUniqueIdentifier like "%AD" or SMS_R_System.SMSUniqueIdentifier like "%AE" or SMS_R_System.SMSUniqueIdentifier like "%AF" or SMS_R_System.SMSUniqueIdentifier like "%B0" or SMS_R_System.SMSUniqueIdentifier like "%B1" or SMS_R_System.SMSUniqueIdentifier like "%B2" or SMS_R_System.SMSUniqueIdentifier like "%B3" or SMS_R_System.SMSUniqueIdentifier like "%B4" or SMS_R_System.SMSUniqueIdentifier like "%B5" or SMS_R_System.SMSUniqueIdentifier like "%B6"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_14" -QueryExpression $Percent05_Set14_DEC_170to182_HEX_AAtoB6 -RuleName "Percent05_Set14_DEC_170to182_HEX_AAtoB6"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_15" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set15_DEC_183to195_HEX_B7toC3 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%B7" or SMS_R_System.SMSUniqueIdentifier like "%B8" or SMS_R_System.SMSUniqueIdentifier like "%B9" or SMS_R_System.SMSUniqueIdentifier like "%BA" or SMS_R_System.SMSUniqueIdentifier like "%BB" or SMS_R_System.SMSUniqueIdentifier like "%BC" or SMS_R_System.SMSUniqueIdentifier like "%BD" or SMS_R_System.SMSUniqueIdentifier like "%BE" or SMS_R_System.SMSUniqueIdentifier like "%BF" or SMS_R_System.SMSUniqueIdentifier like "%C0" or SMS_R_System.SMSUniqueIdentifier like "%C1" or SMS_R_System.SMSUniqueIdentifier like "%C2" or SMS_R_System.SMSUniqueIdentifier like "%C3"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_15" -QueryExpression $Percent05_Set15_DEC_183to195_HEX_B7toC3 -RuleName "Percent05_Set15_DEC_183to195_HEX_B7toC3"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_16" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set16_DEC_196to207_HEX_C4toCF = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%C4" or SMS_R_System.SMSUniqueIdentifier like "%C5" or SMS_R_System.SMSUniqueIdentifier like "%C6" or SMS_R_System.SMSUniqueIdentifier like "%C7" or SMS_R_System.SMSUniqueIdentifier like "%C8" or SMS_R_System.SMSUniqueIdentifier like "%C9" or SMS_R_System.SMSUniqueIdentifier like "%CA" or SMS_R_System.SMSUniqueIdentifier like "%CB" or SMS_R_System.SMSUniqueIdentifier like "%CC" or SMS_R_System.SMSUniqueIdentifier like "%CD" or SMS_R_System.SMSUniqueIdentifier like "%CE" or SMS_R_System.SMSUniqueIdentifier like "%CF"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_16" -QueryExpression $Percent05_Set16_DEC_196to207_HEX_C4toCF -RuleName "Percent05_Set16_DEC_196to207_HEX_C4toCF"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_17" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set17_DEC_208to219_HEX_D0toDB = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%D0" or SMS_R_System.SMSUniqueIdentifier like "%D1" or SMS_R_System.SMSUniqueIdentifier like "%D2" or SMS_R_System.SMSUniqueIdentifier like "%D3" or SMS_R_System.SMSUniqueIdentifier like "%D4" or SMS_R_System.SMSUniqueIdentifier like "%D5" or SMS_R_System.SMSUniqueIdentifier like "%D6" or SMS_R_System.SMSUniqueIdentifier like "%D7" or SMS_R_System.SMSUniqueIdentifier like "%D8" or SMS_R_System.SMSUniqueIdentifier like "%D9" or SMS_R_System.SMSUniqueIdentifier like "%DA" or SMS_R_System.SMSUniqueIdentifier like "%DB"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_17" -QueryExpression $Percent05_Set17_DEC_208to219_HEX_D0toDB -RuleName "Percent05_Set17_DEC_208to219_HEX_D0toDB"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_18" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set18_DEC_220to231_HEX_DCtoE7 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%DC" or SMS_R_System.SMSUniqueIdentifier like "%DD" or SMS_R_System.SMSUniqueIdentifier like "%DE" or SMS_R_System.SMSUniqueIdentifier like "%DF" or SMS_R_System.SMSUniqueIdentifier like "%E0" or SMS_R_System.SMSUniqueIdentifier like "%E1" or SMS_R_System.SMSUniqueIdentifier like "%E2" or SMS_R_System.SMSUniqueIdentifier like "%E3" or SMS_R_System.SMSUniqueIdentifier like "%E4" or SMS_R_System.SMSUniqueIdentifier like "%E5" or SMS_R_System.SMSUniqueIdentifier like "%E6" or SMS_R_System.SMSUniqueIdentifier like "%E7"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_18" -QueryExpression $Percent05_Set18_DEC_220to231_HEX_DCtoE7 -RuleName "Percent05_Set18_DEC_220to231_HEX_DCtoE7"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_19" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set19_DEC_232to243_HEX_E8toF3 = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%E8" or SMS_R_System.SMSUniqueIdentifier like "%E9" or SMS_R_System.SMSUniqueIdentifier like "%EA" or SMS_R_System.SMSUniqueIdentifier like "%EB" or SMS_R_System.SMSUniqueIdentifier like "%EC" or SMS_R_System.SMSUniqueIdentifier like "%ED" or SMS_R_System.SMSUniqueIdentifier like "%EE" or SMS_R_System.SMSUniqueIdentifier like "%EF" or SMS_R_System.SMSUniqueIdentifier like "%F0" or SMS_R_System.SMSUniqueIdentifier like "%F1" or SMS_R_System.SMSUniqueIdentifier like "%F2" or SMS_R_System.SMSUniqueIdentifier like "%F3"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_19" -QueryExpression $Percent05_Set19_DEC_232to243_HEX_E8toF3 -RuleName "Percent05_Set19_DEC_232to243_HEX_E8toF3"
Create-And-MoveCMCollection -CollectionName "SMS_Collection_05Percent_Set_20" -LimitingCollection "All Windows Workstation or Professional Systems" -FolderPath "DeviceCollection\Reusable Collections\5 Percent Sets"
$Percent05_Set20_DEC_244to255_HEX_F4toFF = 'select *  from  SMS_R_System where SMS_R_System.SMSUniqueIdentifier like "%F4" or SMS_R_System.SMSUniqueIdentifier like "%F5" or SMS_R_System.SMSUniqueIdentifier like "%F6" or SMS_R_System.SMSUniqueIdentifier like "%F7" or SMS_R_System.SMSUniqueIdentifier like "%F8" or SMS_R_System.SMSUniqueIdentifier like "%F9" or SMS_R_System.SMSUniqueIdentifier like "%FA" or SMS_R_System.SMSUniqueIdentifier like "%FB" or SMS_R_System.SMSUniqueIdentifier like "%FC" or SMS_R_System.SMSUniqueIdentifier like "%FD" or SMS_R_System.SMSUniqueIdentifier like "%FE" or SMS_R_System.SMSUniqueIdentifier like "%FF"'
Add-CMDeviceCollectionQueryMembershipRuleWithQuery -CollectionName "SMS_Collection_05Percent_Set_20" -QueryExpression $Percent05_Set20_DEC_244to255_HEX_F4toFF -RuleName "Percent05_Set20_DEC_244to255_HEX_F4toFF"
