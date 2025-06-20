Connect-VIServer -Server vc01.vcf.lab -User administrator@vsphere.local -Password VMware1!VMware1!

$edges = @("edge01a","edge01b")
$edgeUser = "root"
$edgePass = "VMware1!VMware1!"

### DO NOT EDIT BEYOND HEREx

$edgeScript = "sed -i `'/if `"AMD`" in vendor_info and `"AMD EPYC`" not in model_name:/s/^/        #/;/self.error_exit(`"Unsupported CPU: %s`" % model_name)/s/^/        #/`' /opt/vmware/nsx-edge/bin/config.py"

foreach ($edge in $edges) {
    Invoke-VMScript -VM (Get-VM $edge) -ScriptText $edgeScript  -GuestUser $edgeUser -GuestPassword $edgePass
}

Disconnect-VIServer * -Confirm:$false