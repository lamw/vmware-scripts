# vSAN DP OVA Path
$vsanDPOVA = "/Volumes/software/VMware OVA/snapservice_appliance-8.0.3.0-24057802_OVF10.ova"

# Deployment Configuration
$vsanDPVMName = "snap.primp-industries.local"
$vsanDPCluster = "Supermicro-Cluster"
$vsanDPDatastore = "sm-vsanDatastore"
$vsanDPVMNetwork = "Management"

# OVF Property Values
$vsanDPRootPassword = "VMware1!VMware1!"
$vsanDPHostname = "snap.primp-industries.local"
$vsanDPIPAddress = "192.168.30.96"
$vsanDPPrefix = "24"
$vsanDPGateway = "192.168.30.1"
$vsanDPDNS = "192.168.30.2"
$vsanDPDNSDomain = "primp-industries.local"
$vsanDPDNSSearch = "primp-industries.local"
$vsanDPvCenterServer = "vcsa.primp-industries.local"
$vsanDPvCenterServerUsername = "administrator@vsphere.local"
$vsanDPvCenterServerPassword = "VMware1!"
$vsanDPvCenterServerSSODomain = "vsphere.local"

#### DO NOT EDIT BEYOND HERE

# https://gist.github.com/jstangroome/5945820
function  Get-VCCertificate {
    param (
        [string]$Server,
        [int]$Port
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient($Server, $Port)
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({ $true }))
        $sslStream.AuthenticateAsClient($Server, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)
        $cert = $sslStream.RemoteCertificate
        $tcpClient.Close()
        return $cert
    } catch {
        Write-Error "Failed to retrieve SSL certificate: $_"
    }
}

# Get vCenter Server TLS Certificate
$cert = Get-VCCertificate -ComputerName $vsanDPvCenterServer
$vccert = "-----BEGIN CERTIFICATE-----" + $([System.Convert]::ToBase64String($cert.GetRawCertData()))+ "-----END CERTIFICATE-----"

$ovfconfig = Get-OvfConfiguration $vsanDPOVA
$ovfconfig.Common.vami.hostname.Value = $vsanDPHostname
$ovfconfig.Common.varoot_password.Value = $vsanDPRootPassword
$ovfconfig.NetworkMapping.Network_1.Value = $vsanDPVMNetwork
$ovfconfig.vami.VMware_SnapshotService_Appliance.addrfamily.Value = "ipv4"
$ovfconfig.vami.VMware_SnapshotService_Appliance.ip0.Value = $vsanDPIPAddress
$ovfconfig.vami.VMware_SnapshotService_Appliance.prefix0.Value = $vsanDPPrefix
$ovfconfig.vami.VMware_SnapshotService_Appliance.gateway.Value = $vsanDPGateway
$ovfconfig.vami.VMware_SnapshotService_Appliance.dns.Value = $vsanDPDNS
$ovfconfig.vami.VMware_SnapshotService_Appliance.domain.Value = $vsanDPDNSDomain
$ovfconfig.vami.VMware_SnapshotService_Appliance.searchpath.Value = $vsanDPDNSSearch
$ovfconfig.vcenter.VMware_SnapshotService_Appliance.hostname.Value = $vsanDPvCenterServer
$ovfconfig.vcenter.VMware_SnapshotService_Appliance.vcusername.Value = $vsanDPvCenterServerUsername
$ovfconfig.vcenter.VMware_SnapshotService_Appliance.vcuserpassword.Value = $vsanDPvCenterServerPassword
$ovfconfig.vcenter.VMware_SnapshotService_Appliance.vcdomain.Value = $vsanDPvCenterServerSSODomain
$ovfconfig.vcenter.VMware_SnapshotService_Appliance.vccert.Value = $vccert

$VMHost = Get-Cluster $vsanDPCluster| Get-VMHost | Select -first 1

Write-Host -ForegroundColor Green  "Deploying vSAN Data Protection VM ..."
$vm = Import-VApp -Source $vsanDPOVA -OvfConfiguration $ovfconfig -Name $vsanDPVMName -Location $vsanDPCluster -VMHost $VMHost -Datastore $vsanDPDatastore -DiskStorageFormat thin -Force

Write-Host -ForegroundColor Green "Powering on vSAN Data Protection $vsanDPVMName ..."
$vm | Start-VM -Confirm:$false | Out-Null
