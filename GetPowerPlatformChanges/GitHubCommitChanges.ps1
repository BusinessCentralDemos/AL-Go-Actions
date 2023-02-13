Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScopeJson = '7b7d',
    [Parameter(HelpMessage = "Temporary location for files to be checked in", Mandatory = $false)]
    [string] $tempLocation,
    [Parameter(HelpMessage = "The folder location of the PowerPlatform solution", Mandatory = $false)]
    [string] $sourceLocation,
    [Parameter(HelpMessage = "Direct Commit (Y/N)", Mandatory = $false)]
    [bool] $directCommit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$telemetryScope = $null
$bcContainerHelperPath = $null
$tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())


Function Copy-Files {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "The source folder path")]
        [string]$Source,
        [Parameter(Mandatory = $true, HelpMessage = "The destination folder path")]
        [string]$Destination
        )

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
            [Parameter(Mandatory = $false, HelpMessage = "The branch name")]
            [string]$GitHubBranch,
            [Parameter(Mandatory = $false, HelpMessage = "The name of the PowerPlatform solution")]
            [string]$PowerPlatformSolutionName
            )
            
            # Import the helper script
            . (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
            
            # Determine the branch name
            if (!$GitHubBranch) {
                $GitHubBranch = [System.IO.Path]::GetRandomFileName()
            }
            
            # Clone the repository into a new folder
            $ServerUrl = CloneIntoNewFolder -Actor $GitHubActor -Token $GitHubToken -Branch $GitHubBranch
            
            # Get the current
            # Get the current location
            $BaseFolder = (Get-Location).Path
            
            # Set the location to the base folder
            Set-Location $BaseFolder
            
            # Call the Copy-Files function
            Copy-Files -Source $tempLocation -Destination $sourceLocation
            
            # Commit from the new folder
            CommitFromNewFolder -ServerUrl $ServerUrl -CommitMessage "Upadte solution: ($PowerPlatformSolutionName)" -Branch $GitHubBranch
        }
        
        # IMPORTANT: No code that can fail should be outside the try/catch
        try {
            # Call the CloneAndCommit function
            CloneAndCommit -GitHubActor $actor -GitHubToken $token -GitHubBranch $branch -PowerPlatformSolutionName $sourceLocation
            TrackTrace -telemetryScope $telemetryScope
        }
        catch {
            OutputError -message "CreateApp action failed.$([environment]::Newline)Error: $($_.Exception.Message)$([environment]::Newline)Stacktrace: $($_.scriptStackTrace)"
            TrackException -telemetryScope $telemetryScope -errorRecord $_
        }
        finally {
            CleanupAfterBcContainerHelper -bcContainerHelperPath $bcContainerHelperPath
            if (Test-Path $tmpFolder) {
                Remove-Item $tmpFolder -Recurse -Force
            }
        }
        
