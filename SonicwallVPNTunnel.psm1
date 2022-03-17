# Importing public and private functions
$PSScript = "C:\Program Files\WindowsPowerShell\Modules\SonicwallVPNTunnel\0.0.1"
$PublicFunc = @(Get-ChildItem -Path $PSScript\*.ps1 -ErrorAction SilentlyContinue)
$Global:Logname = "SonicaWall"
$Global:EventSource = "VPNTunnel"
# Dotsourcing files
ForEach ($import in $PublicFunc) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ([System.Net.ServicePointManager]::CertificatePolicy -match "System.Net.DefaultCertPolicy") {
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
class ConnectionString {
    [string]$User
    [string]$Pass
    [string]$TFA
    [string]$IP;

    ConnectionString () {
        $this.User = (Get-ITGluePasswords -organization_id 2426679 -id 10471614).data.attributes.username
        $this.pass = (Get-ITGluePasswords -organization_id 2426679 -id 10471614).data.attributes.password
        $this.TFA = Get-OTP -SECRET ((Get-ITGluePasswords -organization_id 2426679 -id 10471614).data.attributes.notes).trim() -LENGTH 6 -WINDOW 30
        $this.IP = "12.206.85.178"
    }
    
}
# Exporting just the Public functions
Export-ModuleMember -Function $PublicFunc.BaseName