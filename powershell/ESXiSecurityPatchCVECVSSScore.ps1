$esxiVersions = @("5.1.0", "5.5.0", "6.0.0", "6.5.0", "6.7.0")
$pathToStoreMetdataFile = $env:TMP

Add-Type -Assembly System.IO.Compression.FileSystem

Write-Host "Downloading ESXi Metadata Files ..."
foreach ($esxiVersion in $esxiVersions) {
    $metadataUrl = "https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/esx/vmw/vmw-ESXi-$esxiVersion-metadata.zip"
    $metadataDownloadPath = $pathToStoreMetdataFile + "\" + $esxiVersion + ".zip"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($metadataUrl,$metadataDownloadPath)

    #https://stackoverflow.com/a/41575369
    $zip = [IO.Compression.ZipFile]::OpenRead($metadataDownloadPath)
    $metadataFileExtractionPath = $pathToStoreMetdataFile + "\$esxiVersion.xml"
    $zip.Entries | where {$_.Name -like 'vmware.xml'} | foreach {[System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $metadataFileExtractionPath, $true)}
    $zip.Dispose()
    Remove-Item -Path $metadataDownloadPath -Force
}

Write-Host "Processing ESXi Metadata Files ..."
$esxiBulletinCVEesults = @()
foreach ($esxiVersion in $esxiVersions) {
    $metadataFileExtractionPath = $pathToStoreMetdataFile + "\$esxiVersion.xml"
    [xml]$XmlDocument = Get-Content -Path $metadataFileExtractionPath

    Write-Host "Extracting KB Information & CVE URLs for $esxiVersion ..." 
    foreach ($bulletin in $XmlDocument.metadataResponse.bulletin) {
        if($bulletin.category -eq "security") {
            $bulletinId = $bulletin.id
            $kbId = ($bulletin.kbUrl).Replace("http://kb.vmware.com/kb/","")

            $results = Invoke-WebRequest -Uri https://kb.vmware.com/articleview?docid=$kbId -UseBasicParsing

            $cveIds = @()
            foreach ($link in $results.Links) {
                if($link.href -match "CVE") {
                    $cveIds += ($link.href).Replace("http://cve.mitre.org/cgi-bin/cvename.cgi?name=","")
                }
            }

            if($cveIds) {
                foreach ($cveId in $cveIds) {
                    # CVE API to retrieve CVE details
                    $results = Invoke-WebRequest -Uri  http://cve.circl.lu/api/cve/$cveId -UseBasicParsing
                    $jsonResults = $results.Content | ConvertFrom-Json
                    $cvssScore = $jsonResults.cvss
                    $cvssComplexity = $jsonResults.access.complexity

                    if($cvssScore -eq $null) {
                        $cvssScore = "N/A"
                    }
                    if($cvssComplexity -eq $null) {
                        $cvssComplexity = "N/A"
                    }

                    $tmp = [PSCustomObject] @{
                        Bulletin = $bulletinId;
                        CVEId = $cveId;
                        CVSSScore = $cvssScore;
                        CVSSComplexity = $cvssComplexity;
                    }
                    $esxiBulletinCVEesults += $tmp
                }
            }
        }
    }
}

$esxiBulletinCVEesults