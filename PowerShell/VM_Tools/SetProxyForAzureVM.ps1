Clear-Host

$ScriptPath   = "$(split-path -parent $MyInvocation.MyCommand.Definition)"
$ScriptName   = "$(Split-Path -Leaf   $MyInvocation.MyCommand.Definition)"
$ScriptNameNX = "$($ScriptName.split('.')[0])"

Set-Location -Path "$ScriptPath"

######################################################################################################################
# functions
######################################################################################################################
function WriteError {
    Param ( [Parameter(ValueFromPipeline,ValueFromRemainingArguments=$true)] [String[]]$message )

    Process {
        $pref = "[ERROR]"
        $pref = $pref.padright(11)
        $msg = (Get-Date).tostring('yyyy-MM-dd HH:mm:ss') + " $pref $message"
        
        Write-Host -ForegroundColor Red "$msg"
        if ($logfile) { "$msg" *>> "$logfile" }
    }
}

function WritePlain {
    Param ( [Parameter(ValueFromPipeline,ValueFromRemainingArguments=$true)] [String[]]$message )

    Process {
        Write-Host -ForegroundColor White "$message"
        if ($logfile) { "$message" *>> "$logfile" }
    }
}

function WriteInformation {
    Param ( [Parameter(ValueFromPipeline,ValueFromRemainingArguments=$true)] [String[]]$message )

    Process {
        $pref = "[INFO]"
        $pref = $pref.padright(11)
        $msg = (Get-Date).tostring('yyyy-MM-dd HH:mm:ss') + " $pref $message"
        
        Write-Host -ForegroundColor Green "$msg"
        if ($logfile) { "$msg" *>> "$logfile" }
    }
}

######################################################################################################################
# Main program
######################################################################################################################

#---------------------------------------------------------------------------------------------------------------------
# perform checks
#---------------------------------------------------------------------------------------------------------------------

#-----------
# parameters
#-----------

$timestamp = $(Get-Date).tostring('yyyy-MM-dd_HHmmss')
$logfile      = "c:\temp\$($timestamp)_$($ScriptNameNX).log"
$logpath      = "$logfile" | Split-Path -Parent

#-----------------------------------------
# ensure that downloaddirectory is present
#-----------------------------------------
if (! $(Test-Path -Path "$logpath")) {
    New-Item -Path "$logpath" -ItemType Directory | Out-Null
}

#---------------------------------------------------------------------------------------------------------------------
# query Azure Metadata Service
#---------------------------------------------------------------------------------------------------------------------
$resultjson = Invoke-WebRequest -Uri "http://169.254.169.254/metadata/instance?api-version=2019-08-15" -Headers @{"Metadata"="true"}

if ($resultjson.StatusCode -ne 200) {
    WriteError "Metadata of VM could not be retrieved - exiting"
    exit 12
}
$result = ($resultjson.Content | ConvertFrom-Json).compute

##########################################################################################################################
# find proxies
##########################################################################################################################

#------------------------------------------------------
# define proxies to be tested according to VMs location
#------------------------------------------------------
switch ($result.location) {
    "eastus2" {
        $testorder = '10.xx.xx.xx:8080', '10.yy.yy.yy:8080'
        WriteInformation "Checking US Proxies ..."
    }

    "westeurope" {
        $testorder = '10.bb.bb.bb:8080', '10.aa.aa.aa:8080'
        WriteInformation "Checking WestEurope Proxies ..."
    }

    default {
        $testorder = '10.aa.aa.aa:8080', '10.bb.bb.bb:8080', '10.cc.cc.cc:8080', '10.dd.dd.dd:8080'
        WriteInformation "Unknown location $($result.location) - checking all known Proxies ..."
    }
}

#---------------------------------------------------
# Loop over all proxies in list, stop at first match
#---------------------------------------------------
$proxyIPPort = $null
$testorder | ForEach-Object {
    if ($proxyIPPort -eq $null) {
        $IP,$Port = $_ -split ':'
        $result = Test-NetConnection -Port $Port -ComputerName $IP
        if ($result.TcpTestSucceeded) {
            $proxyIPPort = "$($result.ComputerName):$($result.RemotePort)"
        }
    }
}

