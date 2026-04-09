$VCF_OPERATIONS_FQDN="vcf02.vcf.lab"
$VCF_OPERATIONS_USERNAME="admin"
$VCF_OPERATIONS_PASSWORD='VMware1!VMware1!'
$VCF_SSO_DEPLOYMENT_MODEL="EMBEDDED" #EMBEDDED or EXTERNAL
$VCF_AUTOMATION_DEPLOYED=$true #$true or $false

$OIDC_LABEL="Keycloak"
$OIDC_OPENID_DISCOVERY_URL="https://auth.vcf.lab:8443/realms/it/.well-known/openid-configuration"
$OIDC_TLS_FULLCHAIN_PEM="/Users/lamw/Desktop/auth.vcf.lab-fullchain.pem"
$OIDC_CLIENT_ID="vcf"
$OIDC_CLIENT_SECRET=""
$OIDC_DOMAIN="vcf.lab"
$OIDC_JIT_PRE_PROVISION_GROUP="vcf-admins"
$OIDC_GROUP_ATTRIBUTE="groups"

#### DO NOT MODIFY BEYOND HERE ####

$Troubleshoot = $false

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)][String]$message,
    [Parameter(Mandatory=$false)][String]$color="green"
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
    $logMessage = "[$timeStamp] $message"
}

$body = @{
    "username" = $VCF_OPERATIONS_USERNAME
    "password" = $VCF_OPERATIONS_PASSWORD
    "authSource" = "local"
} | ConvertTo-Json

My-Logger  "Acquiring VCF Operations access token ..."
$requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_FQDN}/suite-api/api/auth/token/acquire" -Method POST -Headers @{"Content-Type" = "application/json";"Accept" = "application/json"} -Body $body -SkipCertificateCheck

$VCF_OPERATIONS_AUTH_TOKEN=$(($requests.Content | ConvertFrom-Json).token)

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}"
    "X-Ops-API-use-unsupported" = "true"
}

#######################

My-Logger  "Acknowledging VCF SSO Prerequisites..."

$globalIdPSettingsUri = "https://${VCF_OPERATIONS_FQDN}/suite-api/internal/vidb/globalidpsettings"

$body = @{
    "key" = "TERMS_AND_CONDITIONS"
    "value" = "ACCEPTED"
} | ConvertTo-Json

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($globalIdPSettingsUri)`n$($body)`n"
}

$requests = Invoke-WebRequest -Uri $globalIdPSettingsUri -Method PUT -Headers $headers -Body $body -SkipCertificateCheck

My-Logger  "Retrieving VCF Instance & vIDB IDs ..."

$vidbAdapterUri = "https://$VCF_OPERATIONS_FQDN/suite-api/api/resources?adapterKindKey=VMWARE_INFRA_MANAGEMENT&resourceKind=Vidb%20Monitoring"

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($vidbAdapterUri)`n"
}

$resourceNameFilter = @{
    "EXTERNAL" = "Appliance"
    "EMBEDDED" = "Embedded"
}

$requests = Invoke-WebRequest -Uri $vidbAdapterUri -Method GET -Headers $headers -SkipCertificateCheck
$vidbInstance = ($requests.Content | ConvertFrom-Json).resourceList | Where-Object { $_.resourceKey.name -match $resourceNameFilter[$VCF_SSO_DEPLOYMENT_MODEL] } | ForEach-Object {($_.resourceKey.resourceIdentifiers)}
$vcfId = ($vidbInstance  | where {$_.identifierType.name -eq "VIDB_MONITORING_VCF_IDENTIFIER"}).value

$vidbsUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/vidbs?vcfId=$vcfId"

$requests = Invoke-WebRequest -Uri $vidbsUri -Method GET -Headers $headers -SkipCertificateCheck
$vidbResourceId = (($requests.Content | ConvertFrom-Json) | where {$_.deploymentType -eq $VCF_SSO_DEPLOYMENT_MODEL -and $_.vidbStatus.status -eq "ELIGIBLE"}).id

#######################

My-Logger  "Configuring VCF SSO Deployment Model ${VCF_SSO_DEPLOYMENT_MODEL} ..."

$ssoConfigStatusUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/ssoconfigstatus?vcfId=$vcfId"

$body = @{
    "status" = "DEPLOYMENT_MODE_SELECTED"
    "deploymentType" = $VCF_SSO_DEPLOYMENT_MODEL
} | ConvertTo-Json

$requests = Invoke-WebRequest -Uri $ssoConfigStatusUri -Method POST -Headers $headers -Body $body -SkipCertificateCheck

#######################

My-Logger  "Configuring VCF SSO IdP for OIDC ..."

$idpUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/identityproviders"

$cert = (Get-Content -Raw $OIDC_TLS_FULLCHAIN_PEM) -replace "`r?`n", "\n"

$body = [ordered]@{
  "name" = $OIDC_LABEL
  "deploymentType" = $VCF_SSO_DEPLOYMENT_MODEL
  "vidbResourceId" = $vidbResourceId
  "vcfInstanceId" = $vcfId
  "idpType" = "PING"
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
            "attrName" = "given_name"
          },
          @{
            "directoryName" = "lastName"
            "attrName" = "family_name"
          },
          @{
            "directoryName" = "email"
            "attrName" = "email"
          },
          @{
            "directoryName" = "userName"
            "attrName" = "preferred_username"
          },
          @{
            "directoryName" = "groups"
            "attrName" = $OIDC_GROUP_ATTRIBUTE
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
    "certChain" = @($cert)
  }
} | ConvertTo-Json -Depth 10

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($idpUri)`n$($body)`n"
}

$requests = Invoke-WebRequest -Uri $idpUri -Method POST -Headers $headers -Body $body -SkipCertificateCheck

#######################

My-Logger  "Configuring VCF SSO for vCenter & NSX ..."

$idpUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/identityproviders"

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($idpUri)`n"
}

