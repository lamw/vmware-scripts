# Installs 64-bit Cloudbase-init on Microsoft Windows system



### DO NOT EDIT BEYOND HERE ###

$githubLatestReleases = 'https://api.github.com/repos/cloudbase/cloudbase-init/releases/latest' 

$releases = Invoke-WebRequest $githubLatestReleases | ConvertFrom-Json 

$latestx64release = $releases.assets | ? {$_.name -like '*x64.msi'}

$cloudbaseInitInstallerUri = $latestx64release.browser_download_url

$cloudbaseInitInstaller = $latestx64release.name

$cloudbaseInitInstallPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\"
$cloudbaseInitConfigFile = "cloudbase-init.conf"
$cloudbaseInitUnattendConfigFile = "cloudbase-init-unattend.conf"

Write-Host "Downloading Cloudbase-Init Installer ..."
Invoke-WebRequest -Uri $cloudbaseInitInstallerUri -OutFile C:\$cloudbaseInitInstaller

Write-Host "Unlocking Cloudbase-Init Installer ..."
Unblock-File -Path C:\$cloudbaseInitInstaller

Write-Host "Installing Cloudbase-Init ..."
Start-Process msiexec.exe -ArgumentList "/i C:\$cloudbaseInitInstaller /qn /norestart RUN_SERVICE_AS_LOCAL_SYSTEM=1" -Wait

Write-Host "Removing the default Cloudbase-Init configuration files ..."
Remove-Item -Path ($cloudbaseInitInstallPath + $cloudbaseInitConfigFile) -Confirm:$false
Remove-Item -Path ($cloudbaseInitInstallPath + $cloudbaseInitUnattendConfigFile) -Confirm:$false

$confContent = @"
[DEFAULT]
username=Admin
groups=Administrators
inject_user_password=true
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=true
metadata_services=cloudbaseinit.metadata.services.vmwareguestinfoservice.VMwareGuestInfoService
plugins=cloudbaseinit.plugins.common.ephemeraldisk.EphemeralDiskPlugin,cloudbaseinit.plugins.common.mtu.MTUPlugin,cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,cloudbaseinit.plugins.common.sshpublickeys.SetUserSSHPublicKeysPlugin,cloudbaseinit.plugins.common.userdata.UserDataPlugin,cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin,cloudbaseinit.plugins.windows.createuser.CreateUserPlugin
"@

Write-Host "Creating new Cloudbase-Init ${cloudbaseInitConfigFile} File ..."
New-Item -Path $cloudbaseInitInstallPath -Name $cloudbaseInitConfigFile -ItemType File -Force -Value $confContent | Out-Null

$unattendContent = @"
[DEFAULT]
username=Admin
groups=Administrators
inject_user_password=true
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init-unattend.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
check_latest_version=false
metadata_services=cloudbaseinit.metadata.services.vmwareguestinfoservice.VMwareGuestInfoService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin
allow_reboot=false
stop_service_on_exit=false
"@
Write-Host "Creating new Cloudbase-Init ${cloudbaseInitUnattendConfigFile} File ..."
New-Item -Path $cloudbaseInitInstallPath -Name $cloudbaseInitUnattendConfigFile -ItemType File -Force -Value $unattendContent | Out-Null

Write-Host "Enabling automatic startup for Cloudbase-init ..."
Get-Service -Name cloudbase-init | Set-Service -StartupType Automatic

Write-Host "Cleaning up Cloudbase-Init installer ..."
Remove-Item C:\$cloudbaseInitInstaller -Confirm:$false
