Function Get-vSphereLicensingDetails {
<#
    .DESCRIPTION Retrieve vSphere Licensing Information
    .NOTES  Author: William Lam, Broadcom
    .NOTES  Last Updated: 03/02/2024
    .PARAMETER IncludeHost
        Include licensing information for all ESXi hosts
    .PARAMETER IncludeCluster
        Include licensing information for all vSphere Clusters
    .PARAMETER OnlyVVF
        Include licensing information for all ESXi hosts using VMware vSphere Foundation (VVF) entitlement
    .PARAMETER OnlyVCF
        Include licensing information for all ESXi hosts using VMware Cloud Foundation (VCF) entitlement
    .EXAMPLE
        # Output only includes ESXi hosts

        Get-vSphereLicensingDetails -IncludeHost
    .EXAMPLE
        # Output only includes vSphere Clusters

        Get-vSphereLicensingDetails -IncludeCluster
    .EXAMPLE
        Output includes ESXi hosts and vSphere Clusters

        Get-vSphereLicensingDetails -IncludeHost -IncludeCluster
    .EXAMPLE
        Output includes ESXi hosts and only VVF entitlement

        Get-vSphereLicensingDetails -IncludeHost -OnlyVVF
    .EXAMPLE
        Output includes ESXi hosts and only VCF entitlement

        Get-vSphereLicensingDetails -IncludeHost -OnlyVCF
#>
    param(
        [Switch]$IncludeHost=$false,
        [Switch]$IncludeCluster=$false,
        [Switch]$OnlyVVF=$false,
        [Switch]$OnlyVCF=$false
    )

    $lm = Get-View $global:DefaultVIServer.ExtensionData.Content.LicenseManager
    $lam = Get-View $lm.LicenseAssignmentManager

    $entities = @()

    if($IncludeHost) {
        $entities += Get-View -ViewType HostSystem -Property Name
    }

    if($IncludeCluster) {
        $entities += Get-View -ViewType ClusterComputeResource -Property Name
    }

    $results = @()
    foreach ($entity in $entities) {
        $license = $lam.QueryAssignedLicenses($entity.MoRef.Value)

        $entityCost = ($license.properties | where {$_.Key -eq "entityCost"}).Value
        $expirationDate = ($license.AssignedLicense.Properties | where {$_.Key -eq "expirationDate"}).Value

        $tmp = [pscustomobject] @{
            Type = $entity.getType().Name
            Entity = $entity.Name
            LicenseName = $license.AssignedLicense.Name ? $license.AssignedLicense.Name : "N/A"
            LicenseUsage = $entityCost ? $entityCost : "N/A"
            LicenseExpiry = $expirationDate ? $expirationDate : "N/A"
            LicenseKeyId = $license.AssignedLicense.EditionKey ? $license.AssignedLicense.EditionKey : "N/A"
        }

        if($OnlyVVF -or $OnlyVCF) {
            if($OnlyVVF) {
                if($license.AssignedLicense.EditionKey -match "esx.vvf") {
                    $results+=$tmp
                }
            }

            if($OnlyVCF) {
                if($license.AssignedLicense.EditionKey -match "esx.vcf") {
                    $results+=$tmp
                }
            }
        } else {
            $results+=$tmp
        }
    }
    $results | ft
}