WriteInformation "Found Web Proxy on $proxyIPPort"

######################################################################################################################
# Set Proxy IP for SYSTEM
######################################################################################################################

if ($proxyIPPort) {
    #------------------------------------------------------------------------------------------------
    # the following lines set the proxy for user SYSTEM to a value which is specified in as parameter
    #------------------------------------------------------------------------------------------------
    WriteInformation "Configuring Proxy for SYSTEM account ..."

    Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
    Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name Proxyserver -Value "$proxyIPPort"

    $LegacyKey = 'Registry::HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'
    if (-not (Test-Path -Path "$LegacyKey" -Type Container)) {
        WriteInformation "Creating [$($LegacyKey)]"
        New-Item -Path "$LegacyKey" -ItemType Directory | Out-Null
    }

    #-----------------------------------------------------------------------------------------------------
    # the following lines set the proxy for the current user to a value which is specified in as parameter
    #-----------------------------------------------------------------------------------------------------
    WriteInformation "Configuring Proxy for CURRENT User ..."

    Set-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
    Set-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name Proxyserver -Value "$proxyIPPort"

    $LegacyKey = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'
    if (-not (Test-Path -Path "$LegacyKey" -Type Container)) {
        WriteInformation "Creating [$($LegacyKey)]"
        New-Item -Path "$LegacyKey" -ItemType Directory | Out-Null
    }

    #------------------------------------------------------------------------------------------------------
    # this is Microsoft's solution: It copies some (more) settings from the current user to the SYSTEM user
    #------------------------------------------------------------------------------------------------------
    # $obj = Get-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
    # Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name DefaultConnectionSettings -Value $obj.DefaultConnectionSettings
    # Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name SavedLegacySettings       -Value $obj.SavedLegacySettings

    # $obj = Get-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    # Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value $obj.ProxyEnable
    # Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name Proxyserver -Value $obj.Proxyserver


    # https://stackoverflow.com/questions/4283027/whats-the-format-of-the-defaultconnectionsettings-value-in-the-windows-registry
    # https://stackoverflow.com/questions/1564627/how-to-set-automatic-configuration-script-for-a-dial-up-connection-programmati

    # 0.  keep this value
    # 1.  "00" placeholder
    # 2.  "00" placeholder
    # 3.  "00" placeholder
    # 4.  "xx" increments if changed
    # 5.  "xx" increments if 4. is "FF"
    # 6.  "00" placeholder
    # 7.  "00" placeholder
    # 8.  "01"=proxy deaktivated; other value=proxy enabled
    # 9.  "00" placeholder
    # 10. "00" placeholder
    # 11. "00" placeholder
    # 12. "xx" length of "proxyserver:port"
    # 13. "00" placeholder
    # 14. "00" placeholder
    # 15. "00" placeholder
    #     "proxyserver:port"
    # if 'Bypass proxy for local addresses':::
    #     other stuff with unknown length
    #     "<local>"
    #     36 times "00"
    # if no 'Bypass proxy for local addresses':::
    #     40 times "00"

    # $LegacyKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet     Settings\Connections'

    #---------------------------------------------
    # get current proxy settings of SYSTEM account
    #---------------------------------------------
  
    $EAP = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $data = (Get-ItemProperty -Path "$LegacyKey" -Name  DefaultConnectionSettings).DefaultConnectionSettings
    $ErrorActionPreference = $EAP

    #------------------------------------------
    # debugging only: copy old data to new data
    #------------------------------------------
    # [byte[]]$datanew = @()
    # for ($i = 0; $i -lt $data.Count; $i++) {
    #     $datanew += $data[$i]
    # }

    if ($data) {
        #-----------------------------------------------------------------------------
        # copy the first 16 bytes of the old string (jsut to make things a bit easier)
        #-----------------------------------------------------------------------------
        [byte[]]$datanew = @()
        for ($i = 0; $i -lt 16; $i++) {
            $datanew += $data[$i]
        }
    }
    else {
        [byte[]]$datanew = @()
        $data = 0x46,0x00,0x00,0x00,0x04,0x00,0x00,0x00, 0x03,0x00,0x00,0x00,0x11,0x00,0x00,0x00
        for ($i = 0; $i -lt $data.count; $i++) {
            $datanew += $data[$i]
        }
    }

    #-----------------------
    # set new proxy settings
    #-----------------------

    $datanew[8]  = 3                   # set to 'Use a proxy server for your LAN'
    $datanew[12] = $proxyIPPort.Length # set length of proxy port configuration

    $datanew[13] = 0                   # set to zero
    $datanew[14] = 0                   # set to zero
    $datanew[15] = 0                   # set to zero

    #----------------------------
    # configure Proys IP and port
    #----------------------------
    $offset = 16
    for ($i = 0; $i -lt $proxyIPPort.Length; $i++) {
        if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' } # add dummy entry
        $datanew[$($offset + $i)] = [byte][char]$($proxyIPPort.Substring($i,1))
    
        #[byte][char]$($proxyIPPort.Substring($i,1))
        #[char]$datanew[$($offset + $i)]
    }
    $offset += $i

    #---------------------------------
    # configure additional information
    #---------------------------------
    $ProxyOverride = ""
    $ProxyOverride = "169.254.169.254;10.*;*.azure.net;<local>"                                                    # this means: Bypass proxy server for local addresses
                                                                                          
    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = $ProxyOverride.Length ; $offset++                    # length of additional information
                                                                                          
    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = 0                             ; $offset++                    # set to zero
                                                                                          
    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = 0                             ; $offset++                    # set to zero
                                                                                          
    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = 0                             ; $offset++                    # set to zero

    for ($i = 0; $i -lt $ProxyOverride.Length; $i++) {
        if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }          # add dummy entry
        $datanew[$($offset + $i)] = [byte][char]$($ProxyOverride.Substring($i,1))
    }
    $offset += $i

    if ($ProxyOverride -ne "") {
            Set-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyOverride -Value $($ProxyOverride -replace ";<local>","")
            Set-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings"   -Name ProxyOverride -Value $($ProxyOverride -replace ";<local>","")
    }

    #-------------------------------
    # set proxy configuration script
    #-------------------------------
    $proxyConfigScript = ""                                                               # location of the proxy configuration script

    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = $proxyConfigScript.Length     ; $offset++                    # length of the proxy configuration script

    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = 0                             ; $offset++                    # set to zero
                                                                                          
    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = 0                             ; $offset++                    # set to zero
                                                                                          
    if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }              # add dummy entry
    $datanew[$offset]      = 0                             ; $offset++                    # set to zero


    #-----------------------
    # set next 32 bytes to 0
    #-----------------------
    for ($i = 0; $i -lt 32; $i++) {
        # "$($offset + $i)"

        if ($($offset + $i) -ge $datanew.Length) { $datanew += [byte][char]'x' }
        $datanew[$($offset + $i)] = 0

    }

    #-----------------------------------------
    # debugging only: compare old and new data
    #-----------------------------------------
    # for ($i = 0; $i -lt $data.Count; $i++) {
    #     $result = "{0:d3}:   {1:d3}  {1:X3}  {2}     -->  {3:d3}  {3:X3}  {4}" -f $i, $data[$i], [char]$data[$i], $datanew[$i], [char]$datanew[$i]
    # 
    #     if ($data[$i] -eq $datanew[$i]) { Write-Host -ForegroundColor Green "$result" }
    #     else                            { Write-Host -ForegroundColor Red   "$result" }
    # }
    # Write-Host -ForegroundColor Red "$($datanew.Length)"

    #----------------------
    # set values for SYSTEM
    #----------------------
    Set-ItemProperty -Path "$LegacyKey" -Name DefaultConnectionSettings -Value $datanew
    Set-ItemProperty -Path "$LegacyKey" -Name SavedLegacySettings       -Value $datanew

    #----------------------------
    # set values for Current User
    #----------------------------
    Set-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name DefaultConnectionSettings -Value $datanew
    Set-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name SavedLegacySettings       -Value $datanew
}
else {
    WriteInformation "Skipping to configure Proxy for SYSTEM account ..."
}

######################################################################################################################
# finish script
######################################################################################################################
WritePlain ""
WriteInformation "Script finished"
exit 0