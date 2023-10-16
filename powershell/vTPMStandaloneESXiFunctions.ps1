# Author: William Lam
# Description: PowerCLI functions to configure host encryption for a standanlone ESXi host to support vTPM without vCenter Server

Function New-256BitKey {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns randomly generated 256 bit key encoded using base64
    .EXAMPLE
        New-256BitKey
#>
    # Generate 256 bit key
    # Thank you ChatGPT for this code
    $randomKey = [byte[]]::new(32)
    $rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rand.GetBytes($randomKey)

    # Encode the key using Base64
    return [Convert]::ToBase64String($randomKey)
}

Function Prepare-VMHostForEncryption {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function prepares the ESXi host for encryption
    .EXAMPLE
        Prepare-VMHostForEncryption
#>
    $cm = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

    $cryptoState = (Get-VMHost).ExtensionData.Runtime.CryptoState

    if($cryptoState -eq "incapable") {
        Write-Host -ForegroundColor Yellow "`nPreparing ESXi Host for encryption ..."
        $cm.CryptoManagerHostPrepare()
        Write-Host -ForegroundColor Green "Successfully prepared ESXi Host for encryption ...`n"
    } else {
        Write-Host "`nESXi Host has already been prepared for encryption ...`n"
    }
}

Function New-InitialVMHostKey {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function creates and/or ipmorts host key
    .PARAMETER Operation
        CREATE or IMPORT
    .PARAMETER KeyName
        Name of the VM Key
    .PARAMETER CSVTPMKeyFile
        Name of CSV file to save TPM keys (Default: tpm-keys.csv)
    .EXAMPLE
        # Request new VM Key
        New-InitialVMHostKey -Operation CREATE -KeyName "host-key-1"
    .EXAMPLE
        # Imports an existing VM Key
        New-InitialVMHostKey -Operation IMPORT -KeyName "host-key-1" -CSVTPMKeyFile tpm-keys.csv

#>
    param(
        [Parameter(Mandatory=$true)][ValidateSet("CREATE","IMPORT")][string]$Operation,
        [Parameter(Mandatory=$true)][String]$KeyName,
        [Parameter(Mandatory=$false)][String]$CSVTPMKeyFile="tpm-keys.csv"
    )

    $cryptoState = (Get-VMHost).ExtensionData.Runtime.CryptoState

    if($cryptoState -eq "safe") {
        Write-Host -ForegroundColor Red "`nESXi host has already been configured with initial host key ...`n"
        break
    }

    if($cryptoState -ne "prepared") {
        Write-Host -ForegroundColor Red "`nESXi host has not been prepared for encryption ...`n"
        break
    }

    $cm = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

    # Create or import initial host key
    if($Operation -eq "CREATE") {
        Write-Host -ForegroundColor Yellow "Generating random 256 bit host key ..."
        $hostBase64Key = New-256BitKey
        $keyAlgorithim = "AES-256"
    } else {
        $csvfile = Import-Csv $CSVTPMKeyFile
        foreach ($line in $csvfile) {
            if($line.KEYID -eq $KeyName -and $line.TYPE -eq "HOST") {
                Write-Host -ForegroundColor Yellow "Importing existing host key from $CSVTPMKeyFile ..."
                $hostBase64Key = $line.DATA
                $keyAlgorithim = $line.ALGORITHIM
                break
            }
        }
    }

    if($hostBase64Key -eq $null) {
        Write-Host -ForegroundColor Red "Failed to find host key ${KeyName} ...`n"
        break
    }

    $hostKeyId = New-Object VMware.Vim.CryptoKeyId
    $hostKeyId.keyId = $KeyName

    $hostKeySpec = New-Object VMware.Vim.CryptoKeyPlain
    $hostKeySpec.KeyId = $hostKeyId
    $hostKeySpec.Algorithm = $keyAlgorithim
    $hostKeySpec.KeyData = $hostBase64Key

    Write-Host -ForegroundColor Yellow "Adding ESXi Host Key ${KeyName} ..."
    try {
        $cm.CryptoManagerHostEnable($hostKeySpec)
    } catch {
        Write-Host -ForegroundColor Red "Failed to add host key ${KeyName} ...`n"
        break
    }

    # Automatically backup host key to CSV file
    if($Operation -eq "CREATE") {
        if (Test-Path -Path $CSVTPMKeyFile -PathType Leaf) {
            Write-Host -ForegroundColor Yellow "ESXi TPM Keys file $CSVTPMKeyFile exists, please use import operation"
        } else {
            $newcsv = {} | Select "KEYID","ALGORITHIM","TYPE","DATA" | Export-Csv $CSVTPMKeyFile
            $csvfile = Import-Csv $CSVTPMKeyFile
            $csvfile.KEYID = $KeyName
            $csvfile.ALGORITHIM = $keyAlgorithim
            $csvfile.TYPE = "HOST"
            $csvfile.DATA = $hostBase64Key
            Write-Host -ForegroundColor Yellow "Exporting ${KeyName} to $CSVTPMKeyFile ..."
            $csvfile | Export-CSV -Path $CSVTPMKeyFile
        }
    }
    Write-Host -ForegroundColor Green "Successfully added initial host encryption key ${KeyName} ...`n"
}

