#Basic Hashtable of VM size and monthly cost in CAD
$AzureRMSku = $null
$AzureRMSku = @{
'Standard_D12_V2' = '517.47'
'Standard_DS3_v2' = '498.84'
'Standard_A3' = '362.14'
'Basic_A3' = '362.14'
}

#Get all resources in the subscription
$AllResources = Get-AzureRmResource | select Name,ResourceType,ResourceGroupName

$CostofVMs = 0
$cost = 0
#Get information necessary for VM calculation.
$AllResources | where {$_.ResourceType -like "*virtualmachines"} | ForEach-Object {
    $VMSize = (Get-AzureRmVM -ResourceGroupName $_.ResourceGroupName -Name $_.Name | Select HardwareProfile).HardwareProfile.VMSize
    $cost = $AzureRMSku.$VMSize
    $cost
    $CostofVMs = $CostofVMs + $cost
} 
