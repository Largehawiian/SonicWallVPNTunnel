# Enable / Disable VPN for remote backup processing
function Set-VPNTunnel {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    param (
        [Parameter (Mandatory = $True,
        ParameterSetName = 'Enable')]
        [switch]$Enable,
        

        [Parameter (Mandatory = $True,
        ParameterSetName = 'Disable')]
        [switch]$Disable,
        
        [Parameter (Mandatory = $True)]
        [string]$VPN_Name
        
    )
    begin {
        $Script:ConnectionString = [ConnectionString]::New()
        $Script:TFA = [PSCustomObject]@{
            user     = $Script:ConnectionString.User
            password = $Script:ConnectionString.Pass
            tfa      = $Script:ConnectionString.TFA
            override = "true"
        } | ConvertTo-Json
        $Script:Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Script:Headers.Add("Content-Type", "application/json")
        $Script:Response = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/tfa" -Method 'POST' -Headers $Script:Headers -Body $Script:TFA -SkipCertificateCheck 
        $Script:Token = $Script:Response.replace("INFO: Success. BearToken:", "Bearer")
        $Script:Token = $Script:Token -replace "`n", "" -replace "`r", ""
        $Script:Headers = $null
        $Script:Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Script:Headers.Add("Authorization", $Script:Token)
    }
    process {
        if ($Enable) {
           
            $Script:Body = @{
                vpn = @{
                    policy = @(@{
                            ipv4 = @{
                                site_to_site = @{
                                    name   = $VPN_Name
                                    enable = $true
                                }
                            }
                        }
                        
                    )
                }
            } | Convertto-json -Depth 5
            $Script:VPNResult = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/vpn/policies/ipv4/site-to-site/name/$($VPN_Name)" -Method 'PUT' -Headers $Script:Headers -Body $Script:Body -SkipCertificateCheck -ContentType 'application/json'
            Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/config/pending" -Method 'POST' -Headers $Script:Headers  -SkipCertificateCheck -ContentType 'application/json' | Out-Null
            $Script:VPNStatus = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/vpn/policies/ipv4/site-to-site/name/$($VPN_Name)" -Method 'GET' -Headers $Script:Headers -SkipCertificateCheck -ContentType 'application/json'
            Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/auth" -Method 'DEL' -Headers $Script:Headers -Body "" -SkipCertificateCheck | Out-Null
            if ($Script:VPNStatus.vpn.policy.ipv4.site_to_site.enable -eq "true"){
                New-DrmmEventLog -LogName $Global:Logname -EventSource $Global:EventSource
                [System.Diagnostics.EventLog]::WriteEntry($Global:EventSource, "VPN Tunnel $($VPN_Name) was Enabled", "Information", "100")
            }
        }
        if ($Disable) {
            $Script:Body = @{
                vpn = @{
                    policy = @(@{
                            ipv4 = @{
                                site_to_site = @{
                                    name   = $VPN_Name
                                    enable = $false
                                }
                            }
                        }
                        
                    )
                }
            } | Convertto-json -Depth 5

            $Script:VPNResult = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/vpn/policies/ipv4/site-to-site/name/$($VPN_Name)" -Method 'PUT' -Headers $Script:Headers -Body $Script:Body -SkipCertificateCheck
            Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/config/pending" -Method 'POSt' -Headers $Script:Headers  -SkipCertificateCheck -ContentType 'application/json' | Out-Null
            $Script:VPNStatus = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/vpn/policies/ipv4/site-to-site/name/$($VPN_Name)" -Method 'GET' -Headers $Script:Headers -SkipCertificateCheck -ContentType 'application/json'
            Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/auth" -Method 'DEL' -Headers $Script:Headers -Body "" -SkipCertificateCheck | Out-Null
            if ($Script:VPNStatus.vpn.policy.ipv4.site_to_site.enable -eq $false){
                New-DrmmEventLog -LogName $Global:Logname -EventSource $Global:EventSource
                [System.Diagnostics.EventLog]::WriteEntry($Global:EventSource, "VPN Tunnel $($VPN_Name) was Disabled", "Information", "101")
            }

        }
        $Script:Headers = $null
        $Script:TFA = $null
        $Script:Token = $null
        $Script:ConnectionString = $null
        $Script:Return = [PSCustomObject]@{
            Success   = $Script:VPNResult.status.success
            VPNStatus = switch ($Script:VPNStatus.vpn.policy.ipv4.site_to_site.enable) {
                true { "Enabled" }
                false { "Disabled" }
                
            }
        }

        return $Script:Return
    }
}
function New-DrmmEventLog {
    param (
        [Parameter(Mandatory = $true)][string]$LogName,
        [Parameter(Mandatory = $true)][string]$EventSource
    )
    process {
        if ([System.Diagnostics.EventLog]::Exists($LogName) -and [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
           # Write-Host "EventLog:$LogName & Source:$EventSource Exist Already" -ForegroundColor Green
        }
        else {
            try {
                [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $LogName)
            }
            catch {
                $EventLogStatus = $_.Exeception
            } 
        }
    } end {
        if ($EventLogStatus) {
            return $EventLogErrorMessage
        }
        else {
            return "Sucessfully Created EventLog $LogName | EventSource $EventSource"
        }
    }
}

