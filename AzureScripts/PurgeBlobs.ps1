$storageAccounts = @()
$storageAccounts += New-Object -TypeName psobject -Property @{
    name = "airnetclassic"
    containers = @("test")
    blobKey = "test"
    timeDays = 15
}
$blobs = @()
foreach($storageAccount in $storageAccounts)
{
   $account = Get-AzureRmStorageAccount | ?{$_.StorageAccountName -eq $storageAccount.name}
   $context = $account.Context
   foreach($containerName in $storageAccount.containers)
   {
      $blobs = Get-AzureStorageBlob -Container $containerName -Context $context | ?{$_.Name -like "*$($storageAccount.blobKey)*" -and $_.LastModified -gt ((Get-Date).AddDays($storageAccount.timeDays * - 1)) -and $_.ICloudBlob.Properties.LeaseStatus -eq "UnLocked" }
      foreach($blob in $blobs)
      {
        Remove-AzureStorageBlob -CloudBlob $blob.ICloudBlob -Context $context
      }
   }   
}