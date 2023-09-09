Function Get-VCSACertificate {
<#
    .DESCRIPTION Function to retreive all VCSA certifcates (Machine, VMCA Root, STS & Trusted Root)
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER Type
        Optionally filter on a specific certificate type: MACHINE, VMCA_ROOT, STS or TRUSTED_ROOT
#>
    param(
        [Parameter(Mandatory=$false)][ValidateSet("MACHINE","VMCA_ROOT","STS", "TRUSTED_ROOT")][string]$Type
    )

    Function CreateCertObject {
        param(
            [Parameter(Mandatory=$true)]$Cert,
            [Parameter(Mandatory=$true)]$Type
        )

        $tmp = [pscustomobject] [ordered]@{
            Type = $Type
            CertificateCommonName = [regex]::Match($cert.Subject, 'CN=([^,]+)').Value.replace("CN=","");
            CertificateIssuedBy = [regex]::Match($cert.issuer, 'CN=([^,]+)').Value.replace("CN=","");
            CertificateValidFrom = $cert.NotBefore;
            CertificateValidUntil = $cert.NotAfter;
            CertificateSignatureAlgorithm = $cert.SignatureAlgorithm.FriendlyName;
            CertificateThumbprint = $cert.Thumbprint;
            CertificateOrganization = [regex]::Match($cert.Subject, 'O=([^,]+)').Value.replace("O=","");
            CertificateOrganizationalUnit = [regex]::Match($cert.Subject, 'OU=([^,]+)').Value.replace("OU=","");
            CertificateStateProvince = [regex]::Match($cert.Subject, 'S=([^,]+)').Value.replace("S=","");
            CertificateCountry = [regex]::Match($cert.Subject, 'C=([^,]+)').Value.replace("C=","");
            IssuerName = [regex]::Match($cert.issuer, 'CN=([^,]+)').Value.replace("CN=","");
            IssuerOrganization = [regex]::Match($cert.issuer, 'O=([^,]+)').Value.replace("O=","");
            IssuerOrganizationalUnit = [regex]::Match($cert.issuer, 'OU=([^,]+)').Value.replace("OU=","");
            IssuerStateProvince = [regex]::Match($cert.issuer, 'S=([^,]+)').Value.replace("S=","");
            IssuerCountry = [regex]::Match($cert.issuer, 'C=([^,]+)').Value.replace("C=","");
            # BigInt required to convert serial from Hex->Dec https://stackoverflow.com/a/69207938
            IssuerSerialNumber = [decimal][bigint]::Parse($cert.SerialNumber, [System.Globalization.NumberStyles]::AllowHexSpecifier)
            IssuerVersion = $cert.Version
        }
        return $tmp
    }

    $results =@()

    # Cert library to convert from PEM format
    $xCert2Type = [System.Security.Cryptography.X509Certificates.X509Certificate2]

    # Retrieve VMCA_ROOT and STS
    $signingCertService = Get-cisservice "com.vmware.vcenter.certificate_management.vcenter.signing_certificate"
    $signingCerts = $signingCertService.get().signing_cert_chains.cert_chain

    foreach ($signingCert in $signingCerts) {
        $cert = $xCert2Type::CreateFromPem($signingCert) -as $xCert2Type
        if($cert.Subject -eq "CN=ssoserverSign") {
            $c = CreateCertObject -Cert $cert -Type "STS"
            $results+=$c
        } else {
            $c = CreateCertObject -Cert $cert -Type "VMCA_ROOT"
            $results+=$c
        }
    }

    # Retrieve MACHINE
    $tlsService = Get-cisservice "com.vmware.vcenter.certificate_management.vcenter.tls"
    $tlsCert = $tlsService.get()

    $tmp = [pscustomobject] [ordered]@{
        Type = "MACHINE"
        CertificateCommonName = [regex]::Match($tlsCert.subject_dn, 'CN=([^,]+)').Value.replace("CN=","");
        CertificateIssuedBy = [regex]::Match($tlsCert.subject_dn, 'C=([^,]+)').Value.replace("C=","");
        CertificateValidFrom = $tlsCert.valid_from;
        CertificateValidUntil = $tlsCert.valid_to;
        CertificateSignatureAlgorithm = $tlsCert.signature_algorithm;
        CertificateThumbprint = $tlsCert.thumbprint;
        CertificateOrganization = [regex]::Match($tlsCert.subject_dn, 'O=([^,]+)').Value.replace("O=","");
        CertificateOrganizationalUnit = [regex]::Match($tlsCert.subject_dn, 'OU=([^,]+)').Value.replace("OU=","");
        CertificateStateProvince = [regex]::Match($tlsCert.subject_dn, 'ST=([^,]+)').Value.replace("ST=","");
        CertificateCountry = [regex]::Match($tlsCert.subject_dn, 'C=([^,]+)').Value.replace("C=","");
        IssuerName = [regex]::Match($tlsCert.issuer_dn, 'CN=([^,]+)').Value.replace("CN=","");
        IssuerOrganization = [regex]::Match($tlsCert.issuer_dn, 'O=([^,]+)').Value.replace("O=","");
        IssuerOrganizationalUnit = [regex]::Match($tlsCert.issuer_dn, 'OU=([^,]+)').Value.replace("OU=","");
        IssuerStateProvince = [regex]::Match($tlsCert.issuer_dn, 'ST=([^,]+)').Value.replace("ST=","");
        IssuerCountry = [regex]::Match($tlsCert.issuer_dn, 'C=([^,]+)').Value.replace("C=","");
        IssuerSerialNumber = $tlsCert.serial_number
        IssuerVersion = $cert.version
    }
    $results+=$tmp

    # Retrieve TRUSTED_ROOT
    $trustedRootChainService = Get-cisservice "com.vmware.vcenter.certificate_management.vcenter.trusted_root_chains"
    $trustedRootChains = $trustedRootChainService.list().chain
    foreach ($trustedRootChain in $trustedRootChains) {
        $rootChain = $trustedRootChainService.get($trustedRootChain).cert_chain.cert_chain | Out-String
        $rootCert = $xCert2Type::CreateFromPem($rootChain) -as $xCert2Type

        $tmp = [pscustomobject] [ordered]@{
            Type = "TRUSTED_ROOT"
            CertificateCommonName = [regex]::Match($rootCert.Subject, 'CN=([^,]+)').Value.replace("CN=","");
            CertificateIssuedBy = [regex]::Match($rootCert.issuer, 'CN=([^,]+)').Value.replace("CN=","");
            CertificateValidFrom = $rootCert.NotBefore;
            CertificateValidUntil = $rootCert.NotAfter;
            CertificateSignatureAlgorithm = $rootCert.SignatureAlgorithm.FriendlyName;
            CertificateThumbprint = $rootCert.Thumbprint;
            CertificateOrganization = [regex]::Match($rootCert.Subject, 'O=([^,]+)').Value.replace("O=","");
            CertificateOrganizationalUnit = [regex]::Match($rootCert.Subject, 'OU=([^,]+)').Value.replace("OU=","");
            CertificateStateProvince = [regex]::Match($rootCert.Subject, 'S=([^,]+)').Value.replace("S=","");
            CertificateCountry = [regex]::Match($rootCert.Subject, 'C=([^,]+)').Value.replace("C=","");
            IssuerName = [regex]::Match($rootCert.issuer, 'CN=([^,]+)').Value.replace("CN=","");
            IssuerOrganization = [regex]::Match($rootCert.issuer, 'O=([^,]+)').Value.replace("O=","");
            IssuerOrganizationalUnit = [regex]::Match($rootCert.issuer, 'OU=([^,]+)').Value.replace("OU=","");
            IssuerStateProvince = [regex]::Match($rootCert.issuer, 'S=([^,]+)').Value.replace("S=","");
            IssuerCountry = [regex]::Match($rootCert.issuer, 'C=([^,]+)').Value.replace("C=","");
            # BigInt required to convert serial from Hex->Dec https://stackoverflow.com/a/69207938
            IssuerSerialNumber = [decimal][bigint]::Parse($rootCert.SerialNumber, [System.Globalization.NumberStyles]::AllowHexSpecifier)
            IssuerVersion = $rootCert.Version
        }
        $results+=$tmp
    }

    if ($PSBoundParameters.ContainsKey("Type")){
        $results | where {$_.Type -eq $Type}
    } else {
        $results
    }
}