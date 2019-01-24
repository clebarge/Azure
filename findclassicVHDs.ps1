Get-AzureSubscription | foreach {
$SubscriptionID = $_.SubscriptionId
$SubscriptionName = $_.SubscriptionName
Select-AzureSubscription -SubscriptionId $SubscriptionID
Get-AzureStorageAccount | foreach {
    $StorageAccountName = $_.StorageAccountName
    $ContainerContext = $_.Context
    Get-AzureStorageContainer -Context $ContainerContext | where {$_.Name -match "vhd"} | foreach {
        $ContainerName = $_.Name
        
        IF($_.CloudBlobContainer.Properties.LeaseStatus -eq "Locked"){
            write-host "For subscription: $SubscriptionName Active VHDs found in storage account: $StorageAccountName"
            }
        
        }
    }

}