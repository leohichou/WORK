# Requires -Version 3.0
# This script is used to add FQDN to group
#
# The following steps are performed:
#
# 1. Check If group exists or not
# 2. Add FQDN to group
#
#==========================================#
# LogRhythm SmartResponse Plugin           #
# PAN Firewall V2 - SmartResponse          #
# Sakshi.rawal@logrhythm.com               #
# v2  --  May, 2021                        #
#==========================================#

#==========================================#
# LogRhythm SmartResponse Plugin           #
# PAN Firewall V2 - SmartResponse          #
# v3  --  Jan, 2022                        #
#==========================================#

[CmdletBinding()]
Param(
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()]
[string]$FQDN,
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()]
[string]$GroupName
)

$ErrorActionPreference = "Stop"
# Trap for an exception during the scrFQDNt
<#Trap [Exception]
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
}#>

#Fuction to check if entered Group Exists
Function CheckIfGroupExists {
    $GroupUrl = "$PANFirewallHost"+"/restapi/$PANVersion/Objects/AddressGroups?location=vsys&vsys=$Vsys"
    Try {

        if($ProxyFlag -eq 0)
		{
		    $Output = Invoke-RestMethod -Uri $GroupUrl -Method Get -Headers $Header -SkipCertificateCheck
        }
        elseif($ProxyFlag -eq 1)
        {
            $Output = Invoke-RestMethod -Uri $GroupUrl -Method Get -Headers $Header -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            $SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ProxyUname, $SecureProxyPasswd
            $Output = Invoke-RestMethod -Uri $GroupUrl -Method Get -Headers $Header -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }

        $Groups = $Output.result.entry
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Output $ErrorMessage
		exit 1
    }

    $flag = 0
    $Name = "@name"
    foreach($Group in $Groups){
        if($Group.$Name -ceq $GroupName){
            $AlreadyAddedMembers = $Group.static.member
            $flag = 1
            break
        }
    }

    if($flag -eq 0){
        Write-Output "No Group exists with name $GroupName"
        exit 1
    }

    return $AlreadyAddedMembers
}

#Fuction to create FQDN Object
Function CreateFQDNObject {
    $FQDNObjectUrl = "$PANFirewallHost"+"/restapi/$PANVersion/Objects/Addresses?location=vsys&vsys=$Vsys&name=$FQDN"
    $Body = @{
        "entry"= @{
            "fqdn"= $FQDN
            "@name"=  $FQDN
         }
    }
    $Body = $Body | ConvertTo-Json
    Try {
        if($ProxyFlag -eq 0)
		{
		    $FQDNObject = Invoke-RestMethod -Uri $FQDNObjectUrl -Method Post -Headers $Header -Body $Body -SkipCertificateCheck
        }
        elseif($ProxyFlag -eq 1)
        {
            $FQDNObject = Invoke-RestMethod -Uri $FQDNObjectUrl -Method Post -Headers $Header -Body $Body -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            $SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ProxyUname, $SecureProxyPasswd
            $FQDNObject = Invoke-RestMethod -Uri $FQDNObjectUrl -Method Post -Headers $Header -Body $Body -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }

    }
    catch {
		$ErrorMessage = $_.Exception.Message
        if($ErrorMessage -eq "Response status code does not indicate success: 400 (Bad Request)."){
            Write-Output "Invalid FQDN $FQDN entered"
        }else{
            Write-Output $ErrorMessage
        }
        exit 1
    }
}

#Fuction to check if FQDN Object Exists
Function CheckIfFQDNObjectExists {
    $GroupUrl = "$PANFirewallHost"+"/restapi/$PANVersion/Objects/Addresses?location=vsys&vsys=$Vsys"
    Try {
        if($ProxyFlag -eq 0)
		{
		    $Output = Invoke-RestMethod -Uri $GroupUrl -Method Get -Headers $Header -SkipCertificateCheck
        }
        elseif($ProxyFlag -eq 1)
        {
            $Output = Invoke-RestMethod -Uri $GroupUrl -Method Get -Headers $Header -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            $SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ProxyUname, $SecureProxyPasswd
            $Output = Invoke-RestMethod -Uri $GroupUrl -Method Get -Headers $Header -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }

        $FQDNs = $Output.result.entry
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Output $ErrorMessage
		exit 1
    }

    $flag = 0
    $Name = "@name"
    foreach($FQDNValue in $FQDNs){
        if($FQDNValue.fqdn -eq $FQDN){
            $FQDNName = $FQDNValue.$Name
            $flag = 1
            break
        }
    }

    if($flag -eq 0){
        CreateFQDNObject
        $FQDNName = $FQDN
    }

    return $FQDNName
}



