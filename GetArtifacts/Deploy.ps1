Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d',
    [Parameter(HelpMessage = "Projects to deploy", Mandatory = $false)]
    [string] $projects = '',
    [Parameter(HelpMessage = "Name of environment to deploy to", Mandatory = $true)]
    [string] $environmentName,
    [Parameter(HelpMessage = "Artifacts to deploy", Mandatory = $true)]
    [string] $artifacts,
    [Parameter(HelpMessage = "Type of deployment (CD or Publish)", Mandatory = $false)]
    [ValidateSet('CD','Publish')]
    [string] $type = "CD"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null

if ($projects -eq '') {
    Write-Host "No projects to deploy"
}
else {

# IMPORTANT: No code that can fail should be outside the try/catch

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper -baseFolder $ENV:GITHUB_WORKSPACE

    import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    $telemetryScope = CreateScope -eventId 'DO0075' -parentTelemetryScopeJson $parentTelemetryScopeJson

    $EnvironmentName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($environmentName))

    $artifactVersion = $artifactVersion.Replace('/',([System.IO.Path]::DirectorySeparatorChar)).Replace('\',([System.IO.Path]::DirectorySeparatorChar))

    $apps = @()
    $artifactsFolder = Join-Path $ENV:GITHUB_WORKSPACE ".artifacts"
    $artifactsFolderCreated = $false
    if ($artifactVersion -eq ".artifacts") {
        $artifactVersion = $artifactsFolder
    }

    if ($artifactVersion -like "$($ENV:GITHUB_WORKSPACE)*") {
        if (Test-Path $artifactVersion -PathType Container) {
            $projects.Split(',') | ForEach-Object {
                $project = $_.Replace('\','_').Replace('/','_')
                $refname = "$ENV:GITHUB_REF_NAME".Replace('/','_')
                Write-Host "project '$project'"
                $projectApps = @((Get-ChildItem -Path $artifactVersion -Filter "$project-$refname-Apps-*.*.*.*") | ForEach-Object { $_.FullName })
                if (!($projectApps)) {
                    if ($project -ne '*') {
                        throw "There is no artifacts present in $artifactVersion matching $project-$refname-Apps-<version>."
                    }
                }
                $apps += $projectApps
                $apps += @((Get-ChildItem -Path $artifactVersion -Filter "$project-$refname-Dependencies-*.*.*.*") | ForEach-Object { $_.FullName })
            }
        }
        elseif (Test-Path $artifacts) {
            $apps = $artifacts
        }
        else {
            throw "Artifact $artifactVersion was not found. Make sure that the artifact files exist and files are not corrupted."
        }
    }
    elseif ($artifactVersion -eq "current" -or $artifactVersion -eq "prerelease" -or $artifactVersion -eq "draft") {
        # latest released version
        $releases = GetReleases -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY
        if ($artifactVersion -eq "current") {
            $release = $releases | Where-Object { -not ($_.prerelease -or $_.draft) } | Select-Object -First 1
        }
        elseif ($artifactVersion -eq "prerelease") {
            $release = $releases | Where-Object { -not ($_.draft) } | Select-Object -First 1
        }
        elseif ($artifactVersion -eq "draft") {
            $release = $releases | Select-Object -First 1
        }
        if (!($release)) {
            throw "Unable to locate $artifactVersion release"
        }
        New-Item $artifactsFolder -ItemType Directory | Out-Null
        $artifactsFolderCreated = $true
        DownloadRelease -token $token -projects $projects -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY -release $release -path $artifactsFolder -mask "Apps"
        DownloadRelease -token $token -projects $projects -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY -release $release -path $artifactsFolder -mask "Dependencies"
        $apps = @((Get-ChildItem -Path $artifactsFolder) | ForEach-Object { $_.FullName })
        if (!$apps) {
            throw "Artifact $artifactVersion was not found on any release. Make sure that the artifact files exist and files are not corrupted."
        }
    }
    else {
        New-Item $artifactsFolder -ItemType Directory | Out-Null
        $baseFolderCreated = $true
        $allArtifacts = @(GetArtifacts -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY -mask "Apps" -projects $projects -Version $artifactVersion -branch "main")
        $allArtifacts += @(GetArtifacts -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY -mask "Dependencies" -projects $projects -Version $artifactVersion -branch "main")
        if ($allArtifacts) {
            $allArtifacts | ForEach-Object {
                $appFile = DownloadArtifact -token $token -artifact $_ -path $artifactsFolder
                if (!(Test-Path $appFile)) {
                    throw "Unable to download artifact $($_.name)"
                }
                $apps += @($appFile)
            }
        }
        else {
            throw "Could not find any Apps artifacts for projects $projects, version $artifacts"
        }
    }

    if ($artifactsFolderCreated) {
        Remove-Item $artifactsFolder -Recurse -Force
    }

    TrackTrace -telemetryScope $telemetryScope

}
catch {
    OutputError -message "Deploy action failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
}
