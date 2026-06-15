# Requires -Version 7.0
# 
# This Script is used to configure fixed parameters for a plugin so as they need not to be provided everytime while executing an action.
#
# Use Case -> 
# Configure Fixed parameters in a one time script run. For Ex API Key, Username, Password
# Store parameter values in encrypted form.
# 
# The following steps are performed:
#
# 1. Input Validations.
# 2. Creating a file to store parameter values.
# 3. Encrypting the parameter values.
# 4. Storing the parameter values in the file.
#
### ===============================================================================================#
### Change the Value of ConfigurationFilePath for each Plugin                              #########          
### Change the dictionary Key Values for use in the individual Plugin.                     #########
###                                                                                        #########
###                                                                                        #########
###================================================================================================#
# 
#==========================================#
# LogRhythm SmartResponse Plugin           #
# SmartResponse Configure File             #
# V2.0  --  Feb, 2022                      #
#==========================================#



[CmdletBinding()] 
Param( 
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()]
[string]$ClientID, 
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()]
[string]$ClientPassword,
[string]$ProxyUrl,
[string]$ProxyUname,
[string]$ProxyPasswd
)


$ErrorActionPreference = "Stop"
# Trap for an exception during the script
Trap [Exception]
{
    if($PSItem.ToString() -eq "ExecutionFailure")
	{
		exit 1
	}
	elseif($PSItem.ToString() -eq "ExecutionSuccess")
	{
		exit
	}
	else
	{
		write-error $("Trapped: $_")
		Write-Output "Aborting Operation."
		exit
	}
}


# Function to Check and Create SmartResponse Directory
function CreateSRPDirectory
{
	if (!(Test-Path -Path $ConfigurationDirectoryPath))
	{
		New-Item -ItemType "directory" -Path $ConfigurationDirectoryPath -Force | Out-null
	}
}


# Function to Check and Create SmartResponse Config File

function CheckConfigFile
{
	if (!(Test-Path -Path $ConfigurationFilePath))
	{
		New-Item -ItemType "file" -Path $ConfigurationFilePath -Force | Out-null
	}
}


#Function to validate Cisco Secure X Parameters
function ValidateInputs{
    $Url = "https://id.sophos.com/api/v2/oauth2/token"
    $Header = @{
            "Content-Type"= "application/x-www-form-urlencoded"
            "Accept"= "application/json"
    }

    $Body = @{
        "client_id"= $ClientID;
        "client_secret"= $ClientPassword;
        "grant_type"= "client_credentials";
        "scope"="token"
    }
    
    try
	{
        if($ProxyFlag -eq 0)
		{
            Write-Output "Proceeding without Proxy Credentials"
            $Output = Invoke-RestMethod -Uri $Url -Method Post -Headers $Header -Body $Body -ContentType "application/x-www-form-urlencoded"
        }
        elseif($ProxyFlag -eq 1)
        {
            Write-Output "Proceeding without Proxy Credentials."
            $Output = Invoke-RestMethod -Uri $Url -Method Post -Headers $Header -Body $Body -ContentType "application/x-www-form-urlencoded" -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            Write-Output "Proceeding with provided Proxy Credentials"
            $Output = Invoke-RestMethod -Uri $Url -Method Post -Headers $Header -Body $Body -ContentType "application/x-www-form-urlencoded" -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }
		
        $Token = $Output.access_token   
    }
	catch
	{
        $ExceptionMessage = $_.Exception.Message
		if($ExceptionMessage -like "*established connection failed because connected host has failed to respond*"){
			write-output "Please check if the proxy server(if used) is reachable or not."
			write-output "Error: Invalid Proxy details."
			write-error $ExceptionMessage
			throw "ExecutionFailure"
		}
		elseif($ExceptionMessage -eq "Response status code does not indicate success: 407 (Proxy Authentication Required)."){
			write-output "Invalid Input: Invalid Proxy server credentials."
			write-error $ExceptionMessage
			throw "ExecutionFailure"
		}
		elseif ($ExceptionMessage -eq "The remote server returned an error: (401) Unauthorized." -or $ExceptionMessage -eq "Response status code does not indicate success: 401 (UNAUTHORIZED)."){
			Write-Output "Invalid Sophos Central Client Id/ Client Password"\
			write-error $ExceptionMessage
			throw "ExecutionFailure" 
		}
		elseif($ExceptionMessage -eq "This operation is not supported for a relative URI."){
			write-output "Invalid Proxy url."
			write-error $ExceptionMessage
			throw "ExecutionFailure"
		}
		elseif($ExceptionMessage -like "The proxy tunnel request*"){
			write-Output "Please check the Configuration/Proxy parameters and try again"
			write-error $ExceptionMessage
			throw "ExecutionFailure"
		}
        else{
            Write-Output "Validations Failed."
			write-error $ExceptionMessage
            throw "ExecutionFailure"
        }
	}   

    $RegionUrl = "https://api.central.sophos.com/whoami/v1"
    $RegionHeader = @{
            "authorization"= "Bearer $Token"
            "Accept"= "application/json"
    }

    try
	{
        if($ProxyFlag -eq 0)
		{
            $Details = Invoke-RestMethod -Uri $RegionUrl -Method Get -Headers $RegionHeader
        }
        elseif($ProxyFlag -eq 1)
        {
            $Details = Invoke-RestMethod -Uri $RegionUrl -Method Get -Headers $RegionHeader -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            $Details = Invoke-RestMethod -Uri $RegionUrl -Method Get -Headers $RegionHeader -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }
			
        $global:TentantID = $Details.id
        $global:BaseURL = $Details.apiHosts.dataRegion          
    }
	catch
	{
        $ExceptionMessage = $_.Exception.Message      
        Write-Output $ExceptionMessage
        Exit 
	}  
    
}


