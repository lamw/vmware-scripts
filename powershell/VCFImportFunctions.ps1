# Author: William Lam
# Description: Set of functions to initiate and retrieve VCF Brownfield Import Validation

Function Get-SSLThumbprint256 {
    param(
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [Alias('FullName')]
        [String]$URL
    )

    # Convert the FQDN/URL to a useable hostname (strips scheme/path)
    try {
        $Uri = [System.Uri]$URL
    }
    catch {
        Write-Error "Invalid URL provided: $($URL)"
        return
    }

    $Hostname = $Uri.Host
    # Use 443 if no port is explicitly specified
    $Port = if ($Uri.Port -eq -1) { 443 } else { $Uri.Port } 

    # 1. Define the Validation Callback
    # This delegate tells the SslStream to always accept the certificate,
    # bypassing name mismatch and chain errors.
    $ValidationCallback = {
        param(
            [System.Object]$sender,
            [System.Security.Cryptography.X509Certificates.X509Certificate]$certificate,
            [System.Security.Cryptography.X509Certificates.X509Chain]$chain,
            [System.Net.Security.SslPolicyErrors]$sslPolicyErrors
        )
        # Always return $true to accept any certificate
        $true
    }

    # 2. Establish a TCP connection
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $TcpClient.Connect($Hostname, $Port)
    }
    catch {
        Write-Error "Could not connect to $($Hostname):$($Port). Error: $($_.Exception.Message)"
        $TcpClient.Dispose()
        return
    }

    # 3. Establish the SSL stream using the validation callback
    # The correct constructor requires the NetworkStream, the leaveInnerStreamOpen boolean ($false), 
    # and the validation callback delegate.
    $SslStream = New-Object System.Net.Security.SslStream($TcpClient.GetStream(), $false, $ValidationCallback)

    try {
        # Perform the SSL handshake, passing the FQDN for SNI
        $SslStream.AuthenticateAsClient($Hostname)
    }
    catch {
        Write-Error "SSL handshake failed for $($Hostname). Error: $($_.Exception.Message)"
        $SslStream.Dispose()
        $TcpClient.Dispose()
        return
    }

    # 4. Retrieve the certificate object
    $Certificate = $SslStream.RemoteCertificate

    # Clean up the streams/connections
    $SslStream.Dispose()
    $TcpClient.Dispose()

    if (-not $Certificate) {
        Write-Error "Failed to retrieve RemoteCertificate from the SSL stream."
        return
    }

    # 5. Calculate the SHA256 hash (Thumbprint)
    $CertHashBytes = $Certificate.GetCertHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)

    # 6. Format the output
    $SSL_THUMBPRINT = [System.BitConverter]::ToString($CertHashBytes).Replace('-', '')

    # Add colons back for the traditional Thumbprint format
    return $SSL_THUMBPRINT -replace '(..(?!$))','$1:'
}

Function Get-VCFSDDCmToken {
    param(
        [Parameter(Mandatory=$true)]$SddcManagerFQDN,
        [Parameter(Mandatory=$true)]$VCSASSOUsername,
        [Parameter(Mandatory=$true)]$VCSASSOPassword
    )

    $payload = @{
        "username" = $VCSASSOUsername
        "password" = $VCSASSOPassword
    }

    $body = $payload | ConvertTo-Json

    try {
        $requests = Invoke-WebRequest -Uri "https://${SddcManagerFQDN}/v1/tokens" -Method POST -SkipCertificateCheck -Headers @{"Content-Type"="application/json";"Accept"="application/json"} -Body $body

        if($requests.StatusCode -eq 200) {
            $accessToken = ($requests.Content | ConvertFrom-Json).accessToken
        }
    } catch {
        Write-Error "Unable to retrieve SDDC Manager Token ..."
        $requests
        exit
    }

    $headers = @{
        "Content-Type"="application/json"
        "Accept"="application/json"
        "Authorization"="Bearer ${accessToken}"
    }

    return $headers
}

Function New-VCFImportValidation {
    param(
        [Parameter(Mandatory=$true)]$VCSAFQDN,
        [Parameter(Mandatory=$true)]$SddcManagerFQDN,
        [Parameter(Mandatory=$true)]$VCSASSOUsername,
        [Parameter(Mandatory=$true)]$VCSASSOPassword,
        [Parameter(Mandatory=$true)]$VCSARootPassword
    )

    $headers = Get-VCFSDDCmToken -SddcManagerFQDN $SddcManagerFQDN -VCSASSOUsername $VCSASSOUsername -VCSASSOPassword $VCSASSOPassword

    $VCSAThumbprint = Get-SSLThumbprint256 -URL "https://${VCSAFQDN}"

    $payload = @{
        "vcenterAddress" = $VCSAFQDN
        "vcenterSslThumbprint" = $VCSAThumbprint
        "vcenterSsoUsername" = $VCSASSOUsername
        "vcenterSsoPassword" = $VCSASSOPassword
        "vcenterRootSshPassword" =  $VCSARootPassword
    }

    $body = $payload | ConvertTo-Json

    try {
        $requests = Invoke-WebRequest -Uri "https://${SddcManagerFQDN}/v1/sddcs/imports/validations" -Method POST -SkipCertificateCheck -Headers $headers -Body $body

        if($requests.StatusCode -eq 202) {
            ($requests.Content | ConvertFrom-Json) | Select taskId, status
        }
    } catch {
        Write-Error "Unable to begin VCF Import Validation ..."
        exit
    }
}

