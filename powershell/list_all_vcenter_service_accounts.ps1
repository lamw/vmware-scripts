# William Lam
# List all Service Accounts in vCenter Server 9.x

$vcenterVMName = "vc01"
$vcenterSSOAdminPassword = "VMware1!VMware1!"
$vcenterRootPassword = "VMware1!VMware1!"

# Extract the vCenter SCA ID
$venterSCAId = (Invoke-VMScript -ScriptText "cat /etc/vmware/install-defaults/sca.hostid" -vm (Get-VM $vcenterVMName) -GuestUser "root" -GuestPassword $vcenterRootPassword).ScriptOutput

# Retreive vCenter Service Accounts
$results = (Invoke-VMScript -ScriptText "/usr/lib/vmware-vmafd/bin/dir-cli svcaccount list --password ${vcenterSSOAdminPassword}" -vm (Get-VM $vcenterVMName) -GuestUser "root" -GuestPassword $VCSARootPassword).ScriptOutput

# Split by newlines, remove numbering, and trim
$entries = $results -split "`r?`n" |
    ForEach-Object { $_ -replace '^\s*\d+\.\s*', '' } |
    Where-Object { $_.Trim() -ne "" }

$vcenterServiceAccounts = @()
$vcfServiceAccounts = @()
$otherAccounts = @()

foreach ($entry in $entries) {
    if ($entry -match $venterSCAId) {
        $vcenterServiceAccounts += $entry
    }
    elseif ($entry -match '^svc-') {
        $vcfServiceAccounts += $entry
    }
    else {
        $otherAccounts += $entry
    }
}

Write-Host "`nVCF Service Accounts:"
$vcfServiceAccounts

Write-Host "`nOther vCenter Service Accounts:"
$otherAccounts

Write-Host "`nvCenter Service Accounts ($venterSCAId):"
$vcenterServiceAccounts