# Function to encrypt the values
function CreateHashtable
{
	$HashTable = [PSCustomObject]@{ 
								"ClientID" = $SecureClientID
								"ClientPassword" = $SecureClientPassword
                                "TenantID" = $SecureTenantID
                                "BaseURL" = $SecureBaseURL
                                "ProxyUrl" = $SecureProxyUrl
                                "ProxyUname" = $SecureProxyUname
                                "ProxyPasswd" = $SecureProxyPasswd
                                "ProxyFlag" = $SecureProxyFlag
						}
	return $HashTable					
}

# Function to Create Hashtable for the parameters
function CreateConfigFile
{
	CreateHashtable | Export-Clixml -Path $ConfigurationFilePath
	Write-Output "Validations Passed."
	Write-Output "Configuration Parameters saved for Sophos Central V2."
}


$ConfigurationDirectoryPath = "C:\Program Files\LogRhythm\SmartResponse Plugins"
$ConfigurationFilePath = "C:\Program Files\LogRhythm\SmartResponse Plugins\SophosConfigFileV2.xml"

$ClientID = $ClientID.trim()
$ClientPassword = $ClientPassword.trim()


CreateSRPDirectory
CheckConfigFile

$ProxyFlag = 0
if($ProxyUrl -ne "" -and $ProxyUrl -ne $null)
{
    $ProxyUrl = $ProxyUrl.Trim()
    $ProxyFlag = 1
}
else{
    $ProxyUrl = "None"
}

if($ProxyUname -ne "" -and $ProxyUname -ne $null)
{
    $ProxyUname = $ProxyUname.Trim()
    if($ProxyPasswd -ne "" -and $ProxyPasswd -ne $null)
    {
        $ProxyPasswd = $ProxyPasswd.Trim()
        $ProxyFlag = 2
        $SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ProxyUname, $SecureProxyPasswd
    }
    else{
        Write-Output "Please Provide both Username and Password to Continue"
        $ProxyPasswd = "None"
		throw "ExecutionFailure"
    }
}
else{
    $ProxyUname = "None"
    $ProxyPasswd = "None"
}

ValidateInputs

