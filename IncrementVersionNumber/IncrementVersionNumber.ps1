Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d',
    [Parameter(HelpMessage = "Project name if the repository is setup for multiple projects (* for all projects)", Mandatory = $false)]
    [string] $project = '*',
    [Parameter(HelpMessage = "Updated Version Number. Use Major.Minor for absolute change, use +Major.Minor for incremental change.", Mandatory = $true)]
    [string] $versionnumber,
    [Parameter(HelpMessage = "Direct commit (Y/N)", Mandatory = $false)]
    [bool] $directCommit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null
Write-Host "Increment Version Number"

function Update-PowerPlatformSolutionVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version
    )

    $files = Get-ChildItem -Recurse -File
    foreach ($file in $files) {
        Write-Host "Updating $($file.FullName) with version $Version"
        if ($file.Name -eq "solution.xml" -and $file.Directory.Name -eq "other") {
            $xml = [xml](Get-Content $file.FullName)
            $xml.SelectNodes("//Version")[0].InnerText = $Version
            $xml.Save($file.FullName)
        }
    }
}

# IMPORTANT: No code that can fail should be outside the try/catch

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    
    # Set up git branch and clone repository
    $branch = "$(if (!$directCommit) { [System.IO.Path]::GetRandomFileName() })"
    $serverUrl = CloneIntoNewFolder -actor $actor -token $token -branch $branch
    $repoBaseFolder = (Get-Location).path

    # Set up container and telemetry helper
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper -baseFolder $repoBaseFolder

    import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    $telemetryScope = CreateScope -eventId 'DO0076' -parentTelemetryScopeJson $parentTelemetryScopeJson
    
    # Calculate new version number
    $addToVersionNumber = "$versionnumber".StartsWith('+')
    if ($addToVersionNumber) {
        $versionnumber = $versionnumber.Substring(1)
    }
    try {
        $newVersion = [System.Version]"$($versionnumber).0.0"
    }
    catch {
        throw "Version number ($versionnumber) is malformed. A version number must be structured as <Major>.<Minor> or +<Major>.<Minor>"
    }

    # Update version number for all Power Platform solutions
    Update-PowerPlatformSolutionVersion -Version $newVersion 

    # Find all AL projects
    if (!$project) { $project = '*' }

    if ($project -ne '.') {
        $projects = @(Get-ChildItem -Path $repoBaseFolder -Directory -Recurse -Depth 2 | Where-Object { Test-Path (Join-Path $_.FullName ".AL-Go/settings.json") -PathType Leaf } | ForEach-Object { $_.FullName.Substring($repoBaseFolder.length+1) } | Where-Object { $_ -like $project })
        if ($projects.Count -eq 0) {
            if ($project -eq '*') {
                $projects = @( '.' )
            }
            else {
                throw "Project folder $project not found"
            }
        }
    }
    else {
        $projects = @( '.' )
    }

    # Update version number for all AL projects
    $projects | ForEach-Object {
        $project = $_
        try {
            Write-Host "Reading settings from $project\$ALGoSettingsFile"
            $settingsJson = Get-Content "$project\$ALGoSettingsFile" -Encoding UTF8 | ConvertFrom-Json
            if ($settingsJson.PSObject.Properties.Name -eq "repoVersion") {
                $oldVersion = [System.Version]"$($settingsJson.repoVersion).0.0"
                if ((!$addToVersionNumber) -and $newVersion -le $oldVersion) {
                    throw "The new version number ($($newVersion.Major).$($newVersion.Minor)) must be larger than the old version number ($($oldVersion.Major).$($oldVersion.Minor))"
                }
                $repoVersion = $newVersion
                if ($addToVersionNumber) {
                    $repoVersion = [System.Version]"$($newVersion.Major+$oldVersion.Major).$($newVersion.Minor+$oldVersion.Minor).0.0"
                }
                $settingsJson.repoVersion = "$($repoVersion.Major).$($repoVersion.Minor)"
            }
            else {
                $repoVersion = $newVersion
                if ($addToVersionNumber) {
                    $repoVersion = [System.Version]"$($newVersion.Major+1).$($newVersion.Minor).0.0"
                }
                Add-Member -InputObject $settingsJson -NotePropertyName "repoVersion" -NotePropertyValue "$($repoVersion.Major).$($repoVersion.Minor)" | Out-Null
            }
            $useRepoVersion = (($settingsJson.PSObject.Properties.Name -eq "versioningStrategy") -and (($settingsJson.versioningStrategy -band 16) -eq 16))
            $settingsJson
            $settingsJson | Set-JsonContentLF -path "$project\$ALGoSettingsFile"
        }
        catch {
            throw "Settings file $project\$ALGoSettingsFile is malformed.$([environment]::Newline) $($_.Exception.Message)."
        }

        $folders = @('appFolders', 'testFolders' | ForEach-Object { if ($SettingsJson.PSObject.Properties.Name -eq $_) { $settingsJson."$_" } })
        if (-not ($folders)) {
            $folders = Get-ChildItem -Path $project | Where-Object { $_.PSIsContainer -and (Test-Path (Join-Path $_.FullName 'app.json')) } | ForEach-Object { $_.Name }
        }
        $folders | ForEach-Object {
            Write-Host "Modifying app.json in folder $project\$_"
            $appJsonFile = Join-Path "$project\$_" "app.json"
            if (Test-Path $appJsonFile) {
                try {
                    $appJson = Get-Content $appJsonFile -Encoding UTF8 | ConvertFrom-Json
                    $oldVersion = [System.Version]$appJson.Version
                    if ($useRepoVersion) {
                        $appVersion = $repoVersion
                    }
                    elseif ($addToVersionNumber) {
                        $appVersion = [System.Version]"$($newVersion.Major+$oldVersion.Major).$($newVersion.Minor+$oldVersion.Minor).0.0"
                    }
                    else {
                        $appVersion = $newVersion
                    }
                    $appJson.Version = "$appVersion"
                    $appJson | Set-JsonContentLF -path $appJsonFile
                }
                catch {
                    throw "Application manifest file($appJsonFile) is malformed."
                }
            }
        }
    }

    # Commit changes to branch
    if ($addToVersionNumber) {
        CommitFromNewFolder -serverUrl $serverUrl -commitMessage "Increment Version number by $($newVersion.Major).$($newVersion.Minor)" -branch $branch
    }
    else {
        CommitFromNewFolder -serverUrl $serverUrl -commitMessage "New Version number $($newVersion.Major).$($newVersion.Minor)" -branch $branch
    }

    TrackTrace -telemetryScope $telemetryScope
}
catch {
    OutputError -message "IncrementVersionNumber action failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
