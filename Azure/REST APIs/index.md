---
title: Calling Azure REST APIs
---

# Define REST API endpoint

First thing you need is the locator of the REST API endpoint you want to use:

``` Powershell
$ResourceURI         = "https://management.azure.com"
```

# Get and prepare bearer token

Now you have to logon Azure, retrieve a token and prepare the HTTP authentication header.

Note, that the token has a limited lifetime.

## ... via Azure CLI

``` Powershell
#--------------------------------------
# Logon to Azure / to logout: az logout
#--------------------------------------
az login --use-device-code

#--------------------------------------------------------------
# Get Token for REST API and prepare HTTP authentication header
#--------------------------------------------------------------
$gettoken = az account get-access-token --resource="$ResourceURI"
if ($gettoken -ne $null) {
    $token  = ($gettoken | ConvertFrom-Json).accesstoken
    $APItoken = @{}
    $APItoken.Add("Authorization", "bearer $token")

    $validto  = ($gettoken | ConvertFrom-Json).expiresOn
    Write-Host -ForegroundColor Yellow "Token is valid until $validto"
}
```

## ... via Azure CLI

``` Powershell
#-------------------------------------------------
# Logon to Azure / to logout: Disconnect-AzAccount
#-------------------------------------------------
$context = (Get-AzContext | Select-Object -First 1)
if ([string]::IsNullOrEmpty($context)) {
    $null = Connect-AZAccount -UseDeviceAuthentication    
    $context = (Get-AzContext | Select-Object -First 1)
}

#--------------------------------------------------------------
# Get Token for REST API and prepare HTTP authentication header
#--------------------------------------------------------------
$apiToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, "Never", $null, "$ResourceURI")
if ($apiToken -ne $null) {
    $APItoken = @{
        'Authorization'          = 'Bearer ' + $apiToken.AccessToken.ToString()
        'Content-Type'           = 'application/json'
        'X-Requested-With'       = 'XMLHttpRequest'
        'x-ms-client-request-id' = [guid]::NewGuid()
        'x-ms-correlation-id'    = [guid]::NewGuid()
    }

    $validto  = $apiToken.ExpiresOn
    Write-Host -ForegroundColor Yellow "Token is valid until $validto"
}
```

# Call the REST API

Taking the Enterprise Portal as example, the code below calls the API which lists all possible Operations of the Billing API (see https://docs.microsoft.com/en-us/rest/api/billing/2017-04-24-preview/operations/list).

``` Powershell
#------------------------------------
# Retrieve all Billing API Operations
#------------------------------------
Write-Host -ForegroundColor Yellow "Billing API Operations:"
$ListOperationsURI  = 'https://management.azure.com/providers/Microsoft.Billing/operations?api-version=2019-10-01-preview'
$Operations         = (Invoke-RestMethod -Method Get -UseBasicParsing -Headers $APItoken -Uri "$ListOperationsURI").value
$Operations | ConvertTo-Json -Depth 100

#---------------------------------
# format and output the operations
#---------------------------------
$a = @()
$Operations | ForEach-Object {
    $x = New-Object psobject -Property @{
        Operation = $_.display.operation
        Resource  = $_.display.resource
        Name      = $_.name
    }

    $a += $x
}
$a | Sort-Object -Property Resource,Name | ft -AutoSize
```