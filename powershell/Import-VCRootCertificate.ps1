# Author: William Lam
# Blog: www.williamlam.com
# Description: Script to import vCenter Server 6.x root certificate to Mac OS X or NIX* system
# Reference: http://www.williamlam.com/2016/07/automating-the-import-of-vcenter-server-6-x-root-certificate.html

Function Import-VCRootCertificate ([string]$VC_HOSTNAME) {
    # Set the default download directory to current users desktop
    # Download will be saved as cert.zip
    $DOWNLOAD_PATH=[Environment]::GetFolderPath("Desktop")
    $DOWNLOAD_FILE_NAME="cert.zip"
    $DOWNLOAD_FILE_PATH="$DOWNLOAD_PATH\$DOWNLOAD_FILE_NAME"
    $EXTRACTED_CERTS_PATH="$DOWNLOAD_PATH\certs"

    # VAMI URL, easy way to verify if we have Windows VC or VCSA
    $URL = "https://"+$VC_HOSTNAME+":5480"
    $FOUND_VCSA = 1
	
	try {
		# Checking to see if we have a Windows VC or VCSA
		# as they have different SSL Certificate download endpoints
		$websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
		try {
			Write-Host "`nTesting vCenter URL $URL"
			$result = Invoke-WebRequest -Uri $URL -TimeoutSec 5
		}
		catch [System.NotSupportedException] {
			Write-Host $_.Exception -ForegroundColor "Red" -BackgroundColor "Black"
			throw
		}
		catch [System.Net.WebException] {
			Write-Host $_.Exception
			$FOUND_VCSA = 0
		}

		if($FOUND_VCSA) {
			$VC_CERT_DOWNLOAD_URL="https://"+$VC_HOSTNAME+"/certs/download"
		} else {
			$VC_CERT_DOWNLOAD_URL="https://"+$VC_HOSTNAME+"/certs/download.zip"
		}

		# Required to ingore SSL Warnings
		if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type)
		{
			add-type -TypeDefinition  @"
				using System.Net;
				using System.Security.Cryptography.X509Certificates;
				public class TrustAllCertsPolicy : ICertificatePolicy {
					public bool CheckValidationResult(
						ServicePoint srvPoint, X509Certificate certificate,
						WebRequest request, int certificateProblem) {
						return true;
					}
				}
"@
		}
		[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
		
		# Download VC's SSL Certificate
		Write-Host "`nDownloading VC SSL Certificate from $VC_CERT_DOWNLOAD_URL to $DOWNLOAD_FILE_PATH"
		$webclient = New-Object System.Net.WebClient
		$webclient.DownloadFile("$VC_CERT_DOWNLOAD_URL","$DOWNLOAD_FILE_PATH")

		# Extracting SSL Certificate zip file
		Add-Type -AssemblyName System.IO.Compression.FileSystem
		[System.IO.Compression.ZipFile]::ExtractToDirectory($DOWNLOAD_FILE_PATH, "$DOWNLOAD_PATH")

		# Find SSL certificates ending with .0
		$Dir = get-childitem $EXTRACTED_CERTS_PATH -recurse
		$List = $Dir | where {$_.extension -eq ".0"}

		# Thanks to https://lennytech.wordpress.com/2013/06/18/powershell-install-sp-root-cert-to-trusted-root/ for snippet of code
		# Retrieve Trusted Root Certification Store
		$certStore = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Store Root, LocalMachine

		# Import VC SSL Certificate(s) into cert store
		Write-Host "Importing to VC SSL Certificate to Certificate Store"
		foreach ($a in $list) {
			$file = "$EXTRACTED_CERTS_PATH\$a"

			# Get the certificate from the location where it was placed by the export process
			$cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 $file

			# Open the store with maximum allowed privileges
			$certStore.Open("MaxAllowed")

			# Add the certificate to the store
			$certStore.Add($cert)
		}
		# Close the store
		$certStore.Close()
	}
	catch {
		Write-Host -ForegroundColor "Red" -BackgroundColor "Black" $_.Exception
	}
	finally {
		#clean up
		if (Test-Path $DOWNLOAD_FILE_PATH) {
			Write-Host "Cleaning up, deleting $DOWNLOAD_FILE_PATH"
			Remove-Item $DOWNLOAD_FILE_PATH
		}
		if (Test-Path $EXTRACTED_CERTS_PATH) {
			Write-Host "Cleaning up, deleting $EXTRACTED_CERTS_PATH"
			Remove-Item -Recurse -Force $EXTRACTED_CERTS_PATH
		}
	}
}

Import-VCRootCertificate $Args[0]
