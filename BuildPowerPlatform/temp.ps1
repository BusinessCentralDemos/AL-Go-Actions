
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
        
        if (-not $parametersObject) {
            continue
        }
        $parametersObject = Update-FlowSettingsParamterObject -parametersObject $parametersObject -CompanyId $CompanyId -EnvironmentName $EnvironmentName
    }
    
    # Update actions
    $actionsObject = $jsonObject.properties.definition.actions
    $actions = $actionsObject | Get-Member -MemberType Properties
    foreach ($action in $actions) {
        $parametersObject = $actions.($action.Name).inputs.parameters
        
        if (-not $parametersObject) {
            continue
        }      
        $parametersObject = Update-FlowSettingsParamterObject -parametersObject $parametersObject -CompanyId $CompanyId -EnvironmentName $EnvironmentName
    }

    # Save the updated JSON back to the file
    $jsonObject | ConvertTo-Json -Depth 100 | Set-Content $FilePath
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

Update-Flows -SolutionFolder .\PPSolution -EnvironmentName Anders -CompanyId 1234