#Fuction to add FQDN to group
Function AddFQDNToGroup {
    $FQDNObjectAddUrl = "$PANFirewallHost"+"/restapi/$PANVersion/Objects/AddressGroups?location=vsys&vsys=$Vsys&name=$GroupName"
    $FQDNArray = @()
    $FQDNArray+= $AlreadyAddedMembers
    $FQDNArray+= $FQDNName
    $Member= @{
            "member"= @($FQDNArray)
        }

    $Body = @{
        "entry"= @{
            "static"= $Member
            "@name" = $GroupName
        }
    }
    $Body = $Body | ConvertTo-Json -Depth 4
    Try {
        if($ProxyFlag -eq 0)
		{
		    $FQDNObject = Invoke-RestMethod -Uri $FQDNObjectAddUrl -Method Put -Headers $Header -Body $Body -SkipCertificateCheck
        }
        elseif($ProxyFlag -eq 1)
        {
            $FQDNObject = Invoke-RestMethod -Uri $FQDNObjectAddUrl -Method Put -Headers $Header -Body $Body -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            $SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ProxyUname, $SecureProxyPasswd
            $FQDNObject = Invoke-RestMethod -Uri $FQDNObjectAddUrl -Method Put -Headers $Header -Body $Body -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }

        Write-Output "FQDN $FQDN successfully added to Group $GroupName"
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        if($ErrorMessage -eq "Response status code does not indicate success: 409 (Conflict)."){
            Write-Output "FQDN $FQDN is already added in Group $GroupName"
	        throw "ExecutionSuccess"
        }else{
            Write-Output $ErrorMessage
            $_
	    throw "ExecutionFailure"
        }
    }
}

Function CommitChanges {
    $Uri = "$PANFirewallHost"+"/api/?key=apikey&type=commit&cmd=<commit></commit>"
    Try {
        if($ProxyFlag -eq 0)
		{
		    $UriReturn = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Header  -SkipCertificateCheck
        }
        elseif($ProxyFlag -eq 1)
        {
            $UriReturn = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Header -SkipCertificateCheck -Proxy $ProxyUrl
        }
        else{
            $SecureProxyPasswd = $ProxyPasswd | ConvertTo-SecureString -AsPlainText -Force
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ProxyUname, $SecureProxyPasswd
            $UriReturn = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Header  -SkipCertificateCheck -Proxy $ProxyUrl -ProxyCredential $cred
        }
        if($UriReturn.response.result.job){
            Write-Output "Commit initiated for the changes. Please check the progress in Dashboard. Job ID: $($UriReturn.response.result.job)"
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Output $ErrorMessage
        Write-Error "Error in Commiting the changes!"
	    throw "ExecutionFailure"
    }
}

. .\FetchConfig.ps1

$Key = $ConfigItems.Key
$PANFirewallHost = $ConfigItems.PANFirewallIP
$Vsys = $ConfigItems.VirtualSystem
$PANVersion = $ConfigItems.PANVersion

$FQDN = $FQDN.Trim()
$GroupName = $GroupName.Trim()
$ProxyFlag = $ConfigItems.ProxyFlag
$ProxyUrl = $ConfigItems.ProxyUrl
$ProxyUname = $ConfigItems.ProxyUname
$ProxyPasswd = $ConfigItems.ProxyPasswd
$Header= @{
		"X-PAN-KEY" = $Key
        "Content-Type" = "application/json"
        "Accept" = "application/json"
}

#Function call

$AlreadyAddedMembers = CheckIfGroupExists
$FQDNName = CheckIfFQDNObjectExists

AddFQDNToGroup
CommitChanges


# SIG # Begin signature block
# MIIRzQYJKoZIhvcNAQcCoIIRvjCCEboCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCO8QwRaRXkHdsBA8nWGbw5+E
# JOmggg8CMIIEyjCCA7KgAwIBAgIQVYges/w+aNZI0+oa53/ULjANBgkqhkiG9w0B
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU+MPYq/4r
# eVe8knhbGnAjV0Uw+OUwDQYJKoZIhvcNAQEBBQAEggEAKRWWbrWdO7oJJcKcDIFk
# 5Qe1bgo8ttaK1f3DNXLudW+cf70IKuwHCaj0jLSieATuGpRjhh0eAcmPX8/y+7gl
# AsxeNWm1m2NWeUweMUSdve029ncJQf153hXKt3HXC+PU5YIfI9HuqQEyTn/FLpx/
# tj3MY0Lda/Tgz3yiPESvzqNfBdDbIsEhD9U/YdQ7hGnry/CIi1NkgpoBndVqukCa
# YKixQyM8rX/6y8Ol5lnL2i2btKixd9kRAX8WHq/GoMlO7ECcHijXACqTLIYDApOQ
# U/Wzr1oKAovQfmoDhDOqljgyAgkAGnr0QdX4GOXUQNCrPPZkV124WGPassLvXyRz
# 1A==
# SIG # End signature block
