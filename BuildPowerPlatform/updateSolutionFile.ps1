[CmdletBinding()]
param(
    [Parameter(Position = 1, mandatory = $false)]
    [string] $version,
    [Parameter(Position = 2, mandatory = $false)]
    [string] $managed
)

function Update-VersionNode {
    param(
        [Parameter(Position = 0, mandatory = $false)]
        [string] $version,
        [Parameter(Position = 1, mandatory = $true)]
        [xml] $xml
    )
    if ($version) {
        $versionNode = $xml.SelectSingleNode("//Version");
        Write-Host "Updating version: "$version;
        $versionNode.'#text' = $version;
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
        [Parameter(Position = 0, mandatory = $false)]
        [string] $version,
        [Parameter(Position = 1, mandatory = $false)]
        [string] $managed,
        [Parameter(Position = 2, mandatory = $true)]
        [string[]] $solutionFiles
    )
    foreach ($solutionFile in $solutionFiles) {
        Write-Host "Updating solution: "$solutionFile;
        $xmlFile = [xml](Get-Content $solutionFile);

        Update-VersionNode -version $version -xml $xmlFile;
        update-ManagedNode -managed $managed -xml $xmlFile;
        
        $xmlFile.Save($solutionFile);
    }
}

function Get-PowerPlatformSolutionFiles {
    $solutionFiles = Get-ChildItem -Path . -Filter "solution.xml" -Recurse -File;
    return $solutionFiles.FullName;
}

$solutionFiles = Get-PowerPlatformSolutionFiles;
Update-SolutionFiles -version $version -managed $managed -solutionFiles $solutionFiles;