Function New-VMTPMKey {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function creates and/or ipmorts Host key
    .PARAMETER Operation
        CREATE or IMPORT
    .PARAMETER KeyName
        Name of the VM Key
    .PARAMETER CSVTPMKeyFile
        Name of CSV file to save TPM keys (Default: tpm-keys.csv)
    .EXAMPLE
        # Request new Host Key
        New-VMTPMKey -Operation CREATE -KeyName "windows-11-key"
    .EXAMPLE
        # Imports an existing Host Key
        New-VMTPMKey -Operation IMPORT -KeyName "windows-11-key" -CSVTPMKeyFile tpm-keys.csv

#>
    param(
        [Parameter(Mandatory=$true)][ValidateSet("CREATE","IMPORT")][string]$Operation,
        [Parameter(Mandatory=$true)][String]$KeyName,
        [Parameter(Mandatory=$false)][String]$CSVTPMKeyFile="tpm-keys.csv"
    )

    $cm = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

    # Ensure ESXi host encryption is enabled
    if($cm.Enabled) {
        # Create or import VM key
        if($Operation -eq "CREATE") {
            Write-Host -ForegroundColor Yellow "Generating random 256 bit VM key ..."
            $vmBase64Key = New-256BitKey
            $keyAlgorithim = "AES-256"
        } else {
            $csvfile = Import-Csv $CSVTPMKeyFile
            foreach ($line in $csvfile) {
                if($line.KEYID -eq $KeyName -and $line.TYPE -eq "VM") {
                    Write-Host -ForegroundColor Yellow "Importing existing VM key from $CSVTPMKeyFile ..."
                    $vmBase64Key = $line.DATA
                    $keyAlgorithim = $line.ALGORITHIM
                    break
                }
            }
        }

        if($vmBase64Key -eq $null) {
            Write-Host -ForegroundColor Red "Failed to find VM key ${KeyName} ...`n"
            break
        }

        $vmKeyId = New-Object VMware.Vim.CryptoKeyId
        $vmKeyId.keyId = $KeyName

        $vmKeySpec = New-Object VMware.Vim.CryptoKeyPlain
        $vmKeySpec.KeyId = $vmKeyId
        $vmKeySpec.Algorithm = $keyAlgorithim
        $vmKeySpec.KeyData = $vmBase64Key

        Write-Host -ForegroundColor Yellow "Adding VM key ${KeyName} ..."
        try {
            $cm.AddKey($vmKeySpec)
        } catch {
            Write-Host -ForegroundColor Red "Failed to add VM key ${KeyName} ...`n"
            break
        }

        # Automatically backup VM key to CSV file
        if($Operation -eq "CREATE") {
            if (Test-Path -Path $CSVTPMKeyFile -PathType Leaf) {
                $tmp = [PSCustomObject] [ordered]@{
                    KEYID = $KeyName;
                    ALGORITHIM = $keyAlgorithim;
                    TYPE = "VM";
                    DATA = $vmBase64Key
                }
                Write-Host -ForegroundColor Yellow "Exporting ${KeyName} to $CSVTPMKeyFile ..."
                $tmp | Export-CSV -Append -NoTypeInformation -Path $CSVTPMKeyFile
            } else {
                Write-Error "Unable to find $CSVTPMKeyFile ..."
            }
        }
        Write-Host -ForegroundColor Green "Successfully added VM encryption key ${KeyName} ...`n"
    } else {
        Write-Host -ForegroundColor Red "`nESXi host has not been prepared for encryption ...`n"
    }
}

