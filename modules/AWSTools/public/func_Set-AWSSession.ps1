<#
.SYNOPSIS
    This script setup AWS environment variables to assume a IAM role with MFA enabled.
.DESCRIPTION
    This script fetches temporary AWS credentials to use a IAM role with a MFA enabled profile. The credentials are provided to packer as environment variabels.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    The script depends on the AWS cli v2
#>

function Set-AWSSession {
    [CmdletBinding()]
    param (
        # IAM role ARN to assume
        [Parameter()]
        [String]
        $RoleArn = $env:AWS_ROLE_ARN,

        # Local IAM profile configured in ~/.aws/credentials to use to assume the role
        [Parameter()]
        [String]
        $ProfileName = $env:AWS_PROFILE,

        # ARN of the MFA device accosiated with the profile to use
        [Parameter(Mandatory)]
        [String]
        $MFADevice,

        # TOTP token
        [Parameter()]
        [ValidateScript({ $_ -match '^[0-9]{6}$' })]
        [Int]
        $MFAToken,

        # Duration of the valide token
        [Parameter()]
        [ValidateRange(900, 60000)]
        [Int]
        $Duration = 900
    )

    $ErrorActionPreference = 'Stop'

    ## Build aws sts command 
    $assumeRoleCmd = New-Object System.Collections.Generic.List[String]
    $assumeRoleCmd.AddRange([String[]]@('aws', 'sts', 'assume-role', `
                '--role-arn', $RoleArn, `
                '--duration-seconds', $Duration, `
                '--role-session-name', 'packer-build', `
                '--profile', $ProfileName
        ))

    if ($MFAToken) {
        $assumeRoleCmd.AddRange([String[]]@('--serial-number', $MFADevice, '--token-code', $MFAToken))
    }

    ## Run command to get temporary credentials and configure them as
    ## environment variabels to can be used from other commands (eg. packer)
    $response = Invoke-Expression ($assumeRoleCmd -join ' ') | ConvertFrom-Json

    $env:AWS_ACCESS_KEY_ID = $response.Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $response.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $response.Credentials.SessionToken
}