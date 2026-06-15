# Requires -PSVersion 3.0
# Fortigate
#
# The Following Steps are Performed
#
# Clubbed : Common Function's Used and Token Generation
#==========================================#
# LogRhythm SmartResponse Plugin           #
# FortiGate  - SmartResponse               #
# ashish.saxena@logrhythm.com              #
# v3.1  --  Dec, 2020                      #
#==========================================#
[CmdletBinding()] 
Param(  
[Parameter(Position=0,Mandatory=$True)] 
[string]$UserName, 
[Parameter(Position=1,Mandatory=$True)] 
[string]$Password, 
[Parameter(Position=2,Mandatory=$True)] 
[string]$FortiIP, 
[Parameter(Position=3,Mandatory=$True)] 
[string]$Port,
[Parameter(Position=4,Mandatory=$True)] 
[string]$Command,
[Parameter(Position=5,Mandatory=$True)] 
[string]$Object,
[Parameter(Position=6,Mandatory=$True)] 
[string]$ScriptName
)

$ErrorActionPreference = 'Stop'
# Set up a trap to properly exit on terminating exceptions
Trap [Exception] 
{
    Write-Error $("TRAPPED: " + $_)
    Exit
}

#*******************************************
#Function To Validate Input Parameters
Function Input-Validation
{
 #Data Validation
 If ($Command -eq "add_ip" -and $ScriptName -match 'Add-IP'){
    #Write-Host "Add_IP $object"
    $Global:IPRange = 0
    if ($Object -match $IPRegex){
     #Write-Host "Valid IP"
    }
    elseif ($Object -match $GroupRegex){
     Throw "`nInvalid IP. However, valid group name you can use Display Group Info action with same parameters.`n"
    }
    elseif ($Object -match $DomainRegex){
     Throw "`nInvalid IP. However, valid domain you can use Add Domain action with same parameters.`n"
    }
    elseif($Object -match $IPRangeRegex){
    #Write-Host "Valid IP Range"
    $Global:IPRange = 1
    Subnet-IP
    }
    else {
     Throw "`nInvalid IP.`n"
    }
 }
 Elseif ($Command -eq "add_domain" -and $ScriptName -match 'Add-Domain'){
    #Write-Host "Add_IP $object"
    if ($Object -match $DomainRegex){
     #Write-Host "Valid Domain"
    }
    elseif ($Object -match $GroupRegex){
     Throw "`nInvalid Domain. However, valid group name you can use Display Group Info action with same parameters.`n"
    }
    elseif ($Object -match $IPRegex){
     Throw "`nInvalid Domain. However, valid ip you can use Add IP action with same parameters.`n"
    }
    else {
     Throw "`nInvalid Domain.`n"
    }
 }
 Elseif ($Command -eq "get" -and $ScriptName -match 'Group-Info'){
    #Write-Host "Get $object"
    if ($Object -match $GroupRegex){
     #Write-Host "Valid Group Name"
    }
    elseif ($Object -match $IPRegex){
     Throw "`nInvalid Group Name. However, valid ip you can use Add IP action with same parameters.`n"
    }
    elseif ($Object -match $DomainRegex){
     Throw "`nInvalid Group Name. However, valid domain you can use Add Domain action with same parameters.`n"
    }
    else {
     Throw "`nInvalid Group Name.`n"
    }
  }
 Else {
    Throw "`nInvalid Command/Script. Please use Add_IP/Add_Domain/Get Command with suitable script.`n"
 }
}

