[CmdletBinding()]
param(
    [Parameter(Position = 0, mandatory = $true)] [string] $CompanyId,
    [Parameter(Position = 1, mandatory = $true)] [string] $EnvironmentName,
    [Parameter(Position = 2, mandatory = $true)] [string] $SolutionFolder
)

function getCurrentPowerAppSettings {
    param (
        [Parameter(Position = 0, mandatory = $true)] [string] $solutionFolder
    )

    $connectionFiles = Get-ChildItem -Path $solutionFolder -Recurse -File -Include "Connections.json"    
    $currentSettingsList = @()

    foreach ($connectionFile in $connectionFiles) {
        $connectionsFilePath = $connectionFile.FullName
        $jsonFile = Get-Content $connectionsFilePath | ConvertFrom-Json
        $ConnectorNodeNames = ($jsonFile | Get-Member -MemberType NoteProperty).Name               

        # We don't know the name of the connector node, so we need to loop through all of them
        foreach ($connectorNodeName in $ConnectorNodeNames) {
            $connectorNode = $jsonFile.$connectorNodeName
            if ($connectorNode.connectionRef.displayName -eq "Dynamics 365 Business Central") {
                $currentEnvironmentAndCompany = ($connectorNode.datasets | Get-Member -MemberType NoteProperty).Name

                if (!$currentsettingsList.Contains($currentEnvironmentAndCompany)) {
                    $currentSettingsList += $currentEnvironmentAndCompany
                } 
                break     
            }
        }
    }
    
    return $currentSettingsList
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
            
            $fileContent = Get-Content $file.FullName
            if (Select-String -Pattern $oldSetting -InputObject $fileContent) {
                Set-Content -Path $file.FullName -Value $fileContent.Replace($oldSetting, $newSetting)
                Write-Host $file.FullName" <-- updated "
            }
        }
    }
}

function Update-FlowSettingsParamterObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Object]$parametersObject,
        [Parameter(Mandatory = $true)]
        [string]$CompanyId,
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )
    # Check if parameters are for Business Central
    if ((-not $parametersObject.company) -or (-not $parametersObject.bcEnvironment)) {
        return $parametersObject
    }       
        
    # Check if parameters are already set to the correct values
    if (($parametersObject.company -eq $CompanyId) -and ($parametersObject.bcEnvironment -eq $EnvironmentName)) {
        Write-Host "No changes needed for: $FilePath"
        return $parametersObject
    }

    # Check if parameters are set using a different approach (e.g. environment variables or passed in parameters)
    if ($parametersObject.company -contains "@parameters('" -or $parametersObject.bcEnvironment -contains "@parameters('") {
        Write-Host "No changes needed for: $FilePath"
        Write-Host "Connection is set using a different approach (e.g. environment variables or passed in parameters)"
        return $parametersObject
    }

    Write-Host "Updating: $FilePath with $CompanyId and $EnvironmentName"
    $parametersObject.company = $CompanyId
    $parametersObject.bcEnvironment = $EnvironmentName
    return $parametersObject
}

function Update-FlowJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$CompanyId,
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName
    )
    # Read the JSON file
    $jsonObject = Get-Content $FilePath | ConvertFrom-Json
    
    # Update triggers
    $triggersObject = $jsonObject.properties.definition.triggers
    $triggers = $triggersObject | Get-Member -MemberType Properties
    foreach ($trigger in $triggers) {
        $parametersObject = $triggers.($trigger.Name).inputs.parameters                
        if ($parametersObject) {
            $parametersObject = Update-FlowSettingsParamterObject -parametersObject $parametersObject -CompanyId $CompanyId -EnvironmentName $EnvironmentName
        }
    }
    
    # Update actions
    $actionsObject = $jsonObject.properties.definition.actions
    $actions = $actionsObject | Get-Member -MemberType Properties
    foreach ($action in $actions) {
        $parametersObject = $actions.($action.Name).inputs.parameters
        if ($parametersObject) {
            $parametersObject = Update-FlowSettingsParamterObject -parametersObject $parametersObject -CompanyId $CompanyId -EnvironmentName $EnvironmentName
        }      
    }

    # Save the updated JSON back to the file
    $jsonObject | ConvertTo-Json -Compress -Depth 100 | Set-Content $FilePath
}

function Update-Flows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionFolder,        
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,        
        [Parameter(Mandatory = $true)]
        [string]$CompanyId
    )

    Write-Host "Updating Flow settings"
    $flowFilePaths = Get-ChildItem -Path "$SolutionFolder/workflows" -Recurse -Filter *.json | Select-Object -ExpandProperty FullName
        
    foreach ($flowFilePath in $flowFilePaths) {
        Write-Host "Updating: $flowFilePath"
        Update-FlowJson -FilePath $flowFilePath -CompanyId $CompanyId -EnvironmentName $EnvironmentName
    }        
}

function Update-PowerApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionFolder,
        
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,
        
        [Parameter(Mandatory = $true)]
        [string]$CompanyId
    )

    Write-Host "Updating PowerApp settings"        
    $currentPowerAppSettings = getCurrentPowerAppSettings -solutionFolder "$SolutionFolder/CanvasApps"
    if ($currentPowerAppSettings.Count -eq 0) {
        Write-Warning "Could not find connections file"
        throw "Could not find connections file"
    }
        
    $newSettings = "$EnvironmentName,$CompanyId"
    Write-Host "New settings: "$newSettings
        
    foreach ($currentSetting in $currentPowerAppSettings) {
        if ($currentSetting -eq $newSettings) {
            Write-Host "No changes needed for: "$currentSetting
            continue
        }
        
        Write-Host "Updating: "$currentSetting
        replaceOldSettings -oldSetting $currentSetting -newSetting $newSettings -solutionFolder "$SolutionFolder/CanvasApps"
    }
}

Write-Host "Updating Business Central environment and company settings"
Update-PowerApps -SolutionFolder $SolutionFolder -EnvironmentName $EnvironmentName -CompanyId $CompanyId
Update-Flows -SolutionFolder $SolutionFolder -EnvironmentName $EnvironmentName -CompanyId $CompanyId