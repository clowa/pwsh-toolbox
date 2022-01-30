<#
.SYNOPSIS
    This cmdlet let you fetch the token to access AWS EKS cluster.
.DESCRIPTION
    This cmdlet uses the AWS CLI to fetch the token to access the AWS elastic kubernetes service cluster and per default store it to clipboard.
.EXAMPLE
    PS C:\> Get-EKSToken -Region eu-west-1 -ClusterName myCluster
    Get the token of cluster myCluster located at eu-west-1 and store it to clipboard.
#>
function Get-EKSToken {
    param (
        # AWS region of the kubernetes cluster
        [Parameter(
            Position = 0
        )]
        [String]
        #! The following regex can lead to "' doesn't match a supported format" if ~/.aws/config is formated with CFLF. Solution is to store file with LF.
        $Region = $((Get-Content -Raw -Path $HOME/.aws/config | Select-String -Pattern '\[default\]\s*\r\n?|\nregion\s*=\s(.*)').Matches.Groups[1].Value),

        # Name of the kubernetes cluster
        [Parameter(
            Position = 1
        )]
        [String]
        $ClusterName = $((Select-String -Pattern 'current-context: (.*)$' -Path $HOME/.kube/config).Matches.Groups[1].Value),

        # Name of the AWS profile to use
        [Parameter()]
        [String]
        $ProfileName = $( if ($env:AWS_PROFILE) { $env:AWS_PROFILE } else { "default" } ),

        # Pass thru the token and do not set it to clipboard
        [Parameter()]
        [Switch]
        $PassThru,

        # Use the raw response and do not extract the token
        [Parameter()]
        [Switch]
        $Raw
    )

    $response = Invoke-Expression "aws eks get-token --cluster-name `"$Clustername`" --region `"$Region`" --profile `"$ProfileName`"" | ConvertFrom-Json

    if ($Raw) {
        $result = $response
    } else {
        $result = $response.status.token
    }

    if ($PassThru) {
        return $result
    }

    $result | Set-Clipboard
}

Set-Alias -Name token -Value Get-EKSToken -Description 'Shortcut to get eks token of prototype cluster'  