Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $Actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $Token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $ParentTelemetryScopeJson = '7b7d',
    [Parameter(HelpMessage = "The name of the environment as defined in GitHub", Mandatory = $false)]
    [string] $EnvironmentName,
    [Parameter(HelpMessage = "The current location for files to be checked in", Mandatory = $false)]
    [string] $TempLocation,
    [Parameter(HelpMessage = "The relative folder location of the PowerPlatform solution in the repository", Mandatory = $false)]
    [string] $SourceLocation,
    [Parameter(HelpMessage = "Direct Commit (Y/N)", Mandatory = $false)]
    [string] $DirectCommit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $ParentTelemetryScopeJson;
Write-Host "Starting GitHubCommitChanges.ps1 with parameters: $([environment]::Newline)Actor: $Actor$([environment]::Newline)Token: $Token$([environment]::Newline)ParentTelemetryScopeJson: $ParentTelemetryScopeJson$([environment]::Newline)TempLocation: $TempLocation$([environment]::Newline)SourceLocation: $SourceLocation$([environment]::Newline)DirectCommit: $DirectCommit"

# Import the helper script
. (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)

function GetFullPath() {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )       
    if ([System.IO.Path]::IsPathRooted($Path)) {
        write-host "Path is already full path: $Path";
        return $Path
    } 

    $tempFullPath = Get-Item -Path $path | Select-Object -ExpandProperty FullName
    write-host "Path is not full path, converting to full path: $path -> $tempFullPath";
    return $tempFullPath;
}

    
Function CloneAndCommit {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "The GitHub actor running the action")]
        [string]$GitHubActor,
        [Parameter(Mandatory = $true, HelpMessage = "The GitHub token running the action")]
        [string]$GitHubToken,
        [Parameter(Mandatory = $true, HelpMessage = "Create a new branch or commit to the current branch")]
        [bool]$CreateNewBranch,
        [Parameter(Mandatory = $true, HelpMessage = "The name of the PowerPlatform solution")]
        [string]$PowerPlatformSolutionName
    )

    $fullTempLocation = GetFullPath -Path $TempLocation;
        
    $gitHubBranch = "";
    if ($CreateNewBranch) {
        $gitHubBranch = [System.IO.Path]::GetRandomFileName()
        Write-Host "Creating a new branch: $gitHubBranch"
    }
        
    # Clone the repository into a new folder
    Write-Host "Cloning the repository into a new folder"
    $serverUrl = CloneIntoNewFolder -Actor $GitHubActor -Token $GitHubToken -Branch $gitHubBranch
            
    $baseFolder = (Get-Location).Path
    Set-Location $baseFolder

    Write-Host "Copi files from $fullTempLocation to $baseFolder\$PowerPlatformSolutionName"
    Copy-Item -Path $fullTempLocation -Destination "$baseFolder\$PowerPlatformSolutionName" -Recurse

    # debug section - remove later
    Write-Host "Files copied to $baseFolder\$PowerPlatformSolutionName"    
    Get-ChildItem $baseFolder\$PowerPlatformSolutionName;
    Get-ChildItem ;

    Write-Host "Check content of file in $baseFolder\$PowerPlatformSolutionName"
    Get-Content -Path "$baseFolder\$PowerPlatformSolutionName\PPSolution\CanvasApps\src\cr301_testpowerapp_3661a\Src\Screen1.fx.yaml"
    
    Write-Host "Check content of file in $fullTempLocation"
    Get-Content -Path "$fullTempLocation\PPSolution\CanvasApps\src\cr301_testpowerapp_3661a\Src\Screen1.fx.yaml"
    # debug section - remove later

    # Commit from the new folder
    write-host "Committing changes from the new folder $baseFolder\$PowerPlatformSolutionName"
    CommitFromNewFolder -ServerUrl $serverUrl -CommitMessage "Update solution: $PowerPlatformSolutionName with latest from environment: $EnvironmentName" -Branch $gitHubBranch
}
        
# IMPORTANT: No code that can fail should be outside the try/catch
try {
    CloneAndCommit -GitHubActor $Actor -GitHubToken $Token -CreateNewBranch ($DirectCommit -eq "false") -PowerPlatformSolutionName $SourceLocation
    # TODO: Why can we not find the trackTrace function?
    #TrackTrace -telemetryScope $telemetryScope
}
catch {
    Write-Error -message "Pull changes failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
    # TODO: Why can we not find the trackExceptions function?
    #TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    if (Test-Path $TempLocation) {
        Remove-Item $TempLocation -Recurse -Force
    }
}
        
