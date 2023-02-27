Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d'
)

function Get-Artifacts {
    # Define the URL of the repository's latest release API endpoint
    $apiUrl = "https://api.github.com/repos/andersgMSFT/bcSampleAppsTest/releases/latest"

    # Set the GitHub API token if necessary
    $headers = @{ "Authorization" = $token }

    # Call the API endpoint and parse the JSON response
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    Write-Host "Response: $response"
    $assets = $response.assets

    # Loop through the release assets and download them
    foreach ($asset in $assets) {
        write-host "Asset: $asset.name"
        $url = $asset.browser_download_url
        $filename = $asset.name
        Invoke-WebRequest -Uri $url -OutFile $filename
    }
}

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null

Write-Host "Get BC sample apps"

# IMPORTANT: No code that can fail should be outside the try/catch
try {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper -baseFolder $ENV:GITHUB_WORKSPACE

    import-module (Join-Path -path $PSScriptRoot -ChildPath "..\TelemetryHelper.psm1" -Resolve)
    $telemetryScope = CreateScope -eventId 'DO0075' -parentTelemetryScopeJson $parentTelemetryScopeJson

    Get-Artifacts

    Write-Host "Arifacts downloaded"
}
catch {
    OutputError -message "Deploy action failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
}
