Function PlayGame {
    param(
        [Parameter(Mandatory=$true)][String]$VMName,
        [Parameter(Mandatory=$false)][Boolean]$ReturnCarriage,
        [Parameter(Mandatory=$false)][Boolean]$DebugOn
    )

    # Map subset of USB HID keyboard scancodes
    # https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2
    $movements = @{
        'LEFT'='0x5c';
        'RIGHT'='0x5e';
    }

    $vm = Get-View -ViewType VirtualMachine -Filter @{"Name"=$VMName}

	# Verify we have a VM or fail
    if(!$vm) {
        Write-host "Unable to find VM $VMName"
        return
    }

    # Start Game #

    $hidCode = "0x3b" # F2
    $tmp = New-Object VMware.Vim.UsbScanCodeSpecKeyEvent
    $modifer = New-Object Vmware.Vim.UsbScanCodeSpecModifierType
    $modifer.LeftGui = $true
    $tmp.Modifiers = $modifer
    $hidCodeHexToInt = [Convert]::ToInt64($hidCode,"16")
    $hidCodeValue = ($hidCodeHexToInt -shl 16) -bor 0007
    $tmp.UsbHidCode = $hidCodeValue
    $hidCodesEvents+=$tmp
    $spec = New-Object Vmware.Vim.UsbScanCodeSpec
    $spec.KeyEvents = $hidCodesEvents

    Write-Host ""
    [void](Read-Host 'Press Enter to start playing game using the vSphere API …')
    $results = $vm.PutUsbScanCodes($spec)

    # Play Game #

    $hidCodesEvents = @()
    foreach ($count in 1..500) {
        $randomNumber = Get-Random -Maximum 3 -Minimum 1
        if($randomNumber -eq 1) {
            $character = "LEFT"
        } elseif($randomNumber -eq 2) {
            $character = "RIGHT"
        } else {
            $character = "DOWN"
        }
        $hidCode = $movements[[string]$character]
        $tmp = New-Object VMware.Vim.UsbScanCodeSpecKeyEvent

        # Convert to expected HID code format
        $hidCodeHexToInt = [Convert]::ToInt64($hidCode,"16")
        $hidCodeValue = ($hidCodeHexToInt -shl 16) -bor 0007

        $tmp.UsbHidCode = $hidCodeValue
        $hidCodesEvents+=$tmp

        if($DebugOn) {
            Write-Host "Character: $character -> HIDCode: $hidCode -> HIDCodeValue: $hidCodeValue"
        }
        # Call API to send keystrokes to VM
        $spec = New-Object Vmware.Vim.UsbScanCodeSpec
        $spec.KeyEvents = $hidCodesEvents
        Write-Host
        if($randomNumber -eq 1) {
            Write-Host -ForegroundColor Cyan "Sending $character key to $VMName"
        } else {
            Write-Host -ForegroundColor Green "Sending $character key to $VMName"
        }
        $results = $vm.PutUsbScanCodes($spec)
        Start-Sleep -Seconds 1
    }
}

$vmName ="Windows10-VM-From-VMTX-Template"

PlayGame -VMName $vmName