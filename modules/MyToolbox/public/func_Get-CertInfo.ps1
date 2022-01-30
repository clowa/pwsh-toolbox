<#
.SYNOPSIS
    This cmdlet check the left valid days of certificates
.DESCRIPTION
    This cmdlet check the certificate of websites and check if the certificate is valid for at least a given time.
.EXAMPLE
    PS C:\> Get-CertInfo -Site google.de -MinDaysTillExpiration 50
    Check if the certificate of google is valid for at least 50 days.
#>
function Get-CertInfo {
    #Requires -Module CertificateHealth
    [CmdletBinding()]
    param (
        # URL(s) of websites to check certificates of
        [Parameter(
            Mandatory,
            Position = 1,
            ValueFromPipeline
        )]
        [String[]]
        $Site,

        # Days that the certificate should still be valid 
        [Parameter(
            Position = 2
        )]
        [Int]
        $MinDaysTillExpiration = 90
    )

    Begin {
        $certInfos = [PSCustomObject[]]
        # Disable certificate validation
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }

    Process {
        try {
            $certInfos = foreach ($s in $site) {
                Write-Verbose "Check $($s)"
                $cert = Get-NetCertificate -ComputerName $s
    
                $certExpDate = $cert.NotAfter
                [int]$certExpiresIn = ($certExpDate - $(Get-Date)).Days
    
                if ($certExpiresIn -gt $MinDaysTillExpiration) {
                    $notify = $false
                } else {
                    $notify = $true
                }
    
                $commonName = $cert.Subject -split 'CN=' | Where-Object { $_ }
    
                [PSCustomObject]@{
                    Name               = $commonName
                    Thumbprint         = $cert.Thumbprint
                    ValidSince         = $cert.NotBefore
                    ValidTill          = $cert.NotAfter
                    DaysTillExpiration = $certExpiresIn
                    Notify             = $notify
                }
            }
    
            return $certInfos
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
    }

    End { }   
}