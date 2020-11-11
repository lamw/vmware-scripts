Function Set-VMKeystrokes {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    ===========================================================================
     Modified by:   David Rodriguez
     Organization:  Sysadmintutorials
     Blog:          www.sysadmintutorials.com
     Twitter:       @systutorials
    ===========================================================================
    ===========================================================================
     Modified by:   Mark Elvers <mark.elvers@tunbury.org>
    ===========================================================================
    .DESCRIPTION
        This function sends a series of character keystrokse to a particular VM
    .PARAMETER VMName
        The name of a VM to send keystrokes to
    .PARAMETER StringInput
        The string of tokens to send to the VM
    .PARAMETER DebugOn
        Enable debugging which will output input charcaters and their mappings
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "root"

        Push "root" to VM $VM
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "root"

        Push "root" with return line to VM $VM
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "root" -DebugOn $true

        Push "root" to VM $VM with some debug
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "{gui}r"

	Send Windows key-R to bring up the Run dialog
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "cmd{enter}"

	Send text "cmd" followed by the return character
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "{ctrl}{alt}{delete}"

	Send key sequence Control-Alt-Del
    .EXAMPLE
        Set-VMKeystrokes -VMName $VM -StringInput "{alt}{f4}"

	Send Alt-F4 sequence (typically to close a window)

#>
    param(
        [Parameter(Mandatory = $true)][String]$VMName,
        [Parameter(Mandatory = $true)][String]$StringInput,
        [Parameter(Mandatory = $false)][Boolean]$DebugOn
    )


    # Map subset of USB HID keyboard scancodes
    # https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2
    # This string is encoded in triples "key hidCode shift"
    # it's done this way as you can't declare a case sensitive hash immediately
    $map = @"
    none 0 0
    err_ovf 1 0
    a 4 0
    b 5 0
    c 6 0
    d 7 0
    e 8 0
    f 9 0
    g A 0
    h B 0
    i C 0
    j D 0
    k E 0
    l F 0
    m 10 0
    n 11 0
    o 12 0
    p 13 0
    q 14 0
    r 15 0
    s 16 0
    t 17 0
    u 18 0
    v 19 0
    w 1A 0
    x 1B 0
    y 1C 0
    z 1D 0
    1 1E 0
    2 1F 0
    3 20 0
    4 21 0
    5 22 0
    6 23 0
    7 24 0
    8 25 0
    9 26 0
    0 27 0
    A 4 1
    B 5 1
    C 6 1
    D 7 1
    E 8 1
    F 9 1
    G A 1
    H B 1
    I C 1
    J D 1
    K E 1
    L F 1
    M 10 1
    N 11 1
    O 12 1
    P 13 1
    Q 14 1
    R 15 1
    S 16 1
    T 17 1
    U 18 1
    V 19 1
    W 1A 1
    X 1B 1
    Y 1C 1
    Z 1D 1
    ! 1E 1
    @ 1F 1
    # 20 1
    $ 21 1
    % 22 1
    ^ 23 1
    & 24 1
    * 25 1
    leftbrace 26 1
    rightbrace 27 1
    enter 28 0
    esc 29 0
    backspace 2A 0
    tab 2B 0
    space 2C 0
    - 2D 0
    = 2E 0
    [ 2F 0
    ] 30 0
    \ 31 0
    hash 32 0
    ; 33 0
    ' 34 0
    `` 35 0
    , 36 0
    . 37 0
    / 38 0
    minus 2D 1
    equal 2E 1
    leftcurlybrace 2F 1
    rightcurlybrace 30 1
    | 31 1
    tilde 32 1
    : 33 1
    " 34 1
    ~ 35 1
    < 36 1
    > 37 1
    ? 38 1
    capslock 39 0
    f1 3A 0
    f2 3B 0
    f3 3C 0
    f4 3D 0
    f5 3E 0
    f6 3F 0
    f7 40 0
    f8 41 0
    f9 42 0
    f10 43 0
    f11 44 0
    f12 45 0
    sysrq 46 0
    scrolllock 47 0
    pause 48 0
    insert 49 0
    home 4A 0
    pageup 4B 0
    delete 4C 0
    end 4D 0
    pagedown 4E 0
    right 4F 0
    left 50 0
    down 51 0
    up 52 0
    numlock 53 0
    kpslash 54 0
    kpasterisk 55 0
    kpminus 56 0
    kpplus 57 0
    kpenter 58 0
    kp1 59 0
    kp2 5A 0
    kp3 5B 0
    kp4 5C 0
    kp5 5D 0
    kp6 5E 0
    kp7 5F 0
    kp8 60 0
    kp9 61 0
    kp0 62 0
    kpdot 63 0
    102nd 64 0
    compose 65 0
    power 66 0
    kpequal 67 0
    f13 68 0
    f14 69 0
    f15 6A 0
    f16 6B 0
    f17 6C 0
    f18 6D 0
    f19 6E 0
    f20 6F 0
    f21 70 0
    f22 71 0
    f23 72 0
    f24 73 0
    open 74 0
    help 75 0
    props 76 0
    front 77 0
    stop 78 0
    again 79 0
    undo 7A 0
    cut 7B 0
    copy 7C 0
    paste 7D 0
    find 7E 0
    mute 7F 0
    volumeup 80 0
    volumedown 81 0
    kpcomma 85 0
    ro 87 0
    katakanahiragana 88 0
    yen 89 0
    henkan 8A 0
    muhenkan 8B 0
    kpjpcomma 8C 0
    hangeul 90 0
    hanja 91 0
    katakana 92 0
    hiragana 93 0
    zenkakuhankaku 94 0
    kpleftparen B6 0
    kprightparen B7 0
    leftctrl E0 0
    leftshift E1 0
    leftalt E2 0
    leftmeta E3 0
    rightctrl E4 0
    rightshift E5 0
    rightalt E6 0
    rightmeta E7 0
    media_playpause E8 0
    media_stopcd E9 0
    media_previoussong EA 0
    media_nextsong EB 0
    media_ejectcd EC 0
    media_volumeup ED 0
    media_volumedown EE 0
    media_mute EF 0
    media_www F0 0
    media_back F1 0
    media_forward F2 0
    media_stop F3 0
    media_find F4 0
    media_scrollup F5 0
    media_scrolldown F6 0
    media_edit F7 0
    media_sleep F8 0
    media_coffee F9 0
    media_refresh FA 0
    media_calc FB 0
"@ -split '\s+'
    $hidCharacterMap = New-Object system.collections.hashtable
    for ($i = 1; $i -lt $map.count; $i += 3) {
        $hidCode = [Convert]::ToInt64($map[$i + 1], 16)
        $hidCodeValue = ($hidCode -shl 16) -bor 0007
        $hidCharacterMap[[string]$map[$i]] = @{ hidCode = $hidCode; hidCodeValue = $hidCodeValue; shift = ($map[$i + 2] -eq 1) }
    }
    $hidCharacterMap[" "] = $hidCharacterMap["space"]

    $vm = Get-View -ViewType VirtualMachine -Filter @{"Name" = "^$($VMName)$" }

    # Verify we have a VM or fail
    if (!$vm) {
        Write-host "Unable to find VM $VMName"
        return
    }

    $hidCodesEvents = @()

    #Code for -StringInput
    if ($StringInput) {
        $tokens = @()
        $b = $false
        $StringInput -split '([{}])' |% {
            switch ($_) {
                '{' { $b = $true }
                '}' { $b = $false }
                Default { if ($b) { $tokens += $_.toLower() } else { $tokens += $_.ToCharArray() } }
            }
        }

        $modifier = New-Object Vmware.Vim.UsbScanCodeSpecModifierType

        foreach ($token in $tokens) {
            if ($hidCharacterMap.ContainsKey([string]$token)) {
                $tmp = New-Object VMware.Vim.UsbScanCodeSpecKeyEvent
                $tmp.UsbHidCode = $hidCharacterMap[[string]$token].hidCodeValue
                $modifier.LeftShift = $hidCharacterMap[[string]$token].shift
                $tmp.Modifiers = $modifier
                $hidCodesEvents += $tmp

                $modifier = New-Object Vmware.Vim.UsbScanCodeSpecModifierType

                if ($DebugOn) {
                    Write-Host "[Input] Character: $($token) -> HIDCode: $($hidCharacterMap[[string]$token].hidCode) -> HIDCodeValue: $($hidCharacterMap[[string]$token].hidCodeValue)"
                }
            } else {
                switch ($token) {
                    "shift" { $modifier.LeftShift = $true }
                    "alt" { $modifier.LeftAlt = $true }
                    "ctrl" { $modifier.LeftControl = $true }
                    "gui" { $modifier.LeftGui = $true }
                    Default {
                        Write-Host "[KeyInput] The following character `"$($token)`" has not been mapped, you will need to manually process this character"
                    }
                }
            }
        }
    }

    if ($hidCodesEvents.length -gt 0) {
        # Call API to send keystrokes to VM
        $spec = New-Object Vmware.Vim.UsbScanCodeSpec
        $spec.KeyEvents = $hidCodesEvents
        Write-Host "Sending keystrokes to $VMName ...`n"
        $results = $vm.PutUsbScanCodes($spec)
    }
}
