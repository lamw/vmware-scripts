Function Decode-VMwareLicense {
    param(
        [Parameter(Mandatory=$true)][String[]]$LicenseKeys
    )

    if($global:DefaultVIServer -eq $null) {
        Write-Error "No vCenter Server connection detected, please use `"Connect-VIServer`" cmdlet"
        exit 1
    }

    $licenseManager = Get-View $global:DefaultVIServer.ExtensionData.Content.LicenseManager

    foreach ($LicenseKey in $LicenseKeys) {
        $license = ($licenseManager.DecodeLicense($LicenseKey))

        $expiredDate = ""
        $licenseInfos = @()
        foreach ($property in $license.properties) {
            if($property.key -eq "expirationDate") {
                $expiredDate = $property.value
            } elseif($property.key -eq "LicenseInfo") {
                $licenseInfos += $property.value
            }
        }

        $productsLicenseInfo = @()
        foreach ($licenseInfo in $licenseInfos) {
            $features = @()
            foreach ($property in $licenseInfo.properties) {
                switch($property.key) {
                    "ProductName" {
                        $productName = $property.value
                    }
                    "ProductVersion" {
                        $productVersion = $property.value
                    }
                    "feature" {
                        $features+=$property.value
                    }
                }
            }
            $tmp = [pscustomobject][ordered]@{
                Product = $productName
                Version = $productVersion
                Features = $features.Value
            }

            $productsLicenseInfo+=$tmp
        }

        $lastFive = ($license.LicenseKey).Remove(0, ($license.LicenseKey.Length - 5))
        $masked = "XXXXX-XXXXX-XXXXX-XXXXX-${lastFive}"

        Write-Host -ForegroundColor Yellow "`nLicense: " -NoNewline
        Write-Host $masked
        Write-Host -ForegroundColor Yellow "Name: " -NoNewline
        Write-Host $license.Name
        Write-Host -ForegroundColor Yellow "Capacity: " -NoNewline
        Write-Host $license.Total
        Write-Host -ForegroundColor Yellow "Unit: " -NoNewline
        Write-Host $license.CostUnit
        Write-Host -ForegroundColor Yellow "Expiration: " -NoNewline
        Write-Host $expiredDate

        foreach ($product in $productsLicenseInfo) {
            Write-Host -ForegroundColor Yellow "Product: " -NoNewline
            Write-Host -ForegroundColor Cyan "$($product.Product) $($product.Version)"
            Write-Host -ForegroundColor Yellow "Features: " -NoNewline
            Write-Host -ForegroundColor Magenta "$(($product.features | out-string).replace("`n", ",").trim(","))"
        }
        Write-Host -ForegroundColor Green "------`n"
    }
}