Function Get-VSphereCertificateDetails {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns the certificate mode of vCenter Server along with
        the certificate details of each ESXi hosts being managed by vCenter Server
    .EXAMPLE
        Get-VSphereCertificateDetails
#>
    if($global:DefaultVIServer.ProductLine -eq "vpx") {
        $vCenterCertMode = (Get-AdvancedSetting -Entity $global:DefaultVIServer -Name vpxd.certmgmt.mode).Value
        Write-Host -ForegroundColor Cyan "`nvCenter $(${global:DefaultVIServer}.Name) Certificate Mode: $vCenterCertMode"
    }

    $results = @()
    $vmhosts = Get-View -ViewType HostSystem -Property Name,ConfigManager.CertificateManager
    foreach ($vmhost in $vmhosts) {
        $certConfig = (Get-View $vmhost.ConfigManager.CertificateManager).CertificateInfo
        if($certConfig.Subject -match "vmca@vmware.com") {
            $certType = "VMCA"
        } else {
            $certType = "Custom"
        }
        $tmp = [PSCustomObject] @{
            VMHost = $vmhost.Name;
            CertType = $certType;
            Status = $certConfig.Status;
            Expiry = $certConfig.NotAfter;
        }
        $results+=$tmp
    }
    $results
}
