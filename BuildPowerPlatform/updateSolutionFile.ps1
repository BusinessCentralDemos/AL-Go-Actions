[CmdletBinding()]
param(
    [Parameter(Position = 0, mandatory = $true)]
    [string] $appBuild,
    [Parameter(Position = 1, mandatory = $true)]
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
    if ($version) {
        Write-Host "Updating version";
        $versionNode = $xml.SelectSingleNode("//Version");
        $versionNodeText = $versionNode.'#text';
        
        $versionParts = $versionNodeText.Split('.');
        $newVersionNumber = $versionParts[0] + '.' + $versionParts[1] + '.' + $appBuild + '.' + $appRevision;

        Write-Host "New version: "$newVersionNumber;
        $versionNode.'#text' = $newVersionNumber;
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
        Update-ManagedNode -managed $managed -xml $xmlFile;
        
        $xmlFile.Save($solutionFile);
    }
}

function Get-PowerPlatformSolutionFiles {
    $solutionFiles = Get-ChildItem -Path . -Filter "solution.xml" -Recurse -File;
    return $solutionFiles.FullName;
}

$solutionFiles = Get-PowerPlatformSolutionFiles;
Update-SolutionFiles -version $version -managed $managed -solutionFiles $solutionFiles;