Function Remove-VMTPMKey {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function removes an existing VM key
    .PARAMETER KeyName
        Name of the VM Key
    .PARAMETER Force
        Force remove VM Key
    .EXAMPLE
        # Remove VM key
        Remove-VMTPMKey -KeyName "windows-11-key"
    .EXAMPLE
        # Forcefully remove VM key
        Remove-VMTPMKey -KeyName "windows-11-key" -Force $true
#>
    param(
        [Parameter(Mandatory=$true)][String]$KeyName,
        [Parameter(Mandatory=$false)][Boolean]$Force=$false
    )

    $cm = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

    $key = $cm.ListKeys($null) | where {$_.KeyId -eq $KeyName}
    Write-Host -ForegroundColor Yellow "Removing VM key ${KeyName} ..."
    try {
        $cm.RemoveKey($key,$Force)
    } catch {
        Write-Host -ForegroundColor Red "Failed to remove VM key, maybe in use or use -Force option to forcefully remove ...`n"
        break
    }
    Write-Host -ForegroundColor Green "Successfully removed VM key ...`n"
}

Function Get-VMHostTPMKeys {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns all Host/VM keys
    .EXAMPLE
        Get-VMHostTPMKeys
#>

    $cm = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

    if($cm.Enabled) {
        $cm.ListKeys($null)
    } else {
        Write-Host -ForegroundColor Red "`nESXi host has not been prepared for encryption or does not contain initial host key ...`n"
    }
}
Function Reconfigure-VMWithvTPM {
<#
    .NOTES
    ===========================================================================
    Created by:    William Lam
    Organization:  VMware
    Blog:          www.williamlam.com
    Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function adds vTPM to existing VM and applies an existing VM key for encryption
    .PARAMETER KeyName
        Name of the VM Key
    .PARAMETER VMName
        Name of the VM to add vTPM
    .EXAMPLE
        Reconfigure-VMWithvTPM -KeyName "windows-11-key" -VMName "Windows-11"
#>
    param(
        [Parameter(Mandatory=$true)][String]$KeyName,
        [Parameter(Mandatory=$true)][String]$VMName
    )

    $vm = Get-VM $VMName

    $cm = Get-View $global:DefaultVIServer.ExtensionData.Content.CryptoManager

    # Retrieve VM key
    $cryptoSpec = New-Object VMware.Vim.CryptoSpecEncrypt
    $cryptoSpec.CryptoKeyId = $cm.ListKeys($null) | where {$_.KeyId -eq $KeyName}

    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

    # Set VM encryption key
    $spec.Crypto = $cryptoSpec

    # Add TPM device
    $spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $spec.deviceChange[0].operation = 'add'
    $spec.deviceChange[0].device = New-Object VMware.Vim.VirtualTPM
    $spec.DeviceChange[0].Device.Key = 11000

    # Reconfigure VM
    Write-Host -ForegroundColor Yellow "Adding vTPM to ${VMName} using encryption key ${KeyName} ..."
    $task = $vm.ExtensionData.ReconfigVM_Task($spec)
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task
}
