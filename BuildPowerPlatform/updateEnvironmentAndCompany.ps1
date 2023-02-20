[CmdletBinding()]
param(
    [Parameter(Position = 0, mandatory = $true)] [string] $CompanyId,
    [Parameter(Position = 1, mandatory = $true)] [string] $EnvironmentName,
    [Parameter(Position = 2, mandatory = $true)] [string] $SolutionFolder
)

function getCurrentSettings {
    param (
        [Parameter(Position = 0, mandatory = $true)] [string] $solutionFolder
    )

    $connectionFiles = Get-ChildItem -Path $solutionFolder -Recurse -File -Include "Connections.json";    
    $currentSettingsList = @();

    foreach ($connectionFile in $connectionFiles) {
        $connectionsFilePath = $connectionFile.FullName;
        $jsonFile = Get-Content $connectionsFilePath | ConvertFrom-Json;
        $ConnectorNodeNames = ($jsonFile | Get-Member -MemberType NoteProperty).Name;               

        # We don't know the name of the connector node, so we need to loop through all of them
        foreach ($connectorNodeName in $ConnectorNodeNames) {
            $connectorNode = $jsonFile.$connectorNodeName;
            if ($connectorNode.connectionRef.displayName -eq "Dynamics 365 Business Central") {
                $currentEnvironmentAndCompany = ($connectorNode.datasets | Get-Member -MemberType NoteProperty).Name;

                if (!$currentsettingsList.Contains($currentEnvironmentAndCompany)) {
                    $currentSettingsList += $currentEnvironmentAndCompany;
                } 
                break;     
            }
        }
    }
    
    return $currentSettingsList;
}

function replaceOldSettings {
    param(
        [Parameter(Position = 0, mandatory = $true)] [string] $solutionFolder,
        [Parameter(Position = 0, mandatory = $true)] [string] $oldSetting,
        [Parameter(Position = 0, mandatory = $true)] [string] $newSetting
    )

    $powerAppFiles = Get-ChildItem -Recurse -File $solutionFolder
    foreach ($file in $powerAppFiles) {
        # only check json and xml files
        if (($file.Extension -eq ".json") -or ($file.Extension -eq ".xml")) {
            
            $fileContent = Get-Content $file.FullName;
            if (Select-String -Pattern $oldSetting -InputObject $fileContent) {
                Set-Content -Path $file.FullName -Value $fileContent.Replace($oldSetting, $newSetting);
                Write-Host $file.FullName" <-- updated ";
            }
        }
    }
}

Write-Host "Updating Business Central environment and company settings";

$currentSettings = getCurrentSettings -solutionFolder $SolutionFolder;
if ($currentSettings.Count -eq 0) {
    Write-Warning "Could not find connections file";
    throw "Could not find connections file";
}

$newSettings = "$EnvironmentName,$CompanyId";
Write-Host "New settings: "$newSettings;

foreach ($currentSetting in $currentSettings) {
    if ($currentSetting -eq $newSettings) {
        Write-Host "No changes needed for: "$currentSetting;
        continue;
    }

    Write-Host "Updating: "$currentSetting;
    replaceOldSettings -oldSetting $currentSetting -newSetting $newSettings -solutionFolder $SolutionFolder;
}