$ActivationKey = "<FILL ME>"
$HCXServer = "mgmt-hcxm-02.cpbu.corp"
$VAMIUsername = "admin"
$VAMIPassword = "VMware1!"
$VIServer = "mgmt-vcsa-01.cpbu.corp"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "VMware1!"
$NSXServer = "mgmt-nsxm-01.cpbu.corp"
$NSXUsername = "admin"
$NSXPassword = "VMware1!"

Connect-HcxVAMI -Server $HCXServer -Username $VAMIUsername -Password $VAMIPassword

Set-HcxLicense -LicenseKey $ActivationKey

Set-HcxVCConfig -VIServer $VIServer -VIUsername $VIUsername -VIPassword $VIPassword -PSCServer $VIServer

Set-HcxNSXConfig -NSXServer $NSXServer -NSXUsername $NSXUsername -NSXPassword $NSXPassword

Set-HcxLocation -City "Santa Barbara" -Country "United States of America"

Set-HcxRoleMapping -SystemAdminGroup @("vsphere.local\Administrators","cpbu.corp\Administrators") -EnterpriseAdminGroup @("vsphere.local\Administrators","cpbu.corp\Administrators")
