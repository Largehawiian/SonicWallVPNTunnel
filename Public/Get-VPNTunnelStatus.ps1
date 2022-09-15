function Get-VPNTunnelStatus {
    param (
        [Parameter(Mandatory = $true)][string]$VPN_Name
    )
    begin {
        $Script:ConnectionString = [ConnectionString]::New()
        $Script:TFA = [PSCustomObject]@{
            user     = $Script:ConnectionString.User
            password = $Script:ConnectionString.Pass
            tfa      = $Script:ConnectionString.TFA
            override = "true"
        } | ConvertTo-Json
        $Script:Response = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/tfa" -Method 'POST' -Headers $Script:Headers -Body $Script:TFA -SkipCertificateCheck -ContentType "application/json"
        $Script:Token = $Script:Response.replace("INFO: Success. BearToken:", "Bearer")
        $Script:Token = $Script:Token -replace "`n", "" -replace "`r", ""
        $Script:Headers = $null
        $Script:Headers =@{
            "Authorization" = $Script:Token
        }
    }
    process {
        $Script:VPNStatus = Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/vpn/policies/ipv4/site-to-site/name/$($VPN_Name)" -Method 'GET' -Headers $Script:Headers -SkipCertificateCheck -ContentType 'application/json'
        Invoke-RestMethod "https://$($Script:ConnectionString.IP):2020/api/sonicos/auth" -Method 'DEL' -Headers $Script:Headers -Body "" -SkipCertificateCheck | Out-Null

        $Script:Headers = $null
        $Script:TFA = $null
        $Script:Token = $null
        $Script:ConnectionString = $null
        $Script:Return = [PSCustomObject]@{
            VPNStatus = switch ($Script:VPNStatus.vpn.policy.ipv4.site_to_site.enable) {
                true { "Enabled" }
                false { "Disabled" }
            }
        }
        return  $Script:Return
    }
}