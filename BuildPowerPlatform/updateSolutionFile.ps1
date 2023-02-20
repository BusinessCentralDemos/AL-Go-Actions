[CmdletBinding()]
param(
    [Parameter(Position = 0, mandatory = $true)]
    [string] $solutionFolder,
    [Parameter(Position = 1, mandatory = $true)]
    [string] $appBuild,
    [Parameter(Position = 2, mandatory = $true)]
    [string] $appRevision,
    [Parameter(Position = 3, mandatory = $false)]
    [string] $managed
)

function Update-VersionNode {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $appBuild,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $appRevision,
        [Parameter(Position = 2, mandatory = $true)]
        [xml] $xml
    )

    if ($appBuild -and $appRevision) {
        Write-Host "Updating version";
        $versionNode = $xml.SelectSingleNode("//Version");
        $versionNodeText = $versionNode.'#text';
        
        $versionParts = $versionNodeText.Split('.');
        $newVersionNumber = $versionParts[0] + '.' + $versionParts[1] + '.' + $appBuild + '.' + $appRevision;

        Write-Host "New version: "$newVersionNumber;
        $versionNode.'#text' = $newVersionNumber;
    }
    else {
        Write-Host "Skipping version update since appBuild and appRevision are not set ($appBuild, $appRevision)";
    }
}

function Update-ManagedNode {
    param(
        [Parameter(Position = 0, mandatory = $false)]
        [string] $managed,
        [Parameter(Position = 1, mandatory = $true)]
        [xml] $xml
    )
    
    $managedValue = "0";
    if ($managed -eq "true") {
        $managedValue = "1";
    }

    $nodeWithName = $xml.SelectSingleNode("//Managed");
    Write-Host "Updating managed flag: "$managedValue;
    $nodeWithName.'#text' = $managedValue;    
}

function Update-SolutionFiles {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $appBuild,
        [Parameter(Position = 1, mandatory = $true)]
        [string] $appRevision,
        [Parameter(Position = 2, mandatory = $false)]
        [string] $managed,
        [Parameter(Position = 3, mandatory = $true)]
        [string[]] $solutionFiles
    )
    foreach ($solutionFile in $solutionFiles) {
        Write-Host "Updating solution: "$solutionFile;
        $xmlFile = [xml](Get-Content $solutionFile);

        Update-VersionNode -appBuild $appBuild -appRevision $appRevision -xml $xmlFile;
        Update-ManagedNode -managed $managed -xml $xmlFile;
        
        $xmlFile.Save($solutionFile);
    }
}

function Get-PowerPlatformSolutionFiles {
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string] $solutionFolder
    )
    $solutionFiles = Get-ChildItem -Path $solutionFolder -Filter "solution.xml" -Recurse -File;
    return $solutionFiles.FullName;
}

Write-Host "Updating Power Platform solution files";
# When we use the solution folder we should only get 1 solution file - the script is just written so it can handle multiple solution files in the future
Update-SolutionFiles -appBuild $appBuild -appRevision $appRevision -managed $managed -solutionFiles $solutionFiles;
