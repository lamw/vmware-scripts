# Author: William Lam
# Website: https://williamlam.com
# Reference: https://williamlam.com/2024/07/useful-vsphere-automation-techniques-for-assisting-with-crowdstrike-remediation.html

$vmName = "CrowdStrike-VM"
$bitLockerKey = ""

$vm = Get-VM $vmName

Write-Host -ForegroundColor Cyan "Powering on ${vmName} ..."
$vm | Start-VM -Confirm:$false | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Pressing a key to boot from CD-ROM ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyDown" | Out-Null
Write-Host -ForegroundColor Yellow "Sleeping for 25 seconds to ensure we land on next window..."
Start-Sleep -Seconds 25

Write-Host -ForegroundColor Cyan "Entering Tab from `"Language to install`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "Tab" | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Entering Tab from `"Time and currency format`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "Tab" | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Entering Tab from `"Keyboard or input method`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "Tab" | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Entering the `"Next`" button ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyEnter" | Out-Null
Write-Host -ForegroundColor Yellow "Sleeping for 5 seconds to ensure we land on next window.."
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Cyan "Entering Tab from `"Install now`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "Tab" | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Entering `"repair your computer option`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyEnter" | Out-Null
Write-Host -ForegroundColor Yellow "Sleeping for 5 seconds to ensure we land on next window.."
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Cyan "Entering down arrow from `"Continue`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyDown" | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Entering down arrow from `"Use a device`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyDown" | Out-Null
Start-Sleep -Seconds 1

Write-Host -ForegroundColor Cyan "Entering `"Troubleshoot`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyEnter" | Out-Null
Write-Host -ForegroundColor Yellow "Sleeping for 5 seconds to ensure we land on next window.."
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Cyan "Entering `"Command Prompt`" ..."
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyEnter" | Out-Null
Write-Host -ForegroundColor Yellow "Sleeping for 5 seconds to ensure we land on next window.."
Start-Sleep -Seconds 5

if($bitLockerKey -ne "") {
    Write-Host -ForegroundColor Cyan "Entering Bitlocker key ..."
    Set-VMKeystrokes -VMName $vm -StringInput $bitLockerKey | Out-Null
    Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyEnter" | Out-Null
    Start-Sleep -Seconds 5
}

Write-Host -ForegroundColor Cyan "Entering CrowdStrike delete command ..."
Set-VMKeystrokes -VMName $vm -StringInput "del C:\Windows\System32\drivers\CrowdStrike\C-00000291*.sys" | Out-Null
Start-Sleep -Seconds 1
Set-VMKeystrokes -VMName $vm -SpecialKeyInput "KeyEnter" | Out-Null
