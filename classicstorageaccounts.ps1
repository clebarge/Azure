Get-AzureSubscription | foreach {
$SubscriptionID = $_.SubscriptionId
$SubscriptionName = $_.SubscriptionName
Select-AzureSubscription -SubscriptionId $SubscriptionID
Get-AzureStorageAccount | foreach {
    $StorageAccount = $_
    New-Object -TypeName PSObject -Property @{
        Location = $StorageAccount.Location
        Name = $StorageAccount.StorageAccountName
        Subscription = $SubscriptionName
        }
    
    }

} | export-csv -NoTypeInformation C:\Working\storageacts.csv