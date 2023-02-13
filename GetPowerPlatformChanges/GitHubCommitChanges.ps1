Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $Actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $Token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $ParentTelemetryScopeJson = '7b7d',
    [Parameter(HelpMessage = "Temporary location for files to be checked in", Mandatory = $false)]
    [string] $TempLocation,
    [Parameter(HelpMessage = "The relative folder location of the PowerPlatform solution", Mandatory = $false)]
    [string] $SourceLocation,
    [Parameter(HelpMessage = "Direct Commit (Y/N)", Mandatory = $false)]
    [string] $DirectCommit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $ParentTelemetryScopeJson;

Function Copy-Files {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "The source folder path")]
        [string]$Source,
        [Parameter(Mandatory = $true, HelpMessage = "The destination folder path")]
        [string]$Destination
    )
        
    Write-Host "Copying files from $Source to $Destination"
        
    Get-ChildItem $Source | ForEach-Object {
        $destinationPath = Join-Path $Destination $_.Name
        Copy-Item $_.FullName $destinationPath
    }
}
    
Function CloneAndCommit {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "The GitHub actor running the action")]
        [string]$GitHubActor,
        [Parameter(Mandatory = $true, HelpMessage = "The GitHub token running the action")]
        [string]$GitHubToken,
        [Parameter(Mandatory = $true, HelpMessage = "Indicates if direct commit")]
        [bool]$DirectCommit,
        [Parameter(Mandatory = $true, HelpMessage = "The name of the PowerPlatform solution")]
        [string]$PowerPlatformSolutionName
    )
        
    # Import the helper script
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
        
    $GitHubBranch = "";
    if ($DirectCommit -eq "true") {
        $GitHubBranch = [System.IO.Path]::GetRandomFileName()
    }
        
    # Clone the repository into a new folder
    $serverUrl = CloneIntoNewFolder -Actor $GitHubActor -Token $GitHubToken -Branch $GitHubBranch
            
    $baseFolder = (Get-Location).Path
    Set-Location $baseFolder
            
    Copy-Files -Source $TempLocation -Destination "$baseFolder/$SourceLocation"
            
    # Commit from the new folder
    CommitFromNewFolder -ServerUrl $serverUrl -CommitMessage "Upadte solution: ($PowerPlatformSolutionName)" -Branch $GitHubBranch
}
        
# IMPORTANT: No code that can fail should be outside the try/catch
try {
    CloneAndCommit -GitHubActor $Actor -GitHubToken $Token -GitHubBranch $branch -PowerPlatformSolutionName $SourceLocation
    TrackTrace -telemetryScope $telemetryScope
}
catch {
    Write-Error -message "Pull changes failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    if (Test-Path $TempLocation) {
        Remove-Item $TempLocation -Recurse -Force
    }
}
        