$requests = Invoke-WebRequest -Uri $idpUri -Method GET -Headers $headers -Body $body -SkipCertificateCheck
$vidbHostname = (($requests.Content | ConvertFrom-Json).identityProviderInfoList | where {$_.deploymentType -eq $VCF_SSO_DEPLOYMENT_MODEL -and $_.vidbResourceId -eq $vidbResourceId -and $_.vcfInstanceId -eq $vcfId}).vidbHostname

$authSourceUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/authsource?vcfId=$vcfId"

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($authSourceUri)`n"
}

$requests = Invoke-WebRequest -Uri $authSourceUri -Method GET -Headers $headers -SkipCertificateCheck

$vcfComponents = @()
foreach ($component in ($requests.Content | ConvertFrom-Json).authSourceComponents) {
  if($component.status -eq "NOT_CONFIGURED") {
    $tmp = @{
      "componentType" = $component.componentType
      "componentHostname" = $component.componentHostname
      "vcfComponentId" = $component.vcfComponentId
    }
    $vcfComponents += $tmp
  }
}

$authSourceUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/authsource"

$body = [ordered] @{
  "vcfInstanceId" = $vcfId
  "vidbResourceId" = $vidbResourceId
  "vidbHostname" = $vidbHostname
  "vcfComponents" = $vcfComponents
} | ConvertTo-Json -Depth 3

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($authSourceUri)`n$($body)`n"
}

$requests = Invoke-WebRequest -Uri $authSourceUri -Method POST -Headers $headers -Body $body -SkipCertificateCheck

#######################

My-Logger  "Configuring VCF SSO for for VCF Operations ..."

$opsComponentUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/authsource/components?componentType=VCF_OPS"

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($opsComponentUri)`n"
}

$requests = Invoke-WebRequest -Uri $opsComponentUri -Method GET -Headers $headers -ContentType "application/json" -SkipCertificateCheck
if($requests.StatusCode -eq 200) {
  if((($requests.Content | ConvertFrom-Json).authSourceComponents).count -eq 0) {
    $authsourceUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/authsource"

    $body = [ordered]@{
      "vcfInstanceId" = $vcfId
      "vidbResourceId" = $vidbResourceId
      "vidbHostname" = $vidbHostname
      "vcfComponents" = @(
        @{"componentType" = "VCF_OPS"}
      )
    } | ConvertTo-Json -Depth 3

    if($Troubleshoot) {
      Write-Host -ForegroundColor cyan "`n[DEBUG] - $($authsourceUri)`n$($body)`n"
    }

    $requests = Invoke-WebRequest -Uri $authsourceUri -Method POST -Headers $headers -Body $body -SkipCertificateCheck
  }
}

#######################

if($VCF_AUTOMATION_DEPLOYED) {
  My-Logger  "Configuring VCF SSO VCF Automation ..."

  $autoComponentUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/authsource/components?componentType=VCF_AUTOMATION"

  if($Troubleshoot) {
    Write-Host -ForegroundColor cyan "`n[DEBUG] - $($autoComponentUri)`n"
  }

  $requests = Invoke-WebRequest -Uri $autoComponentUri -Method GET -Headers $headers -ContentType "application/json" -SkipCertificateCheck
  if($requests.StatusCode -eq 200) {
    if((($requests.Content | ConvertFrom-Json).authSourceComponents).count -eq 0) {
      $authsourceUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/authsource"

      $body = [ordered]@{
        "vcfInstanceId" = $vcfId
        "vidbResourceId" = $vidbResourceId
        "vidbHostname" = $vidbHostname
        "vcfComponents" = @(
          @{"componentType" = "VCF_AUTOMATION"}
        )
      } | ConvertTo-Json -Depth 3

      if($Troubleshoot) {
        Write-Host -ForegroundColor cyan "`n[DEBUG] - $($authsourceUri)`n$($body)`n"
      }

      $requests = Invoke-WebRequest -Uri $authsourceUri -Method POST -Headers $headers -Body $body -SkipCertificateCheck
    }
  }
}

#######################

My-Logger  "Completing VCF SSO UI workflow ..."

$ssoConfigStatusUri = "https://$VCF_OPERATIONS_FQDN/suite-api/internal/vidb/ssoconfigstatus?vcfId=${vcfId}"

$body = @{
  "status" = "FINISHED"
  "deploymentType" = $VCF_SSO_DEPLOYMENT_MODEL
} | ConvertTo-Json

if($Troubleshoot) {
  Write-Host -ForegroundColor cyan "`n[DEBUG] - $($ssoConfigStatusUri)`n$($body)`n"
}

$requests = Invoke-WebRequest -Uri $ssoConfigStatusUri -Method PUT -Headers $headers -Body $body -SkipCertificateCheck

