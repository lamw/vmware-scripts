$cloudinit_metadata_file = "metadata-ubuntu.json"
$vcenter = "fill-me-in"
$vcenter_username = "fill-me-in"
$vcenter_password = "fill-me-in"
$vm_id = "fill-me-in"
$vm_dns_server = "fill-me-in"
$vm_dns_domain = "fill-me-in"
$debug = $false

### DO NOT EDIT BEYOND HERE ###

$metadata = Get-Content -Raw ${cloudinit_metadata_file}
$escaped_metadata = (($metadata | ConvertFrom-Json)|ConvertTo-Json -Depth 12 -Compress)

$pair = "${vcenter_username}:${vcenter_password}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)

$results = Invoke-WebRequest -Uri "https://${vcenter}/api/session" -Method POST -Headers @{"Authorization"="Basic $base64"}
if($results.StatusCode -ne 201) {
    Write-Host -ForegroundColor Red "Failed to login to vCenter Serve, please verify your credentials are correct"
    break
}
$vmware_session_id = $results.content.replace('"','')

$userdata = @'
#cloud-config
runcmd:
- hostnamectl set-hostname cloud-init-configured.primp-industries.local
'@

$payload = [ordered]@{
    "spec" = [ordered]@{
        "configuration_spec" = [ordered]@{
            "cloud_config" = [ordered]@{
                "cloudinit" = [ordered]@{
                    "metadata" = $escaped_metadata;
                    "userdata" = $userdata;
                };
                "type" = "CLOUDINIT";
            };
        };
        "global_DNS_settings" = @{
			"dns_servers" = @(${vm_dns_server});
			"dns_suffix_list" = @(${vm_dns_domain});
		};
        "interfaces" = @(@{
            "adapter" = @{
                "ipv4" = [ordered]@{
                    "type" = "STATIC";
                };
            };
        });
    }
}

$body = $payload | ConvertTo-Json -depth 12

if($debug) {$body}

$results = Invoke-WebRequest -Uri "https://${vcenter}/api/vcenter/vm/${vm_id}/guest/customization" -Method PUT -Headers @{"vmware-api-session-id"=$vmware_session_id;"Content-Type"="application/json"} -Body $body
if($results.StatusCode -ne 204) {
    Write-Host -ForegroundColor Red "Failed apply GuestOS Customization Spec"
    break
} else {
    Write-Host -ForegroundColor Green "Successfully applied GuestOS Cloud-Init Customization Spec to ${vm_id}"
}
