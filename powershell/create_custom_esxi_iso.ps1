# Author: William Lam
# Website: www.williamlam.com

# ESXi Offline Depot
$ESXIBaseImagePath = "VMware-ESXi-9.0.1.0.24957456-depot.zip"

# List of ESXi Offline Bundle Drivers
$ESXIDriverPaths = @("VMware-Re-Driver_1.101.01-5vmw.800.1.0.20613240.zip")

$ESXICustomIsoSpec = "esx-9.0.1.0-realtek.spec"
$ESXICustomIsoPath = "esx-9.0.1.0-realtek.iso"

##### DO NOT EDIT BEYOND HERE #####

if((Get-PowerCLIVersion).Major -lt "9") {
    Write-Error "This script requires VCF.PowerCLI 9.x or greater`n"
    exit
}

Write-Host -Foreground cyan "Processing ESXi Base Image $ESXIDriver ..."
$ESXIBaseImageVersion = (Get-DepotBaseImages -Depot $ESXIBaseImagePath).Version

# Build list of Components from ESXi Drivers
$components = @{}
foreach ($ESXIDriver in $ESXIDriverPaths) {
    Write-Host -Foreground cyan "Processing ESXi Driver $ESXIDriver ..."
    $component = (Get-DepotComponents -Depot $ESXIDriver) | Select Name, Version
    $components.Add(${component}.name,${component}.version)
}

# Create Software Spec
$spec = [ordered] @{
    base_image = @{
        version = $ESXIBaseImageVersion
    }
    components = $components
}
$spec | ConvertTo-Json | Set-Content -NoNewline -Path $ESXICustomIsoSpec

# Build Depo List
$ESXIDepots = '"' + $(($ESXIDriverPaths+=$ESXIBaseImagePath) -join '","') + '"'
$ESXICustomIsoSpec = '"' + $ESXICustomIsoSpec + '"'
$ESXICustomIsoPath = '"' + $ESXICustomIsoPath + '"'

# Create New Custom ISO
Write-Host -Foreground green "`nCreating Custom ESXi ISO and saving to ${ESXICustomIsoPath} ...`n"
Invoke-Expression "New-IsoImage -Depots $ESXIDepots -SoftwareSpec $ESXICustomIsoSpec -Destination $ESXICustomIsoPath"