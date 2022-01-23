function Confirm-VaultExists {
    param (
        # Name of the Vault
        [Parameter(Mandatory, Position = 0)]
        [String]
        $VaultName
    )

    ## Check if provided vault exists. If not throw termination exception
    $Vault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
    
    if (-Not $Vault) {
        ## Easyly create an error and throw it again as a terminating error without do all the error object stuff.
        try { throw "SecretVault $VaultName doesn't exist." } catch { $PSCmdlet.ThrowTerminatingError($_) }
    }

    return $true
}