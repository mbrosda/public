---
title: VMs and Security
---

# Example: Retrieve Secret from Key Vault using a system assigned Identity

```PowerShell
#------------------------------------------------------------------------------------------
# see also https://gsexdev.blogspot.com/2019/09/using-system-assigned-managed-identity.html
#------------------------------------------------------------------------------------------

$KeyVaultURL = "https://xxxxxxxxxxxxxxxxxxxx.vault.azure.net/secrets/dbaccountpw?api-version=7.0"

$SptokenResult = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Headers @{Metadata="true"}
$Sptoken       = ConvertFrom-Json $SptokenResult.Content

$headers = @{
'Content-Type'  = 'application\json'
'Authorization' = 'Bearer ' + $Sptoken.access_token
}

$Response = (Invoke-WebRequest -Uri $KeyVaultURL  -Headers $headers)

($Response.Content | ConvertFrom-Json).value
```

__Prerequisites:__

* Key Vault Access Policy must be set for the object (PowerShell: Set-AzKeyVaultAccessPolicy)
* The network policies on the Key vault must match the given Scenario
* If only specified Azure subnets have access to the Key Vault, then ensure that connection to the key vault is performed directly (e.g. not via Proxy)
* Same applies for 169.254.169.254. This IP must also be added to the 'noproxy' list.

Example exception list for Proxy settings:

```
169.254.169.254;10.*;*.azure.net
```