$SecureClientID = $ClientID | ConvertTo-SecureString -AsPlainText -Force
$SecureClientPassword = $ClientPassword | ConvertTo-SecureString -AsPlainText -Force
$SecureTenantID = $global:TentantID | ConvertTo-SecureString -AsPlainText -Force
$SecureBaseURL = $global:BaseURL | ConvertTo-SecureString -AsPlainText -Force
$SecureProxyFlag = $ProxyFlag | ConvertTo-SecureString -AsPlainText -Force
$SecureProxyUrl = $ProxyUrl | ConvertTo-SecureString -AsPlainText -Force
$SecureProxyUname = $ProxyUname | ConvertTo-SecureString -AsPlainText -Force
$SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force

CreateConfigFile

# SIG # Begin signature block
# MIIRzQYJKoZIhvcNAQcCoIIRvjCCEboCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpqUiK55NepIEIl5+m3MvpGUz
# F4Kggg8CMIIEyjCCA7KgAwIBAgIQVYges/w+aNZI0+oa53/ULjANBgkqhkiG9w0B
# AQsFADB/MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xHzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxMDAuBgNVBAMTJ1N5
# bWFudGVjIENsYXNzIDMgU0hBMjU2IENvZGUgU2lnbmluZyBDQTAeFw0yMDA0MTQw
# MDAwMDBaFw0yMzA0MTQyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMREwDwYDVQQIDAhD
# b2xvcmFkbzEQMA4GA1UEBwwHQm91bGRlcjEWMBQGA1UECgwNTG9nUmh5dGhtIElu
# YzEWMBQGA1UEAwwNTG9nUmh5dGhtIEluYzCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAKtgKMrsk1Y4teei1BZXtVASJUJMvhXl59ajrRNMIUM/akSErMl1
# a0z91uSvPURdN1X8f4pqqQHPylyoZmkIMGdKUMfWZN8OWclbX2H5RagryxSZDGsU
# QF33D/R25NVJMJkxHLgx2WxxkUDZI6H5habWGg5AureJoEchA1xX6YSZdi+0Y7pw
# PgtDJ/an1JsQ31jRBDPtCAxLkjQ7j2SehDtrNUmUtHmXE85hJmBubWaE1tE6zwBX
# fcinSDfC7UR9L426ODp8YOPMLTxY5Dd//K3wcyeQsZtTNjeopRbAmfcrcd85uLCK
# BHQUO9S2gD8NMxPIHf+lpvQ/65uIAoerXQsCAwEAAaOCAV0wggFZMAkGA1UdEwQC
# MAAwDgYDVR0PAQH/BAQDAgeAMCsGA1UdHwQkMCIwIKAeoByGGmh0dHA6Ly9zdi5z
# eW1jYi5jb20vc3YuY3JsMGEGA1UdIARaMFgwVgYGZ4EMAQQBMEwwIwYIKwYBBQUH
# AgEWF2h0dHBzOi8vZC5zeW1jYi5jb20vY3BzMCUGCCsGAQUFBwICMBkMF2h0dHBz
# Oi8vZC5zeW1jYi5jb20vcnBhMBMGA1UdJQQMMAoGCCsGAQUFBwMDMFcGCCsGAQUF
# BwEBBEswSTAfBggrBgEFBQcwAYYTaHR0cDovL3N2LnN5bWNkLmNvbTAmBggrBgEF
# BQcwAoYaaHR0cDovL3N2LnN5bWNiLmNvbS9zdi5jcnQwHwYDVR0jBBgwFoAUljtT
# 8Hkzl699g+8uK8zKt4YecmYwHQYDVR0OBBYEFHc86HHn9MazQ41EskTwd+oRB5Lk
# MA0GCSqGSIb3DQEBCwUAA4IBAQBZtaAJIPbB2tXBy7iDie9DowBPww5H5cukWnoH
# I78QMFY5Ucj8GP/1n6za/S/qNXUObE+3nh4yBPbi7lPaDthMrtwMyRLt1SvWwuHp
# W9gx0Zc1jsdwrvx+E6qo0jJ2e+rFpNaKma6xE3EsIucljSv2yFEepMX00f5GHfAT
# B4sGWVBIK798robhmC1t9Hw5xeWlhhZLgFtAu/1cF4KJA6K3zKUTqoLA5ewalkLC
# mEXOmRRE9mVqMiKEe1jH0xpjKiLQ1EuIKhelmLDQT7Gy64IHnat6nW1PY18JxJ4j
# vqxiHaaWeG77ZKqxq2zf7XU3Snr9ZNP0LQUFYDNaM9DrqSs7MIIE0zCCA7ugAwIB
# AgIQGNrRniZ96LtKIVjNzGs7SjANBgkqhkiG9w0BAQUFADCByjELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZWZXJpU2lnbiBU
# cnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2lnbiwgSW5jLiAt
# IEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJpU2lnbiBDbGFz
# cyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzUw
# HhcNMDYxMTA4MDAwMDAwWhcNMzYwNzE2MjM1OTU5WjCByjELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZWZXJpU2lnbiBUcnVz
# dCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2lnbiwgSW5jLiAtIEZv
# ciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJpU2lnbiBDbGFzcyAz
# IFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzUwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvJAgIKXo1nmAMqudLO07cfLw8
# RRy7K+D+KQL5VwijZIUVJ/XxrcgxiV0i6CqqpkKzj/i5Vbext0uz/o9+B1fs70Pb
# ZmIVYc9gDaTY3vjgw2IIPVQT60nKWVSFJuUrjxuf6/WhkcIzSdhDY2pSS9KP6HBR
# TdGJaXvHcPaz3BJ023tdS1bTlr8Vd6Gw9KIl8q8ckmcY5fQGBO+QueQA5N06tRn/
# Arr0PO7gi+s3i+z016zy9vA9r911kTMZHRxAy3QkGSGT2RT+rCpSx4/VBEnkjWNH
# iDxpg8v+R70rfk/Fla4OndTRQ8Bnc+MUCH7lP59zuDMKz10/NIeWiu5T6CUVAgMB
# AAGjgbIwga8wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwbQYIKwYB
# BQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2UvZ2lmMCEwHzAHBgUrDgMCGgQUj+XT
# GoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDovL2xvZ28udmVyaXNpZ24uY29tL3Zz
# bG9nby5naWYwHQYDVR0OBBYEFH/TZafC3ey78DAJ80M5+gKvMzEzMA0GCSqGSIb3
# DQEBBQUAA4IBAQCTJEowX2LP2BqYLz3q3JktvXf2pXkiOOzEp6B4Eq1iDkVwZMXn
# l2YtmAl+X6/WzChl8gGqCBpH3vn5fJJaCGkgDdk+bW48DW7Y5gaRQBi5+MHt39tB
# quCWIMnNZBU4gcmU7qKEKQsTb47bDN0lAtukixlE0kF6BWlKWE9gyn6CagsCqiUX
# ObXbf+eEZSqVir2G3l6BFoMtEMze/aiCKm0oHw0LxOXnGiYZ4fQRbxC1lfznQgUy
# 286dUV4otp6F01vvpX1FQHKOtw5rDgb7MzVIcbidJ4vEZV8NhnacRHr2lVz2XTII
# M6RUthg/aFzyQkqFOFSDX9HoLPKsEdao7WNqMIIFWTCCBEGgAwIBAgIQPXjX+XZJ
# YLJhffTwHsqGKjANBgkqhkiG9w0BAQsFADCByjELMAkGA1UEBhMCVVMxFzAVBgNV
# BAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZWZXJpU2lnbiBUcnVzdCBOZXR3
# b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2lnbiwgSW5jLiAtIEZvciBhdXRo
# b3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJpU2lnbiBDbGFzcyAzIFB1Ymxp
# YyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzUwHhcNMTMxMjEw
# MDAwMDAwWhcNMjMxMjA5MjM1OTU5WjB/MQswCQYDVQQGEwJVUzEdMBsGA1UEChMU
# U3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5l
# dHdvcmsxMDAuBgNVBAMTJ1N5bWFudGVjIENsYXNzIDMgU0hBMjU2IENvZGUgU2ln
# bmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJeDHgAWryyx
# 0gjE12iTUWAecfbiR7TbWE0jYmq0v1obUfejDRh3aLvYNqsvIVDanvPnXydOC8KX
# yAlwk6naXA1OpA2RoLTsFM6RclQuzqPbROlSGz9BPMpK5KrA6DmrU8wh0MzPf5vm
# wsxYaoIV7j02zxzFlwckjvF7vjEtPW7ctZlCn0thlV8ccO4XfduL5WGJeMdoG68R
# eBqYrsRVR1PZszLWoQ5GQMWXkorRU6eZW4U1V9Pqk2JhIArHMHckEU1ig7a6e2iC
# Me5lyt/51Y2yNdyMK29qclxghJzyDJRewFZSAEjM0/ilfd4v1xPkOKiE1Ua4E4bC
# G53qWjjdm9sCAwEAAaOCAYMwggF/MC8GCCsGAQUFBwEBBCMwITAfBggrBgEFBQcw
# AYYTaHR0cDovL3MyLnN5bWNiLmNvbTASBgNVHRMBAf8ECDAGAQH/AgEAMGwGA1Ud
# IARlMGMwYQYLYIZIAYb4RQEHFwMwUjAmBggrBgEFBQcCARYaaHR0cDovL3d3dy5z
# eW1hdXRoLmNvbS9jcHMwKAYIKwYBBQUHAgIwHBoaaHR0cDovL3d3dy5zeW1hdXRo
# LmNvbS9ycGEwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDovL3MxLnN5bWNiLmNvbS9w
# Y2EzLWc1LmNybDAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYBBQUHAwMwDgYDVR0P
# AQH/BAQDAgEGMCkGA1UdEQQiMCCkHjAcMRowGAYDVQQDExFTeW1hbnRlY1BLSS0x
# LTU2NzAdBgNVHQ4EFgQUljtT8Hkzl699g+8uK8zKt4YecmYwHwYDVR0jBBgwFoAU
# f9Nlp8Ld7LvwMAnzQzn6Aq8zMTMwDQYJKoZIhvcNAQELBQADggEBABOFGh5pqTf3
# oL2kr34dYVP+nYxeDKZ1HngXI9397BoDVTn7cZXHZVqnjjDSRFph23Bv2iEFwi5z
# uknx0ZP+XcnNXgPgiZ4/dB7X9ziLqdbPuzUvM1ioklbRyE07guZ5hBb8KLCxR/Md
# oj7uh9mmf6RWpT+thC4p3ny8qKqjPQQB6rqTog5QIikXTIfkOhFf1qQliZsFay+0
# yQFMJ3sLrBkFIqBgFT/ayftNTI/7cmd3/SeUx7o1DohJ/o39KK9KEr0Ns5cF3kQM
# Ffo2KwPcwVAB8aERXRTl4r0nS1S+K4ReD6bDdAUK75fDiSKxH3fzvc1D1PFMqT+1
# i4SvZPLQFCExggI1MIICMQIBATCBkzB/MQswCQYDVQQGEwJVUzEdMBsGA1UEChMU
# U3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5l
# dHdvcmsxMDAuBgNVBAMTJ1N5bWFudGVjIENsYXNzIDMgU0hBMjU2IENvZGUgU2ln
# bmluZyBDQQIQVYges/w+aNZI0+oa53/ULjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU4yNO4zgl
# SLqSo2TewkpPnYUyo7AwDQYJKoZIhvcNAQEBBQAEggEAVhoMPd1SG3XYb75t8pJC
# vLEy8RkRZXunhK6caU9aboDWC6+lJKwHLy8iHsRVvL/yJ5rbyh/h5KBkG8L6laSc
# iicFWGOL3/gzxsGxYg5ag5nLRSHq7DG+WM0aXC6DJfuIsHVC9AZFwHeMjbCw1t++
# 3CoDebrNypdNXCnj6ef6KBaMorKVqnQv8LrLSNOVBA6RuOeno6jNGNdfbGksHeX6
# 3iSERnxqgRpzUnRABrEjRCyJGCNBkO3VMqayiKDbvq305+QhhCC86chlEwiTE9EY
# Ing1zhoiEj/6kEhVSU4ZuxV6yDT5EmNiGsKu+3DbRCjqTHw+zaWjgU+xv6kn1ysA
# mw==
# SIG # End signature block