Function Get-ValidationResultsTable {
    param(
        [Parameter(Mandatory=$true)]
        [PSObject[]]$Errors,

        # Optional filter parameter
        [String]$FilterStatus = $null
    )

    # Define the statuses that should be included in the output
    $AllowedStatuses = @('VALIDATION_SUCCESSFUL', 'VALIDATION_FAILED')
    
    # Validation Check for FilterStatus (allows $null or "")
    if ($FilterStatus -ne $null -and $FilterStatus -ne "") {
        if ($FilterStatus -notin $AllowedStatuses) {
            Write-Error "Invalid value '$FilterStatus' provided for FilterStatus. Must be 'VALIDATION_SUCCESSFUL' or 'VALIDATION_FAILED'."
            return
        }
    }
    
    # If FilterStatus is "" or $null, treat it as no filter.
    $EffectiveFilter = if ($FilterStatus -eq "") { $null } else { $FilterStatus }

    $Results = @()

    foreach ($Error in $Errors) {
        
        # 1. Check for nested errors and recurse
        if ($Error.PSObject.Properties.Name -contains "nestedErrors" -and $Error.nestedErrors) {
            
            # Recurse: Call the function again with the nested array, passing the filter down
            $Results += Get-ValidationResultsTable -Errors $Error.nestedErrors -FilterStatus $EffectiveFilter

        }
        # 2. Base Case: No nestedErrors found, and a message exists.
        elseif ($Error.PSObject.Properties.Name -contains "message" -and $Error.message) {
            
            $CurrentStatus = $null
            $CurrentImportance = "N/A" # Initialize importance level
            $CurrentRemediation = "N/A" # Initialize remediation message
            
            # --- Status and Importance Extraction (from CONTEXT) ---
            if ($Error.PSObject.Properties.Name -contains "context") {
                $ContextObject = $Error.context
                
                # Check for context object type
                if ($ContextObject -is [System.Management.Automation.PSCustomObject] -or $ContextObject -is [System.Collections.Hashtable]) {
                    
                    # Extract validationStatus
                    if ($ContextObject.PSObject.Properties.Name -contains "validationStatus" -and $ContextObject.validationStatus) {
                        $ExtractedStatus = $ContextObject.validationStatus
                    }
                    
                    # Extract importanceLevel
                    if ($ContextObject.PSObject.Properties.Name -contains "importanceLevel" -and $ContextObject.importanceLevel) {
                        $CurrentImportance = $ContextObject.importanceLevel
                    }
                } 
                # Handle cases where context might be a plain object
                elseif ($ContextObject) {
                    if ($ContextObject.validationStatus) {
                        $ExtractedStatus = $ContextObject.validationStatus
                    }
                    if ($ContextObject.importanceLevel) {
                        $CurrentImportance = $ContextObject.importanceLevel
                    }
                }
            }
            # --- Remediation Message Extraction (from $ERROR object) ---
            if ($Error.PSObject.Properties.Name -contains "remediationMessage" -and $Error.remediationMessage) {
                 $CurrentRemediation = $Error.remediationMessage
            }
            # -----------------------------------------------------------
            
            # 3. Apply the Status Inclusion Filter
            if ($ExtractedStatus -in $AllowedStatuses) {
                $CurrentStatus = $ExtractedStatus
            }

            # 4. Create output object ONLY if the status was allowed AND it matches the effective filter.
            if ($CurrentStatus) {
                
                # Apply filter logic: If no filter is set, or if the status matches the filter
                if (-not $EffectiveFilter -or ($CurrentStatus -ceq $EffectiveFilter)) {
                    
                    # Create the structured object with all four properties
                    $Results += [PSCustomObject]@{
                        Message             = $Error.message
                        Status              = $CurrentStatus
                        ImportanceLevel     = $CurrentImportance
                        RemediationMessage  = $CurrentRemediation # Extracted from the main error object
                    }
                }
            }
        }
    }
    
    # Return the collected results
    return $Results
}

Function Get-VCFImportValidation {
    param(
        [Parameter(Mandatory=$true)]$VCSAFQDN,
        [Parameter(Mandatory=$true)]$SddcManagerFQDN,
        [Parameter(Mandatory=$true)]$VCSASSOUsername,
        [Parameter(Mandatory=$true)]$VCSASSOPassword,
        [Parameter(Mandatory=$true)]$VCSARootPassword,
        [Parameter(Mandatory=$true)]$TaskId,
        [Parameter(Mandatory=$false)]$FailedValidationsOnly=$true
    )

    $headers = Get-VCFSDDCmToken -SddcManagerFQDN $SddcManagerFQDN -VCSASSOUsername $VCSASSOUsername -VCSASSOPassword $VCSASSOPassword

    try {
        $requests = Invoke-WebRequest -Uri "https://${SddcManagerFQDN}/v1/sddcs/imports/validations/${TaskId}" -Method GET -SkipCertificateCheck -Headers $headers

        if($requests.StatusCode -eq 200) {
            $response = $requests.Content | ConvertFrom-Json

            if($response.status -eq "SUCCESS") {
                $validations = $response.validationResult

                if($FailedValidationsOnly) {
                    return (Get-ValidationResultsTable -Errors $validations -FilterStatus 'VALIDATION_FAILED') | select Status,ImportanceLevel,RemediationMessage,Message | Sort-Object -Property Status
                } else {
                    return (Get-ValidationResultsTable -Errors $validations) | select Status,ImportanceLevel,RemediationMessage,Message | Sort-Object -Property Status
                }
            } elseif($response.status -eq "IN_PROGRESS") {
                Write-Host "VCF Import Validation is still running, please check back in a few minutes"
            } else {
                Write-Error "VCF Import Validation Task ID is either invalid or failed"
                $response
            }
        }
    } catch {
        Write-Error "Unable to retrieve VCF Import Validation Results ..."
        exit
    }
}



