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

Function Copy-AzSqlInstanceDatabaseViaPointInTimeBackup {
    param(
        # Name of the database to recreate
        [Parameter(Mandatory = $true)]
        [String]
        $DatabaseName,

        # Name of the resource group where the source instance is located
        [Parameter(Mandatory = $true)]
        [String]
        $SourceResourceGroupName,

        # Name of the source instance
        [Parameter(Mandatory = $true)]
        [String]
        $SourceInstanceName,

        # Name of the target resource group where the target instance is located
        [Parameter(Mandatory = $true)]
        [String]
        $TargetResourceGroupName,

        # Name of the target instance
        [Parameter(Mandatory = $true)]
        [String]
        $TargetInstanceName,

        # Age of the backup to restore in minutes
        [Parameter(Mandatory = $false)]
        [Int]
        $BackupAgeInMinutes = 7
    )

    $source = @{
        ResourceGroupName = $SourceResourceGroupName
        InstanceName      = $SourceInstanceName
        DatabaseName      = $DatabaseName
    }

    $target = @{
        ResourceGroupName = $TargetResourceGroupName
        InstanceName      = $TargetInstanceName
        DatabaseName      = $DatabaseName
    }

    Write-Host "Copying database `"$($source.DatabaseName)`" from `"$($source.InstanceName)`" to `"$($target.InstanceName)`" ..."

    $sourceInstance = Get-AzSqlInstance `
        -ResourceGroupName $source.ResourceGroupName `
        -Name $source.InstanceName
    $sourceDatabase = $sourceInstance | Get-AzSqlInstanceDatabase -Name $source.DatabaseName

    if (-Not $?) {
        Write-Error "Database `"$($source.DatabaseName)`" does not exist on `"$($source.InstanceName)`"."
        exit 1
    }

    $BackupAgeInMinutes = $BackupAgeInMinutes * -1

    # Checking if the target time is older than the earliest restore point available on the source database.
    if ((Get-Date).AddMinutes($BackupAgeInMinutes) -lt $sourceDatabase.EarliestRestorePoint) {
        Write-Host "Your target restore point is older than the earliest restore point available on the source database. Please choose a more recent restore point. The earliest restore point available is `"$($sourceDatabase.EarliestRestorePoint)`""
        exit 1
    }

    $targetInstance = Get-AzSqlInstance `
        -ResourceGroupName $target.ResourceGroupName `
        -Name $target.InstanceName
    $targetDatabase = $targetInstance | Get-AzSqlInstanceDatabase -Name $target.DatabaseName -ErrorAction SilentlyContinue

    # Dropping the database if it exists on the target instance.
    if (-Not ($? -eq $false -And $null -eq $targetDatabase)) {
        Write-Host "Target Database `"$($targetDatabase.Name)`" already exists."

        ## Prompting the user to confirm the deletion of the database if -Force is not set.
        if (-Not $Force) {
            $deleteDatabase = Read-Host -Prompt "Do you want to delete the database and recreate it? (y/n)"
        }
        if (-Not $Force -And $deleteDatabase -ne "y") {
            Write-Host "Aborting."
            exit 1
        }
        
        $targetDatabase | Remove-AzSqlInstanceDatabase -Force | Out-Null
        if ($?) {
            Write-Host "Successfully deleted Target Database `"$($targetDatabase.Name)`"."
        } else {
            Write-Host "Failed to delete Target Database `"$($targetDatabase.Name)`"."
            exit 1
        }

        Write-Host "Waiting for the azure APIs to catch up ..."
        Start-Sleep -Seconds 10 # Wait for the azure APIs to catch up
    }

    Write-Host "Initiating restore of `"$($source.DatabaseName)`" from `"$($source.InstanceName)`" to `"$($target.InstanceName)`" ..."

    $sourceDatabase | Restore-AzSqlInstanceDatabase `
        -FromPointInTimeBackup `
        -PointInTime (Get-Date).AddMinutes($BackupAgeInMinutes) `
        -TargetResourceGroupName $targetInstance.ResourceGroupName `
        -TargetInstanceName $targetInstance.ManagedInstanceName `
        -TargetInstanceDatabaseName $target.DatabaseName |
    Out-Null

    if ($?) {
        Write-Host "Database `"$($source.DatabaseName)`" recreated successfully."
    } else {
        Write-Host "Database `"$($source.DatabaseName)`" recreated failed."
        exit 1
    }
}