$VCF_OPERATIONS_HOSTNAME="vcf01.vcf.lab"
$VCF_OPERATIONS_USERNAME="admin"
$VCF_OPERATIONS_PASSWORD='VMware1!VMware1!'
$VCF_SSO_DEPLOYMENT_MODEL="EXTERNAL" #EMBEDDED = vCenter Server or EXTERNAL = VCF Management Services (VCFMS)

$OIDC_LABEL="Keycloak"
$OIDC_OPENID_DISCOVERY_URL="https://auth.vcf.lab:8443/realms/it/.well-known/openid-configuration"
$OIDC_TLS_FULLCHAIN_PEM="/Users/lamw/Desktop/auth.vcf.lab-fullchain.pem"
$OIDC_CLIENT_ID="vcf"
$OIDC_CLIENT_SECRET="FILL_ME_IN"
$OIDC_DOMAIN="vcf.lab"
$OIDC_JIT_PRE_PROVISION_GROUP="vcf-admins"
$OIDC_GROUP_ATTRIBUTE="groups"

### DO NOT EDIT BEYOND HERE ####

$ackPreq = $true
$configModel = $true
$configIdp = $true
$configVCandNSX = $true
$configRoleAssignment = $true
$configVCFAandVCFO = $true
$finishSsoWorkflow = $true
$resetSso = $false

Function Invoke-VcfWebRequest {
  Param (
    [Parameter(Mandatory=$true)][String]$Uri,
    [Parameter(Mandatory=$true)][String]$Method,
    [Parameter(Mandatory=$true)]$Headers,
    [Parameter(Mandatory=$false)]$Body
  )

  try {
    if($PSBoundParameters.ContainsKey('Body')) {
      return Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -Body $Body -SkipCertificateCheck
    }

    return Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -SkipCertificateCheck
  } catch {
    Write-Host -ForegroundColor Red "Invoke-WebRequest failed"
    Write-Host -ForegroundColor Red "Uri: $Uri"
    if($PSBoundParameters.ContainsKey('Body')) {
      Write-Host -ForegroundColor Red "Body: $Body"
    }
    Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
    throw
  }
}

$body = @{
    "username" = $VCF_OPERATIONS_USERNAME
    "password" = $VCF_OPERATIONS_PASSWORD
    "authSource" = "local"
} | ConvertTo-Json

Write-Host -ForegroundColor Cyan "Acquiring VCF Operations access token ..."
$requests = Invoke-VcfWebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/auth/token/acquire" -Method POST -Headers @{"Content-Type" = "application/json";"Accept" = "application/json"} -Body $body

$VCF_OPERATIONS_AUTH_TOKEN=$(($requests.Content | ConvertFrom-Json).token)

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}"
    "X-Ops-API-use-unsupported" = "true"
}

