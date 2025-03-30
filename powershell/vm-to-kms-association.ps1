$cryptoManager = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

$kmsServers = @{}
foreach ($i in $cryptoManager.KmipServers) {
    if($i.ManagementType -eq "nativeProvider") {
        $type = "NKP"
    } else { $type = "SKP"}

    $kmsServers.add($i.ClusterId.id,$type)
}

$vms = Get-View -ViewType VirtualMachine -Property Name, Config

$kmsVms = @()
foreach ($vm in $vms | Sort-Object -Property Name) {
    if($vm.Config.KeyId -ne $null) {
        $tmp = [pscustomobject]@{
            Name = $vm.Name
            KMS = $vm.Config.KeyId.ProviderId.id
            KeyId = $vm.Config.KeyId.keyId
        }
        $kmsVms+=$tmp
    }
}

Write-Host -ForegroundColor Cyan "`n==== vCenter Key Providers ===="
$kmsServers

Write-Host -ForegroundColor yellow "`n==== VM Key Provider Mapping ===="
$kmsVms | ft