#Function to Add IP/Domain to Group
Function Add-ToGroup
{
 [CmdletBinding()] 
 Param(  
 [Parameter(Mandatory=$True)] 
 [string]$Group,
 [Parameter(Mandatory=$True)] 
 [string]$Name
 )
 #This block returns the existing contents of the address group. that data must be modified to include the new address object created above and PUT back to the API
 #Write-Host "Get details of $group..."
 $GetUrl = "$Global:BaseUrl/api/v2/cmdb/firewall/addrgrp/$Group/?vdom=$VDOM"
 #Write-Host "Get URL: $getURL"

 $Header = @{
  'X-CSRFTOKEN' = $Global:Token
 }

 $WebSession = Get-Cookie $GetUrl
 $GetOutput = Invoke-WebRequest -Method GET -Uri $GetUrl -Headers $Header -ContentType 'application/json' -WebSession $WebSession -UseBasicParsing
 #Write-Output $GetOutput
 
 $Json = Get-Json $GetOutput
 
 #This is where i start modifying the member data. find the correct json node
 $MatchJson = $Json -match "`"member`".*?\]"
 $MatchOutput = $GetOutput -match "`"member`".*?\]"
 $Members = $matches[0]

 #Remove the close bracket, add new entry inside of JSON formatting
 $Members = $Members.TrimEnd("]")
 $Members = $Members + ", { `"name`" : `"$Name`" } ]"
 #Write-Output $Members
 
 $AddUrl = "${BaseUrl}/api/v2/cmdb/firewall/addrgrp"
 $Body = "{ `"vdom`" : `"$VDOM`", `"json`" : { $Members } }"

 #Write-Output "Adding $name to address group $group..."
 $AddOutput = Invoke-WebRequest -Method PUT -Uri "$AddUrl/$Group/?vdom=$VDOM" -Headers $Header -ContentType 'application/json' -WebSession $WebSession -Body $Body -UseBasicParsing
 #Write-Output "Add output: $AddOutput"

 If($AddOutput -match "`"http_status`":200"){
   Write-Output "Added $Name to Address Group $Group.`n"
 }
 Else{
   Throw "`nHTTP Error. Failed to add $Name to $Group.`n"
 }
}

#Function To Create WebSession Cookie
Function Get-Cookie 
{
 [CmdletBinding()] 
 Param(  
 [Parameter(Mandatory=$True)] 
 [string]$Url
 ) 
 [System.Uri]$Uri = $Url
 $Cookie = New-Object System.Net.Cookie
 $Cookie.Name = $Global:CookieName # Add the name of the cookie
 $Cookie.Value = $Global:CookieValue # Add the value of the cookie
 $Cookie.Domain = $Uri.DnsSafeHost
 $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
 $WebSession.Cookies.Add($Cookie)
 Return $WebSession
}

#Function To Create Json fro Invoke-Web Request
Function Get-Json
{
 [CmdletBinding()] 
 Param(  
 [Parameter(Mandatory=$True)] 
 [string]$Output
 )
 #split output on newlines into an array
 $NewOutput = $Output -split "`n"

 #size the array and set variables
 $y = $NewOutput.GetUpperBound(0)
 $x = 0
 $z = 0

 #iterate through array elements, find the beginning of the JSON, start adding elements from array to json variable
 DO {
    $String = $NewOutput[$x]
    if ($String -contains "{"){
        $z = 1
        }
    if ($z -eq 1){
        $Json = $Json + $String
        }
    $x++
 } While ($x -le $y)
 Return $Json
}

#Function to Log out of API
Function Log-Out
{
 $Logout = Invoke-WebRequest -Method POST -Uri "$Global:BaseUrl/logout" -UseBasicParsing
 #Write-Output "`nLog-Out Successfully From API"
}