if($ackPreq) {
  Write-Host -ForegroundColor Cyan "Acknowledging VCF SSO Prerequisites..."

  $body = @{
      "key" = "TERMS_AND_CONDITIONS"
      "value" = "ACCEPTED"
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/vidb/globalidpsettings" -Method PUT -Headers $headers -Body $body
}

if($configModel) {
  Write-Host -ForegroundColor Cyan "Configuring VCF SSO Deployment Model ${VCF_SSO_DEPLOYMENT_MODEL} ..."

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/api/resources?adapterKindKey=VMWARE_INFRA_MANAGEMENT&resourceKind=Vidb%20Monitoring" -Method GET -Headers $headers

  $resourceNameFilter = @{
      "EXTERNAL" = "Appliance"
      "EMBEDDED" = "Embedded"
  }

  $vidbInstance = ($requests.Content | ConvertFrom-Json).resourceList | Where-Object { $_.resourceKey.name -match $resourceNameFilter[$VCF_SSO_DEPLOYMENT_MODEL] } | ForEach-Object {($_.resourceKey.resourceIdentifiers)}
  $vidbResourceId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_IDENTIFIER"}).value
  $vcfId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_VCF_IDENTIFIER"}).value

  $body = @{
      "deploymentType" = $VCF_SSO_DEPLOYMENT_MODEL
      "vcfInstanceId" = $vcfId
      "vidbResourceId" = $vidbResourceId
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains" -Method POST -Headers $headers -Body $body

  $body = @{
      "status" = "IDP_SELECTED"
      "idpType" = "Generic OIDC"
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssoconfigstatus?vcfId=${vcfId}" -Method POST -Headers $headers -Body $body
}

if($configIdp) {
  Write-Host -ForegroundColor Cyan "Configuring VCF SSO IdP for Generic OIDC ..."

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/api/resources?adapterKindKey=VMWARE_INFRA_MANAGEMENT&resourceKind=Vidb%20Monitoring" -Method GET -Headers $headers

  $resourceNameFilter = @{
      "EXTERNAL" = "Appliance"
      "EMBEDDED" = "Embedded"
  }

  $vidbInstance = ($requests.Content | ConvertFrom-Json).resourceList | Where-Object { $_.resourceKey.name -match $resourceNameFilter[$VCF_SSO_DEPLOYMENT_MODEL] } | ForEach-Object {($_.resourceKey.resourceIdentifiers)}
  $vidbResourceId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_IDENTIFIER"}).value
  $vcfId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_VCF_IDENTIFIER"}).value

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains" -Method GET -Headers $headers -Body $body

  $ssoDomainId = (($requests.Content | ConvertFrom-Json).ssoDomainList | where {$_.vidbResourceId -eq $vidbResourceId -and $_.vcfInstanceId -eq $vcfId}).id

  $cert = (Get-Content -Raw $OIDC_TLS_FULLCHAIN_PEM) -replace "`r?`n", "\n"

  $body = [ordered]@{
    "name" = $OIDC_LABEL
    "ssoDomainId" = $ssoDomainId
    "idpType" = "OTHER"
    "idpConfigTag" = "OIDC"
    "provisionType" = "JIT"
    "idpConfig" = [ordered]@{
      "oidcConfiguration" = @{
        "discoveryEndpoint" = $OIDC_OPENID_DISCOVERY_URL
        "clientId" = $OIDC_CLIENT_ID
        "clientSecret" = $OIDC_CLIENT_SECRET
        "openIdUserIdentifierAttribute" = "sub"
        "internalUserIdentifierAttribute" = "ExternalID"
      }
    }
    "directories" = @(
      @{
        "domains" = @($OIDC_DOMAIN)
        "name" = "Directory OIDC JIT"
      }
    )
    "provisioningConfig" = @{
      "jitConfiguration" = @{
        "oidcJitConfiguration" = @{
          "userAttributeMappings" = @(
            @{
              "directoryName" = "firstName"
              "attributeName" = "given_name"
            },
            @{
              "directoryName" = "lastName"
              "attributeName" = "family_name"
            },
            @{
              "directoryName" = "email"
              "attributeName" = "email"
            },
            @{
              "directoryName" = "userName"
              "attributeName" = "preferred_username"
            },
            @{
              "directoryName" = "groups"
              "attributeName" = $OIDC_GROUP_ATTRIBUTE
            }
          )
        }
        "jitProvisioningGroups" = @(
          @{
            "domain" = $OIDC_DOMAIN
            "groupNames" = @($OIDC_JIT_PRE_PROVISION_GROUP)
          }
        )
      }
    }
    "trustedCertChain" = @{
      "certificateChain" = @($cert)
    }
  } | ConvertTo-Json -Depth 10

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/identityproviders" -Method POST -Headers $headers -Body $body
}

if($configVCandNSX) {
  Write-Host -ForegroundColor Cyan "Configuring VCF SSO for vCenter & NSX ..."

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/api/resources?adapterKindKey=VMWARE_INFRA_MANAGEMENT&resourceKind=Vidb%20Monitoring" -Method GET -Headers $headers

  $resourceNameFilter = @{
      "EXTERNAL" = "Appliance"
      "EMBEDDED" = "Embedded"
  }

  $vidbInstance = ($requests.Content | ConvertFrom-Json).resourceList | Where-Object { $_.resourceKey.name -match $resourceNameFilter[$VCF_SSO_DEPLOYMENT_MODEL] } | ForEach-Object {($_.resourceKey.resourceIdentifiers)}
  $vidbResourceId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_IDENTIFIER"}).value
  $vcfId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_VCF_IDENTIFIER"}).value

  $ssoDomainId = $null
  $timeout = 60
  $elapsed = 0
  $interval = 5
  do {
    $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains" -Method GET -Headers $headers -Body $body
    $ssoDomainId = (($requests.Content | ConvertFrom-Json).ssoDomainList | where {$_.vidbResourceId -eq $vidbResourceId -and $_.vcfInstanceId -eq $vcfId}).id
    if($ssoDomainId) { break }
    Write-Host -ForegroundColor Yellow "Waiting for ssoDomainId ... (${elapsed}s elapsed)"
    Start-Sleep -Seconds $interval
    $elapsed += $interval
  } while ($elapsed -lt $timeout)
  if(-not $ssoDomainId) {
    Write-Host -ForegroundColor Red "Timed out waiting for ssoDomainId after ${timeout}s"
    throw "ssoDomainId not available"
  }

  # Retrieving VCF Core Components
  $body = @{
      "vcfInstances" = @{
          "vcfInstanceIds" = @($vcfId)
          "excludeUnconfiguredComponents" = $false
      }
      "managementComponents" = @()
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/authsources/query" -Method POST -Headers $headers -Body $body

  $vcComponent = (($requests.Content | ConvertFrom-Json).authSourceComponents | where {$_.componentType -eq "VCENTER"})
  $nsxComponent = (($requests.Content | ConvertFrom-Json).authSourceComponents | where {$_.componentType -eq "NSX_MANAGER"})

  $body = [ordered] @{
      "ssoDomainId" = $ssoDomainId
      "action" = "CONFIGURE_COMPONENTS"
      "configurationDetails" = @{
          "vcfComponents" = @(
              @{
                  "vcfComponentId" = $vcComponent.vcfComponentId
                  "vcfInstanceId" = $vcComponent.vcfInstanceId
                  "componentHostname" = $vcComponent.componentHostname
                  "componentType" = "VCENTER"
              },
              @{
                  "vcfComponentId" = $nsxComponent.vcfComponentId
                  "vcfInstanceId" = $nsxComponent.vcfInstanceId
                  "componentHostname" = $nsxComponent.componentHostname
                  "componentType" = "NSX_MANAGER"
              }
          )
      }
  } | ConvertTo-Json -Depth 3

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/authsources/manage" -Method POST -Headers $headers -Body $body
}

if($configRoleAssignment) {
  Write-Host -ForegroundColor Cyan "Configuring VCF Administrator Role to IdP Group $OIDC_JIT_PRE_PROVISION_GROUP ..."

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains/$ssoDomainId/groups/query?page=0&pageSize=10" -Method POST -Headers $headers -Body $body

  $principal = (($requests.Content | ConvertFrom-Json).vidbGroups | where {$_.groupName -eq ${OIDC_JIT_PRE_PROVISION_GROUP}}).groupId

  $body = @{
      "principalIds" = @($principal)
      "principalType" = "GROUP"
      "methodType" = "CREATE_ASSIGNMENT"
      "roleDetails" = @(
          @{
              "roleName" = "vcf_administrator"
              "expiresAt" = ""
          }
      )
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains/$ssoDomainId/assignments/bulk" -Method POST -Headers $headers -Body $body
}

if($configVCFAandVCFO) {
  Write-Host -ForegroundColor Cyan "Configuring VCF Operations & VCF Automation ..."

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains" -Method GET -Headers $headers -Body $body
  $ssoDomainId = (($requests.Content | ConvertFrom-Json).ssoDomainList | where {$_.vidbResourceId -eq $vidbResourceId -and $_.vcfInstanceId -eq $vcfId}).id

  # Retrieving VCF Management Components
  $body = @{
      "vcfInstances" = @{
          "vcfInstanceIds" = @()
          "excludeUnconfiguredComponents" = $false
      }
      "managementComponents" = @("VCFA","VCF_OPS")
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/authsources/query" -Method POST -Headers $headers -Body $body

  $vcfaComponent = (($requests.Content | ConvertFrom-Json).authSourceComponents | where {$_.componentType -eq "VCFA"})
  $vcfoComponent = (($requests.Content | ConvertFrom-Json).authSourceComponents | where {$_.componentType -eq "VCF_OPS"})

  $managementComponents = @()

  if ($vcfaComponent.Count -gt 0) {
      $managementComponents += "VCFA"
  }

  if ($vcfoComponent.Count -gt 0) {
      $managementComponents += "VCF_OPS"
  }

  $body = [ordered] @{
      "ssoDomainId" = $ssoDomainId
      "action" = "CONFIGURE_COMPONENTS"
      "configurationDetails" = @{
          "managementComponents" = $managementComponents
      }
  } | ConvertTo-Json -Depth 3

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/authsources/manage" -Method POST -Headers $headers -Body $body
}

if($finishSsoWorkflow) {
  Write-Host -ForegroundColor Cyan "Finishing VCF SSO Workflow ..."

  $body = @{
      "status" = "FINISHED"
      "deploymentType" = "EXTERNAL"
      "idpType" = "Generic OIDC"
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssoconfigstatus?vcfId=${vcfId}" -Method PUT -Headers $headers -Body $body
}

if($resetSso) {
  Write-Host -ForegroundColor Yellow "Resetting VCF SSO Configuration ..."

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/api/resources?adapterKindKey=VMWARE_INFRA_MANAGEMENT&resourceKind=Vidb%20Monitoring" -Method GET -Headers $headers

  $resourceNameFilter = @{
      "EXTERNAL" = "Appliance"
      "EMBEDDED" = "Embedded"
  }

  $vidbInstance = ($requests.Content | ConvertFrom-Json).resourceList | Where-Object { $_.resourceKey.name -match $resourceNameFilter[$VCF_SSO_DEPLOYMENT_MODEL] } | ForEach-Object {($_.resourceKey.resourceIdentifiers)}
  $vcfId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_VCF_IDENTIFIER"}).value

  $body = @{
      "key" = "TERMS_AND_CONDITIONS"
      "value" = ""
  } | ConvertTo-Json

  $requests = Invoke-VcfWebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/vidb/globalidpsettings" -Method PUT -Headers $headers -Body $body

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains" -Method GET -Headers $headers -Body $body
  $ssoDomainId = (($requests.Content | ConvertFrom-Json).ssoDomainList | where {$_.vidbResourceId -eq $vidbResourceId -and $_.vcfInstanceId -eq $vcfId}).id

  $requests = Invoke-VcfWebRequest -Uri "https://$VCF_OPERATIONS_HOSTNAME/suite-api/internal/vidb/ssodomains/$ssoDomainId" -Method DELETE -Headers $headers -Body $body
}
