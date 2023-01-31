Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d',
    [Parameter(HelpMessage = "Project folder", Mandatory = $false)]
    [string] $project = "",
    [Parameter(HelpMessage = "Project Dependencies in compressed Json format", Mandatory = $false)]
    [string] $projectDependenciesJson = "",
    [Parameter(HelpMessage = "Settings from repository in compressed Json format", Mandatory = $false)]
    [string] $settingsJson = '{}',
    [Parameter(HelpMessage = "Secrets from repository in compressed Json format", Mandatory = $false)]
    [string] $secretsJson = '{}'
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null

# IMPORTANT: No code that can fail should be outside the try/catch

try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper -baseFolder $ENV:GITHUB_WORKSPACE 

    import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    $telemetryScope = CreateScope -eventId 'DO0083' -parentTelemetryScopeJson $parentTelemetryScopeJson

    # Set location
    Write-Host "Build PowerPlatform Solution ${{ matrix.project }}"
    Set-Location (Join-Path $ENV:GITHUB_WORKSPACE '${{ matrix.project }}')

    # Create Output folder
    New-Item -Path '.buildartifacts/PowerPlatformSolution' -ItemType Directory | Out-Null

    # Create a dummy file
    Set-Content -Path (Join-Path '.buildartifacts/PowerPlatformSolution' 'myPPSolution.txt') -value 'This is my PP Solution .zip file'

    TrackTrace -telemetryScope $telemetryScope
}
catch {
    OutputError -message "RunPipeline action failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