#Function To Set Protocol
Function Set-Protocol
{
 # Forcing to use TLS1.2
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::"Tls12"

# Forcing to ignore ssl cert
add-type @"
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
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

#Function To Generate Token/Cookie
Function Create-Token
{
 # Create URL with the correct calling parameters

 $AuthUrl = "https://${FortiIP}:${Port}/logincheck"
 $Global:BaseUrl = "https://${FortiIP}:${Port}"

 # Echo the URL back to the SmartResponse Status viewer
 #Write-Host "AuthURL:: $authURL"

 # define POST parameters
 #$authParams = @{username=$username;secretkey=$pass}
 $AuthParams = "username=${UserName}&secretkey=${Password}"
 #Write-Host "POSTdata: $authParams"

 #make auth URL
 $NewUrl = "${AuthUrl}?${AuthParams}"
 #Write-Host "NewURL::: $newURL"

 #Header for Rest API to Get Token
 $Header = New-Object System.Collections.Hashtable
 $Header.Add("Content-type", "application/x-www-form-urlencoded")

 $Output = Invoke-WebRequest -Method POST -Uri $NewUrl -Headers $Header -UseBasicParsing
 $Output = $Output.RawContent
 #Write-Host $Output

 $FaultCookie = "APSCOOKIE_\d+=`"0%260`""
 #Test for HTTP response 200. If so, parse cookie and token from response
 if($Output -match "200 OK" -and !($Output -match $FaultCookie))
 {
  $Output = $Output -split ';'
  For($i=0;$i -le $Output.count;$i++) {
   if($Output[$i] -match 'Set-Cookie:'){
   $Cookie = $Output[$i]
   }
   elseif($Output[$i] -match 'ccsrftoken'){
   $Token = $Output[$i]
   }
  }
  $Cookie = $Cookie -split 'Set-Cookie:'
  $Cookie = $Cookie[1].trim(" ")
  $Cookie = $Cookie -split '='
  $Global:CookieName = $Cookie[0]
  $Global:CookieValue = $Cookie[1].Trim('"')
  #Write-Host "CookieName::: $Global:CookieName"
  #Write-Host "CookieValue::: $Global:CookieValue"
  $Global:Token = $Token -split '="'
  $Global:Token = $Global:Token[1].Trim('"')
  #Write-Host "Token:::: $Global:Token"
 }
 Else #if no 200 response, auth failed
 { 
  Throw "`nAuthentication Failure.`n"
 }
}

#Function Check If IP/Domain Already Exist in address
Function IPOrDomain-Exist
{
  $GetUrl = "$Global:BaseUrl/api/v2/cmdb/firewall/address/?vdom=$VDOM"
  #Write-Host "Get URL: $getURL"

  $DoNotCheck = 0
  
  $FilterObject = $Object
  
  If($ScriptName -match 'add-domain'){
    $filter = "fqdn=@${FilterObject}"
  } ElseIf($ScriptName -match 'add-ip'){
    $filter = "subnet=@${FilterObject}"
  } ElseIf($ScriptName -match 'add-ip' -and $Global:IPRange -eq 1){
    $filter = "subnet=@${Global:ObjectIP}"
  } Else {
    $DoNotCheck = 1
  }

  $Global:DomainFlag = 0
  $Global:IPFlag = 0

  If($DoNotCheck -eq 0) {
    $UrlWithFilter = "${GetUrl}&filter=${filter}"

  $Header = @{
  'X-CSRFTOKEN' = $Global:Token
  }

    $WebSession = Get-Cookie $GetUrl
    $Output = Invoke-WebRequest -Method GET -Uri $UrlWithFilter -Headers $Header -ContentType 'application/json' -WebSession $WebSession -UseBasicParsing
    $Json = Get-Json $Output
    $Results = ConvertFrom-Json $json | Select -Expand Results
        
    ForEach ($Result in $Results){
        If($Result.Type -match 'FQDN' -and $ScriptName -match 'add-domain' -and $Result.fqdn -match $Object){
            $Global:DomainFlag = 1
            $Global:DomainName = $Result.Name
        }
        Elseif($Result.Type -match 'ipmask' -and $ScriptName -match 'add-ip' -and($Result.subnet -match $Object)){
            $Global:IPFlag = 1
            $Global:IPName = $Result.Name
        }
        Elseif($Global:IPRange -eq 1 -and $Result.subnet -match $Global:ObjectIP){
            $Global:IPFlag = 1
            $Global:IPName = $Result.Name
        }
    }
  }
}



#Function Get Group Info
Function Get-GroupInfo
{
 [CmdletBinding()] 
 Param(  
 [Parameter(Mandatory=$True)] 
 [string]$Group,
 [Parameter(Mandatory=$True)] 
 [string]$VDOM
 ) 
 Group-Exist -Group $Group -VDOM $VDOM
 #$GetUrl = "$Global:BaseUrl/api/v2/cmdb/firewall/addrgrp/${Group}"
 $GetUrl = "$Global:BaseUrl/api/v2/cmdb/firewall/addrgrp/${Group}/?vdom=$VDOM"
 #$GetUrl = "$Global:BaseUrl/api/v2/cmdb/firewall/addrgrp/?vdom=logrhythm"
 #Write-Host "Get URL: $getURL"

 $Header = @{
 'X-CSRFTOKEN' = $Global:Token
 }

 $WebSession = Get-Cookie $GetUrl
 $Output = Invoke-WebRequest -Method GET -Uri $GetUrl -Headers $Header -ContentType 'application/json' -WebSession $WebSession -UseBasicParsing
 $Json = Get-Json $Output
 $Results = ConvertFrom-Json $Json | Select -Expand Results
 $Name = $Results | select -expand Member | Select Name
 Return $Name
}

#Function Get Group Info
Function Group-Exist
{
 [CmdletBinding()] 
 Param(  
 [Parameter(Mandatory=$True)] 
 [string]$Group,  
 [Parameter(Mandatory=$True)] 
 [string]$VDOM
 )
 $GetUrl = "$Global:BaseUrl/api/v2/cmdb/firewall/addrgrp/?vdom=${VDOM}&filter=name=@${Group}"
 #Write-Host "Get URL: $getURL"

 $Header = @{
 'X-CSRFTOKEN' = $Global:Token
 }

 $WebSession = Get-Cookie $GetUrl
 $Output = Invoke-WebRequest -Method GET -Uri $GetUrl -Headers $Header -ContentType 'application/json' -WebSession $WebSession -UseBasicParsing
 #$Output
 $Json = Get-Json $Output
 $Results = ConvertFrom-Json $Json | Select -Expand Results

 $GroupFlag = 0
 If([string]::IsNullOrEmpty($Results)){
  If($ScriptName -match 'Group-Info'){
  Write-Host "`nVDOM ($VDOM) doesn't contain any address group. `n" 
  Exit
  }
  Else{
  Throw "`nVDOM ($VDOM) doesn't contain any address group. `n" 
  }
 }
 Else{
  ForEach($Result in $Results){ 
   If($Result.Name -eq $Group){
   $GroupFlag = 1
   }
  }
  If($GroupFlag -eq 0){
   If($ScriptName -match 'Group-Info'){
   Write-Host "`nAddress Group ($Group) doesn't exist in VDOM $VDOM. `n"  
   Exit
   }
   Else{
   Throw "`nAddress Group ($Group) doesn't exist in VDOM $VDOM. `n" 
   }
  }
 }
}

