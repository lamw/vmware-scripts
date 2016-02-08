# Author: William Lam
# Site: www.virtuallyghetto.com
# Description: Script to automate the installation of vRA 7 IaaS Mgmt Agent
# Reference: http://www.virtuallyghetto.com/2016/02/automating-vrealize-automation-7-simple-minimal-part-2-vra-iaas-agent-deployment.html

# Hostname or IP of vRA Appliance
$VRA_APPLIANCE_HOSTNAME = "vra-appliance.primp-industries.com"
# Username of vRA Appliance
$VRA_APPLIANCE_USERNAME = "root"
# Password of vRA Appliance
$VRA_APPLIANCE_PASSWORD = "VMware1!"
# Path to store vRA Agent on IaaS Mgmt Windows system
$VRA_APPLIANCE_AGENT_DOWNLOAD_PATH = "C:\Windows\Temp\vCAC-IaaSManagementAgent-Setup.msi"
# Path to store vRA Agent installer logs on IaaS Mgmt Windowssystem
$VRA_APPLIANCE_AGENT_INSTALL_LOG = "C:\Windows\Temp\ManagementAgent-Setup.log"

# Credentials to the vRA IaaS Windows System
$VRA_IAAS_SERVICE_USERNAME = "vra-iaas\\Administrator"
$VRA_IAAS_SERVICE_PASSWORD = "!MySuperDuperPassword!"

### DO NOT EDIT BEYOND HERE ###

# URL to vRA Agent on vRA Appliance
$VRA_APPLIANCE_AGENT_URL = "https://" + $VRA_APPLIANCE_HOSTNAME + ":5480/installer/download/vCAC-IaaSManagementAgent-Setup.msi"

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$webclient = New-Object System.Net.WebClient
$webclient.Credentials = New-Object System.Net.NetworkCredential($VRA_APPLIANCE_USERNAME,$VRA_APPLIANCE_PASSWORD)

Write-Host "Downloading " $VRA_APPLIANCE_AGENT_URL "to" $VRA_APPLIANCE_AGENT_DOWNLOAD_PATH "..."
$webclient.DownloadFile($VRA_APPLIANCE_AGENT_URL,$VRA_APPLIANCE_AGENT_DOWNLOAD_PATH)

# Extracting SSL Thumbprint frmo vRA Appliance
# Thanks to Brian Graf for this snippet!
# I originally used this longer snippet from Alan Renouf (https://communities.vmware.com/thread/501913?start=0&tstart=0)
# Brian 1, Alan 0 ;)
# It's still easier in Linux :D
$VRA_APPLIANCE_ENDPOINT = "https://" + $VRA_APPLIANCE_HOSTNAME + ":5480"

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;

    public class IDontCarePolicy : ICertificatePolicy {
        public IDontCarePolicy() {}
        public bool CheckValidationResult(
            ServicePoint sPoint, X509Certificate cert,
            WebRequest wRequest, int certProb) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy
$VRA_APPLIANE_VAMI = [System.Net.Webrequest]::Create("$VRA_APPLIANCE_ENDPOINT")
$VRA_APPLIANCE_SSL_THUMBPRINT = $VRA_APPLIANE_VAMI.ServicePoint.Certificate.GetCertHashString()

# Extracting vRA IaaS Windows VM hostname
$VRA_IAAS_HOSTNAME=hostname

# Arguments to silent installer for vRA IaaS Agent
$VRA_INSTALLER_ARGS = "/i $VRA_APPLIANCE_AGENT_DOWNLOAD_PATH /qn /norestart /Lvoicewarmup! `"$VRA_APPLIANCE_AGENT_INSTALL_LOG`" ADDLOCAL=`"ALL`" INSTALLLOCATION=`"C:\\Program Files (x86)\\VMware\\vCAC\\Management Agent`" MANAGEMENT_ENDPOINT_ADDRESS=`"$VRA_APPLIANCE_ENDPOINT`" MANAGEMENT_ENDPOINT_THUMBPRINT=`"$VRA_APPLIANCE_SSL_THUMBPRINT`" SERVICE_USER_NAME=`"$VRA_IAAS_SERVICE_USERNAME`" SERVICE_USER_PASSWORD=`"$VRA_IAAS_SERVICE_PASSWORD`" VA_USER_NAME=`"$VRA_APPLIANCE_USERNAME`" VA_USER_PASSWORD=`"$VRA_APPLIANCE_PASSWORD`" CURRENT_MACHINE_FQDN=`"$VRA_IAAS_HOSTNAME`""

if (Test-Path $VRA_APPLIANCE_AGENT_DOWNLOAD_PATH) {
    Write-Host "Installing vRA 7 Agent ..."
    # Exit code of 0 = success
    $ec = (Start-Process -FilePath msiexec.exe -ArgumentList $VRA_INSTALLER_ARGS -Wait -Passthru).ExitCode
    if ($ec -eq 0) {
        Write-Host "Installation successful!`n"
    } else {
        Write-Host "Installation failed, please have a look at the log!`n"
    }
} else {
    Write-host "Download must have failed as I can not find the file!`n"
}
