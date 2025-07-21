function New-PCXCMFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [switch]$AutoCreatePath
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Cannot create a folder with an empty name."
    }

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
            Write-Host "Folder '$Name' created at '$Path'." -ForegroundColor $ColSuccess
        } else {
            Write-Host "Folder '$Name' already exists at '$Path'." -ForegroundColor $ColInform
        }
        return $true
    } catch {
        Write-Host "Error creating folder '$Name' at '$Path': $_" -ForegroundColor $ColError
        return $false
    }
}
