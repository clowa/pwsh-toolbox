Function Restore-AzureDeletedBlob {
    [CmdletBinding()]
    param (
        # # Azure storage context
        # [Parameter(Mandatory)]
        # [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]
        # $Context,

        # # Blob Container Name
        # [Parameter(Mandatory)]
        # [String]
        # $ParameterName,

        # Deleted Blob Object
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBlob]
        $Blob,

        # Azure Storage API Version
        # See https://learn.microsoft.com/en-us/rest/api/storageservices/previous-azure-storage-service-versions
        [Parameter()]
        [String]
        $Version = "2020-04-08"#"2023-05-03"
    )

    begin {
        # Import the AzureRM module
        Import-Module -Name "Az.Storage" -MinimumVersion "1.0.0" -Force -ErrorAction Stop

        $curlFound = Get-Command -Name "curl" -ErrorAction SilentlyContinue
        if ($null -eq $curlFound ) {
            Write-Error "curl not found in PATH. Please install or add curl to PATH to use this function."
            exit 1
        }

        $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
        $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resource).AccessToken
    }

    process {
        if ($Blob.IsDeleted -eq $false) {
            Write-Warning "Blob is not deleted yet: $($Blob.Name)"
            return
        }

        $date = (Get-Date).ToUniversalTime().ToString('R')

        $uri = ($Blob.BlobBaseClient.Uri.AbsoluteUri -replace "\?.*", "") + "?comp=undelete"
        # $uri = $Blob.BlobBaseClient.Uri.AbsoluteUri + "?comp=undelete"
        Write-Verbose "Restoring: $uri"
        curl `
            -v `
            -X "PUT" `
            -H "x-ms-date: $date" `
            -H "x-ms-version: $Version" `
            -H "x-ms-blob-type: $($Blob.BlobType)" `
            -H "Authorization: Bearer $accessToken" `
            -H "Content-Length: 0" `
            $uri
    }

    end {
        Remove-Module -Name "Az.Storage" -Force
    }
}
