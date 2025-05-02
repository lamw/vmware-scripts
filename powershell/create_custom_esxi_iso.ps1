# Author: William Lam
# Website: www.williamlam.com

# Path to ESXi Base Offline Image
$ESXIBaseImagePath = "C:\Users\william\Desktop\custom-esxi-image\VMware-ESXi-7.0U3c-19193900-depot.zip"

# List of ESXi Offline Bundle Paths
$ESXIDriverPaths = @(
"C:\Users\william\Desktop\custom-esxi-image\Net-Community-Driver_1.2.2.0-1vmw.700.1.0.15843807_18835109.zip",
"C:\Users\william\Desktop\custom-esxi-image\nvme-community-driver_1.0.1.0-3vmw.700.1.0.15843807-component-18902434.zip"
)

$ESXICustomIsoSpec = "C:\Users\william\Desktop\custom-esxi-image\spec.json"

$ESXICustomIsoPath = "C:\Users\william\Desktop\custom-esxi-image\custom.iso"

##### DO NOT EDIT BEYOND HERE #####

if($PSVersionTable.PSEdition -ne "Desktop") {
    Write-Error "This script is only supported with PowerShell on Windows`n"
    exit
}

Write-Host -Foreground cyan "Processing ESXi Base Image $ESXIBaseImagePath ..."
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
