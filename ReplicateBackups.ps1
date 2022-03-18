# Replicate Backups to SatCom
Import-Module Veeam.Backup.PowerShell
Import-Module SonicwallVPNTunnel


$Script:VPNStatus = Get-VPNTunnelStatus -VPN_Name "SatCom"
$Script:BackupStatus = Invoke-Command -ComputerName "LocalHost" -ScriptBlock { Get-VBRJob | Where-Object { $_.JobType -eq "Backup" } }
if ($Script:BackupStatus.IsRunning -contains $True) {
    Write-host -ForegroundColor Yellow "Backup is Running - Waiting to Complete."
    do {
        $Script:BackupStatus = Invoke-Command -ComputerName "LocalHost" -ScriptBlock { Get-VBRJob | Where-Object { $_.JobType -eq "Backup" } }
        Start-Sleep -second 120
    } until ($Script:WaitingToComplete.IsRunning -notcontains $True)
    $Script:VPNStatus = Get-VPNTunnelStatus -VPN_Name "SatCom"
}

if ($Script:VPNStatus.VPNStatus -eq "Disabled") {
    Write-host -ForegroundColor Yellow "VPN is Disabled - Enabling."
    Set-VPNTunnel -Enable -VPN_Name "SatCom"
}

$i = 0 
do {
    $i++
    Write-Host -ForegroundColor Yellow "Starting VPN and waiting until it reported online."
    $Script:VPNStatus = Get-VPNTunnelStatus -VPN_Name "SatCom"
    Start-Sleep -Seconds 10
} until ($Script:VPNStatus.VPNStatus -eq "Enabled" -or $i -eq 20)

if ($Script:VPNStatus.VPNStatus -eq "Disabled") {
    Write-host -ForegroundColor Red "VPN Did not Start."
    [System.Diagnostics.EventLog]::WriteEntry($Global:EventSource, "VPN Tunnel $($VPN_Name) could not be enabled.", "Error", "200")
    exit 1
}

if ((Invoke-Command -ComputerName "LocalHost" -ScriptBlock {Get-VBRJob -Name "DataCenter"}).IsRunning -eq $False) {
    Write-host -ForegroundColor Yellow "Starting Replication."
    Invoke-Command -ComputerName "LocalHost" -ScriptBlock { Get-VBRJob -Name "DataCenter" | Sync-VBRBackupCopyJob -ImmediateCopyLastRestorePoint }
}
do {
    $Script:ReplicationStatus = Invoke-Command -ComputerName "LocalHost" -ScriptBlock { Get-VBRJob -Name "DataCenter" }
    Write-host -ForegroundColor Yellow "Watching Replication Job for Completion."
    Start-Sleep -Seconds 1800
} until ($Script:ReplicationStatus.IsRunning -ne $True)
Write-host -ForegroundColor Yellow "Disabling VPN"
$Script:VPNStatus = Get-VPNTunnelStatus -VPN_Name "SatCom"
if ($Script:VPNStatus -eq "Enabled") {
    Write-host -ForegroundColor Yellow "VPN Still Enabled, Attempting to disable again."
    $i = 0
    do {
        $i++
        $Script:VPNStatus = Set-VPNTunnel -Disable -VPN_Name "SatCom"
        Start-Sleep -Seconds 10
    } until ($Script:VPNStatus -eq "Disabled" -or $i -eq 20)
    $Script:VPNStatus = Get-VPNTunnelStatus -VPN_Name "SatCom"
    if ($Script:VPNStatus -eq "Disabled") {
        [System.Diagnostics.EventLog]::WriteEntry($Global:EventSource, "VPN Tunnel $($VPN_Name) was Disabled", "Information", "101")
    }
    if ($Script:VPNStatus -eq "Enabled") {
        [System.Diagnostics.EventLog]::WriteEntry($Global:EventSource, "VPN Tunnel $($VPN_Name) could not be disabled.", "Error", "201")
    }
}