#Function To make Subnet of IP e.g 10.2.2.2 to 10.2.2.0 if cidr /24
Function Subnet-IP
{
 $Split = $Object -split '/'
 $IP = $Split[0]
 $Subnet = $Split[1]
 If($Subnet -eq 32){
  Split-IP -IP $IP -Count 4
 }
 Elseif($Subnet -eq 24){
  Split-IP -IP $IP -Count 3 # 3 for IP octet
 }
 Elseif($Subnet -eq 16){
  Split-IP -IP $IP -Count 2 # 2 for IP octet
 }
 Elseif($Subnet -eq 8){
  Split-IP -IP $IP -Count 1 # 1 for IP octet
 }
 Else{
  Throw "`nCIDR used is unsupported.`nSupported CIDR are /32, /24, /16, /8.`n"
 }
}

#Function Split IP
Function Split-IP
{
 [CmdletBinding()] 
 Param(  
 [Parameter(Mandatory=$True)] 
 [string]$IP,  
 [Parameter(Mandatory=$True)] 
 [Int]$Count
 )
 $SplitIP = $IP -split '\.'
 For($i=3;$i -ge $Count;$i--){
 $SplitIP[$i] = 0
 }
 $Global:ObjectIP = $SplitIP -join '.'
 #Write-Host $Global:ObjectIP
}
#*******************************************

$IPRegex = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
$DomainRegex = "^([a-z0-9])(([a-z0-9-]{1,61})?[a-z0-9]{1})?(\.[a-z0-9](([a-z0-9-]{1,61})?[a-z0-9]{1})?)?(\.[a-zA-Z]{2,4})+$"
$GroupRegex = "^[A-Z0-9_.]+-[A-Z0-9]+$"
$IPRangeRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$"
Input-Validation
Set-Protocol
Create-Token
IPOrDomain-Exist

