<#PSScriptInfo
.VERSION 1.0.0
.GUID 4b78ccc0-dfb5-44bb-b550-1cfb0b194585
.AUTHOR William Lam
.COMPANYNAME VMware
.COPYRIGHT Copyright 2020, William Lam
.TAGS VMware ScanCode
.LICENSEURI
.PROJECTURI https://github.com/lamw/vghetto-scripts/blob/master/powershell/VMKeystrokes.ps1
.ICONURI https://blogs.vmware.com/virtualblocks/files/2018/10/PowerCLI.png
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    1.0.0 - Initial Release
.PRIVATEDATA
.DESCRIPTION This function sends a series of character keystrokse to a particular vSphere VM
#>
Function Set-VMKeystrokes {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
    ===========================================================================
    .PARAMETER VMName
        The name of a VM to send keystrokes to
    .PARAMETER StringInput
        The string of characters to send to VM
    .PARAMETER DebugOn
        Enable debugging which will output input charcaters and their mappings
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "root"
        Push "root" to VM $VM
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "root" -ReturnCarriage $true
        Push "root" with return line to VM $VM
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "root" -DebugOn $true
        Push "root" to VM $VM with some debug
    ===========================================================================
     Modified by:   David Rodriguez
     Organization:  Sysadmintutorials
     Blog:          www.sysadmintutorials.com
     Twitter:       @systutorials
    ===========================================================================
    .MODS
        Made $StringInput Optional
        Added a $SpecialKeyInput - See PARAMETER SpecialKeyInput below
        Added description to write-hosts [SCRIPTINPUT] OR [SPECIALKEYINPUT]
    .PARAMETER StringInput
        The string of single characters to send to the VM
    .PARAMETER SpecialKeyInput
        All Function Keys i.e. F1 - F12
        Keyboard TAB, ESC, BACKSPACE, ENTER
        Keyboard Up, Down, Left Right
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -SpecialKeyInput "F2"
        Push SpecialKeyInput F2 to VM $VM
#>
    param(
        [Parameter(Mandatory = $true)][String]$VMName,
        [Parameter(Mandatory = $false)][String]$StringInput,
        [Parameter(Mandatory = $false)][String]$SpecialKeyInput,
        [Parameter(Mandatory = $false)][Boolean]$ReturnCarriage,
        [Parameter(Mandatory = $false)][Boolean]$DebugOn
    )

    # Map subset of USB HID keyboard scancodes
    # https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2
    $hidCharacterMap = @{
        "a"            = "0x04";
        "b"            = "0x05";
        "c"            = "0x06";
        "d"            = "0x07";
        "e"            = "0x08";
        "f"            = "0x09";
        "g"            = "0x0a";
        "h"            = "0x0b";
        "i"            = "0x0c";
        "j"            = "0x0d";
        "k"            = "0x0e";
        "l"            = "0x0f";
        "m"            = "0x10";
        "n"            = "0x11";
        "o"            = "0x12";
        "p"            = "0x13";
        "q"            = "0x14";
        "r"            = "0x15";
        "s"            = "0x16";
        "t"            = "0x17";
        "u"            = "0x18";
        "v"            = "0x19";
        "w"            = "0x1a";
        "x"            = "0x1b";
        "y"            = "0x1c";
        "z"            = "0x1d";
        "1"            = "0x1e";
        "2"            = "0x1f";
        "3"            = "0x20";
        "4"            = "0x21";
        "5"            = "0x22";
        "6"            = "0x23";
        "7"            = "0x24";
        "8"            = "0x25";
        "9"            = "0x26";
        "0"            = "0x27";
        "!"            = "0x1e";
        "@"            = "0x1f";
        "#"            = "0x20";
        "$"            = "0x21";
        "%"            = "0x22";
        "^"            = "0x23";
        "&"            = "0x24";
        "*"            = "0x25";
        "("            = "0x26";
        ")"            = "0x27";
        "_"            = "0x2d";
        "+"            = "0x2e";
        "{"            = "0x2f";
        "}"            = "0x30";
        "|"            = "0x31";
        ":"            = "0x33";
        "`""           = "0x34";
        "~"            = "0x35";
        "<"            = "0x36";
        ">"            = "0x37";
        "?"            = "0x38";
        "-"            = "0x2d";
        "="            = "0x2e";
        "["            = "0x2f";
        "]"            = "0x30";
        "\"            = "0x31";
        "`;"           = "0x33";
        "`'"           = "0x34";
        ","            = "0x36";
        "."            = "0x37";
        "/"            = "0x38";
        " "            = "0x2c";
        "F1"           = "0x3a";
        "F2"           = "0x3b";
        "F3"           = "0x3c";
        "F4"           = "0x3d";
        "F5"           = "0x3e";
        "F6"           = "0x3f";
        "F7"           = "0x40";
        "F8"           = "0x41";
        "F9"           = "0x42";
        "F10"          = "0x43";
        "F11"          = "0x44";
        "F12"          = "0x45";
        "TAB"          = "0x2b";
        "KeyUp"        = "0x52";
        "KeyDown"      = "0x51";
        "KeyLeft"      = "0x50";
        "KeyRight"     = "0x4f";
        "KeyESC"       = "0x29";
        "KeyBackSpace" = "0x2a";
        "KeyEnter"     = "0x28";
    }

    $vm = Get-View -ViewType VirtualMachine -Filter @{"Name" = "^$($VMName)$" }

    # Verify we have a VM or fail
    if (!$vm) {
        Write-host "Unable to find VM $VMName"
        return
    }

    #Code for -StringInput
    if ($StringInput) {
        $hidCodesEvents = @()
        foreach ($character in $StringInput.ToCharArray()) {
            # Check to see if we've mapped the character to HID code
            if ($hidCharacterMap.ContainsKey([string]$character)) {
                $hidCode = $hidCharacterMap[[string]$character]

                $tmp = New-Object VMware.Vim.UsbScanCodeSpecKeyEvent

                # Add leftShift modifer for capital letters and/or special characters
                if ( ($character -cmatch "[A-Z]") -or ($character -match "[!|@|#|$|%|^|&|(|)|_|+|{|}|||:|~|<|>|?|*]") ) {
                    $modifer = New-Object Vmware.Vim.UsbScanCodeSpecModifierType
                    $modifer.LeftShift = $true
                    $tmp.Modifiers = $modifer
                }

                # Convert to expected HID code format
                $hidCodeHexToInt = [Convert]::ToInt64($hidCode, "16")
                $hidCodeValue = ($hidCodeHexToInt -shl 16) -bor 0007

                $tmp.UsbHidCode = $hidCodeValue
                $hidCodesEvents += $tmp

                if ($DebugOn) {
                    Write-Host "[StringInput] Character: $character -> HIDCode: $hidCode -> HIDCodeValue: $hidCodeValue"
                }
            }
            else {
                Write-Host "[StringInput] The following character `"$character`" has not been mapped, you will need to manually process this character"
                break
            }

        }
    }

    #Code for -SpecialKeyInput
    if ($SpecialKeyInput) {
        if ($hidCharacterMap.ContainsKey([string]$SpecialKeyInput)) {
            $hidCode = $hidCharacterMap[[string]$SpecialKeyInput]
            $tmp = New-Object VMware.Vim.UsbScanCodeSpecKeyEvent
            $hidCodeHexToInt = [Convert]::ToInt64($hidCode, "16")
            $hidCodeValue = ($hidCodeHexToInt -shl 16) -bor 0007

            $tmp.UsbHidCode = $hidCodeValue
            $hidCodesEvents += $tmp

            if ($DebugOn) {
                Write-Host "[SpecialKeyInput] Character: $character -> HIDCode: $hidCode -> HIDCodeValue: $hidCodeValue"
            }
        }
        else {
            Write-Host "[SpecialKeyInput] The following character `"$character`" has not been mapped, you will need to manually process this character"
            break
        }
    }

    # Add return carriage to the end of the string input (useful for logins or executing commands)
    if ($ReturnCarriage) {
        # Convert return carriage to HID code format
        $hidCodeHexToInt = [Convert]::ToInt64("0x28", "16")
        $hidCodeValue = ($hidCodeHexToInt -shl 16) + 7

        $tmp = New-Object VMware.Vim.UsbScanCodeSpecKeyEvent
        $tmp.UsbHidCode = $hidCodeValue
        $hidCodesEvents += $tmp
    }

    # Call API to send keystrokes to VM
    $spec = New-Object Vmware.Vim.UsbScanCodeSpec
    $spec.KeyEvents = $hidCodesEvents
    Write-Host "Sending keystrokes to $VMName ...`n"
    $results = $vm.PutUsbScanCodes($spec)
}
