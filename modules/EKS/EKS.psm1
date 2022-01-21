###
# EKS
###
function Get-EKSToken {
    param (
        $Clustername = $((Select-String -Pattern 'current-context: (.*)$' -Path $HOME/.kube/config).Matches.Groups[1].Value),
        #! The following regex can lead to "' doesn't match a supported format" if ~/.aws/config is formated with CFLF. Solution is to store file with LF.
        $Region = $((Get-Content -Raw -Path $HOME/.aws/config | Select-String -Pattern '\[default\]\s*\r\n?|\nregion\s*=\s(.*)').Matches.Groups[1].Value),
        $ProfileName = $( if ($env:AWS_PROFILE) { $env:AWS_PROFILE } else { "default" } ),
        [Switch] $PassThru,
        [Switch] $Raw
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
  