# SIG # Begin signature block
# MIIcdQYJKoZIhvcNAQcCoIIcZjCCHGICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbNy3TkVYx1qLTscAiZ+3TljP
# MGOgghebMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggTKMIIDsqADAgECAhBViB6z/D5o1kjT6hrnf9QuMA0GCSqGSIb3DQEBCwUAMH8x
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0G
# A1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMg
# Q2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENBMB4XDTIwMDQxNDAwMDAwMFoX
# DTIzMDQxNDIzNTk1OVowYjELMAkGA1UEBhMCVVMxETAPBgNVBAgMCENvbG9yYWRv
# MRAwDgYDVQQHDAdCb3VsZGVyMRYwFAYDVQQKDA1Mb2dSaHl0aG0gSW5jMRYwFAYD
# VQQDDA1Mb2dSaHl0aG0gSW5jMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEAq2AoyuyTVji156LUFle1UBIlQky+FeXn1qOtE0whQz9qRISsyXVrTP3W5K89
# RF03Vfx/imqpAc/KXKhmaQgwZ0pQx9Zk3w5ZyVtfYflFqCvLFJkMaxRAXfcP9Hbk
# 1UkwmTEcuDHZbHGRQNkjofmFptYaDkC6t4mgRyEDXFfphJl2L7RjunA+C0Mn9qfU
# mxDfWNEEM+0IDEuSNDuPZJ6EO2s1SZS0eZcTzmEmYG5tZoTW0TrPAFd9yKdIN8Lt
# RH0vjbo4Onxg48wtPFjkN3/8rfBzJ5Cxm1M2N6ilFsCZ9ytx3zm4sIoEdBQ71LaA
# Pw0zE8gd/6Wm9D/rm4gCh6tdCwIDAQABo4IBXTCCAVkwCQYDVR0TBAIwADAOBgNV
# HQ8BAf8EBAMCB4AwKwYDVR0fBCQwIjAgoB6gHIYaaHR0cDovL3N2LnN5bWNiLmNv
# bS9zdi5jcmwwYQYDVR0gBFowWDBWBgZngQwBBAEwTDAjBggrBgEFBQcCARYXaHR0
# cHM6Ly9kLnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGQwXaHR0cHM6Ly9kLnN5
# bWNiLmNvbS9ycGEwEwYDVR0lBAwwCgYIKwYBBQUHAwMwVwYIKwYBBQUHAQEESzBJ
# MB8GCCsGAQUFBzABhhNodHRwOi8vc3Yuc3ltY2QuY29tMCYGCCsGAQUFBzAChhpo
# dHRwOi8vc3Yuc3ltY2IuY29tL3N2LmNydDAfBgNVHSMEGDAWgBSWO1PweTOXr32D
# 7y4rzMq3hh5yZjAdBgNVHQ4EFgQUdzzocef0xrNDjUSyRPB36hEHkuQwDQYJKoZI
# hvcNAQELBQADggEBAFm1oAkg9sHa1cHLuIOJ70OjAE/DDkfly6RaegcjvxAwVjlR
# yPwY//WfrNr9L+o1dQ5sT7eeHjIE9uLuU9oO2Eyu3AzJEu3VK9bC4elb2DHRlzWO
# x3Cu/H4TqqjSMnZ76sWk1oqZrrETcSwi5yWNK/bIUR6kxfTR/kYd8BMHiwZZUEgr
# v3yuhuGYLW30fDnF5aWGFkuAW0C7/VwXgokDorfMpROqgsDl7BqWQsKYRc6ZFET2
# ZWoyIoR7WMfTGmMqItDUS4gqF6WYsNBPsbLrggedq3qdbU9jXwnEniO+rGIdppZ4
# bvtkqrGrbN/tdTdKev1k0/QtBQVgM1oz0OupKzswggTTMIIDu6ADAgECAhAY2tGe
# Jn3ou0ohWM3MaztKMA0GCSqGSIb3DQEBBQUAMIHKMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5l
# dHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1
# dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMgUHVi
# bGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTAeFw0wNjEx
# MDgwMDAwMDBaFw0zNjA3MTYyMzU5NTlaMIHKMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdv
# cmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhv
# cml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMgUHVibGlj
# IFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAK8kCAgpejWeYAyq50s7Ttx8vDxFHLsr4P4p
# AvlXCKNkhRUn9fGtyDGJXSLoKqqmQrOP+LlVt7G3S7P+j34HV+zvQ9tmYhVhz2AN
# pNje+ODDYgg9VBPrScpZVIUm5SuPG5/r9aGRwjNJ2ENjalJL0o/ocFFN0Ylpe8dw
# 9rPcEnTbe11LVtOWvxV3obD0oiXyrxySZxjl9AYE75C55ADk3Tq1Gf8CuvQ87uCL
# 6zeL7PTXrPL28D2v3XWRMxkdHEDLdCQZIZPZFP6sKlLHj9UESeSNY0eIPGmDy/5H
# vSt+T8WVrg6d1NFDwGdz4xQIfuU/n3O4MwrPXT80h5aK7lPoJRUCAwEAAaOBsjCB
# rzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjBtBggrBgEFBQcBDARh
# MF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAfMAcGBSsOAwIaBBSP5dMahqyNjmvD
# z4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52ZXJpc2lnbi5jb20vdnNsb2dvLmdp
# ZjAdBgNVHQ4EFgQUf9Nlp8Ld7LvwMAnzQzn6Aq8zMTMwDQYJKoZIhvcNAQEFBQAD
# ggEBAJMkSjBfYs/YGpgvPercmS29d/aleSI47MSnoHgSrWIORXBkxeeXZi2YCX5f
# r9bMKGXyAaoIGkfe+fl8kloIaSAN2T5tbjwNbtjmBpFAGLn4we3f20Gq4JYgyc1k
# FTiByZTuooQpCxNvjtsM3SUC26SLGUTSQXoFaUpYT2DKfoJqCwKqJRc5tdt/54Rl
# KpWKvYbeXoEWgy0QzN79qIIqbSgfDQvE5ecaJhnh9BFvELWV/OdCBTLbzp1RXii2
# noXTW++lfUVAco63DmsOBvszNUhxuJ0ni8RlXw2GdpxEevaVXPZdMggzpFS2GD9o
# XPJCSoU4VINf0egs8qwR1qjtY2owggVZMIIEQaADAgECAhA9eNf5dklgsmF99PAe
# yoYqMA0GCSqGSIb3DQEBCwUAMIHKMQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVy
# aVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4
# BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQg
# dXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMgUHVibGljIFByaW1h
# cnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTAeFw0xMzEyMTAwMDAwMDBa
# Fw0yMzEyMDkyMzU5NTlaMH8xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRl
# YyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEw
# MC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENB
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl4MeABavLLHSCMTXaJNR
# YB5x9uJHtNtYTSNiarS/WhtR96MNGHdou9g2qy8hUNqe8+dfJ04LwpfICXCTqdpc
# DU6kDZGgtOwUzpFyVC7Oo9tE6VIbP0E8ykrkqsDoOatTzCHQzM9/m+bCzFhqghXu
# PTbPHMWXBySO8Xu+MS09bty1mUKfS2GVXxxw7hd924vlYYl4x2gbrxF4GpiuxFVH
# U9mzMtahDkZAxZeSitFTp5lbhTVX0+qTYmEgCscwdyQRTWKDtrp7aIIx7mXK3/nV
# jbI13Iwrb2pyXGCEnPIMlF7AVlIASMzT+KV93i/XE+Q4qITVRrgThsIbnepaON2b
# 2wIDAQABo4IBgzCCAX8wLwYIKwYBBQUHAQEEIzAhMB8GCCsGAQUFBzABhhNodHRw
# Oi8vczIuc3ltY2IuY29tMBIGA1UdEwEB/wQIMAYBAf8CAQAwbAYDVR0gBGUwYzBh
# BgtghkgBhvhFAQcXAzBSMCYGCCsGAQUFBwIBFhpodHRwOi8vd3d3LnN5bWF1dGgu
# Y29tL2NwczAoBggrBgEFBQcCAjAcGhpodHRwOi8vd3d3LnN5bWF1dGguY29tL3Jw
# YTAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vczEuc3ltY2IuY29tL3BjYTMtZzUu
# Y3JsMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzAOBgNVHQ8BAf8EBAMC
# AQYwKQYDVR0RBCIwIKQeMBwxGjAYBgNVBAMTEVN5bWFudGVjUEtJLTEtNTY3MB0G
# A1UdDgQWBBSWO1PweTOXr32D7y4rzMq3hh5yZjAfBgNVHSMEGDAWgBR/02Wnwt3s
# u/AwCfNDOfoCrzMxMzANBgkqhkiG9w0BAQsFAAOCAQEAE4UaHmmpN/egvaSvfh1h
# U/6djF4MpnUeeBcj3f3sGgNVOftxlcdlWqeOMNJEWmHbcG/aIQXCLnO6SfHRk/5d
# yc1eA+CJnj90Htf3OIup1s+7NS8zWKiSVtHITTuC5nmEFvwosLFH8x2iPu6H2aZ/
# pFalP62ELinefLyoqqM9BAHqupOiDlAiKRdMh+Q6EV/WpCWJmwVrL7TJAUwnewus
# GQUioGAVP9rJ+01Mj/tyZ3f9J5THujUOiEn+jf0or0oSvQ2zlwXeRAwV+jYrA9zB
# UAHxoRFdFOXivSdLVL4rhF4PpsN0BQrvl8OJIrEfd/O9zUPU8UypP7WLhK9k8tAU
# ITGCBEQwggRAAgEBMIGTMH8xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRl
# YyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEw
# MC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENB
# AhBViB6z/D5o1kjT6hrnf9QuMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQow
# CKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcC
# AQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTTjHiqBTw1xVdC9Ir/
# XCw6fqeD4DANBgkqhkiG9w0BAQEFAASCAQCo8lBb3dT1MrLdeXnLneKWHTbn7kbk
# C73U1wHnDBkcz0QriAyVwE6TMuR9gsSNNDw4J48cs25x6+DpUHPZI1sd2OsuqOQ5
# nFl3vVsnAa41ZsATGwNiVT0bkLnW2bdkpjgU6Lw21JsJbiDqIWSKUHu6izuEp1FE
# GdHggPcKLT8Gnv9AZNdZNSAJzbZ+vZgDyulXiTnkmh0/uhb0qsXrp9qAyRmNpdUn
# b466dfWkLtTt17NWezsyzuh8ZZE58MEF/LYZTV3pduLvAcCnA1PNogg0J1rHlvwH
# uqJW1yKAurLO81ZqleXx5aqzCke7Ln0Ifj9+TZr8E+OAUHe2Gu/AK98AoYICCzCC
# AgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMCVVMxHTAbBgNV
# BAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBUaW1l
# IFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTYapgbGlAwCQYF
# Kw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkF
# MQ8XDTIwMTIwMzA5NTgxN1owIwYJKoZIhvcNAQkEMRYEFO6CSClltQGMP6d3z5Hj
# k7lq6skoMA0GCSqGSIb3DQEBAQUABIIBAJCx9qAwqdin+ebZL6vo0ST/o/FhYWWc
# QdnYEm9mIvQVPTTy4eI51qVmpNuUunzGdJ8hDxyUQqVE6e+JEp6MzFhxiSxbpag5
# MdZ/oAoRMPp32+ILBYrPNgf/wZ7rsiVQK+Z1RLniM7ivWTGFZbQlUL3dVdYCm7lR
# 8kxFcMa0ZMWwAzhZuWE6EmcZTnw4a2RtUneJJ7oNI9t0OnsrQWf8go+Ogat63r6r
# FAbfMqxhRPL7A22hS4Gj4T2P9blCH9pGylPNywQSbwoJYJOu1JgWDyKQdJKQoW8K
# +pl2Rks+/5h41jdGPdHg1yVxnTNKuPDbsCDrTDhwCqKRwQcyNX+kEAM=
# SIG # End signature block
