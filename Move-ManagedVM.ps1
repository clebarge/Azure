<#
Move Managed Azure VM.

This script is intended to work around the current limition in regards to moving Azure VMs with Managed Disks.
As a VM must be joined to an availability set at creation, if the VM is a member of an AS now, the AS will be recreated in the destination.
You can also specify and create a new availability set by also specifying the AvailabilitySetParameters.
During the move the VM will be offline.

This script does not move related load balancers as that resource may be moved normally and does not have the limitation of availability sets where the VM may 
only join the Availability Set at creation of the VM. As with Public IPs, only Basic SKU load balancers may be moved.
IP Addressing is also not moved with this script, if you have a static public IP address and the SKU is basic you may be able to move it and attach to the VM afterward.
In this case, ensure that the Load Balancer and Public IP addresses are both basic. If you want to use the new Standard SKU for either, you have to accept that a new IP address is
going to be assigned.

Note: This is actually a copy process, not a move, so the last step is to clean up the resources by deleting them from the source. This is not done by default.
        I may add a cleanup switch later to do the clean up, but generally, this is something you want to do manually (my opinion) after testing the VMs work.

Move-ManagedVM 
    [-VMName] <string>
    [-SourceResourceGroup] <string>
    [-SourceSubscription] <string>
    [-DestinationResourceGroup] <string>
    [-DestinationSubscription] <string>
    [-DestinationLocation] <string>
    [-AvailabilitySet] <switch>
    [-AvailabilitySetParameters] <string>
    

Required Parameters:
VMName: The name of the Azure VM to move.
SourceResourceGroup: The name of the Azure resource group where the VM is located.
SourceSubscription: The name of the Azure subscription where the VM is located.This may also be the Subscription ID.
DestinationResourceGroup: The name of the Azure resource group where the VM should be relocated.

Optional Parameters:
Location: Specify a new Azure datacenter location/region during the move.
DestinationSubscription: The name of the destination subcription, if omitted the source subscription is used.
AvailabilitySet: Specifies that the VM is now, or should be placed into an availability set when migrated. The AS will be automatically recreated with the same settings if it exists, or using the specified parameters.
AvailabilitySetParameters: An array of parameters for the creation of a new AS.
                            "Name,FaultDomains,UpdateDomains"

#>

param(
[parameter(Mandatory=$true,HelpMessage="The Name of the Azure RM VM to move.")][string]$VMName,
[parameter(Mandatory=$true,HelpMessage="The name of the source Azure resource group, where the VM is located.")][string]$SourceResourceGroup,
[parameter(Mandatory=$true,HelpMessage="The name of the source Azure subscription, where the VM is located.")][string]$SourceSubscription,
[parameter(Mandatory=$true,HelpMessage="The name of the destination resource group where the VM will be moved.")][string]$DestinationResourceGroup,
[parameter(Mandatory=$false,HelpMessage="The name of the destination subscription where the VM will be moved.")][string]$DestinationSubscription,
[parameter(Mandatory=$false,HelpMessage="The Azure datacenter location for the moved VM.")][string]$Location,
[parameter(Mandatory=$false,HelpMessage="Move the availability set along with the VM.")][switch]$AvailabilitySet,
[parameter(Mandatory=$false,HelpMessage="Parameters for the AS, Name,FaultDomains,UpdateDomains")][string]$AvailabilitySetParameters
)

#Login to Azure, starting in the source subscription
Connect-AzureRmAccount -Subscription $SourceSubscription

#Get information on the configuration of the VM.

$SourceVMConfig = Get-AzureRmVM -ResourceGroupName $SourceResourceGroup -Name $VMName

#Get information on the configuration of the Availability Set if it exists.
IF($AvailabilitySet)
{
$availSetConfig = Get-AzureRmAvailabilitySet -ResourceGroupName $SourceResourceGroup -ErrorAction Ignore | where {$_.Id -eq $SourceVMConfig.AvailabilitySetReference.id}
    IF(-NOT $availSetConfig)
    {
    $AvailabilitySetParameters = $AvailabilitySetParameters
    }
    ELSE
    {
    $AvailabilitySetParameters = ($availSetConfig.Name + "," + $availSetConfig.PlatformFaultDomainCount + "," + $AvailSetConfig.PlatformUpdateDomainCount)
    }

}

#Shutdown the VM if running.
#Stop-AzureRmVM -Name $VMName -ResourceGroupName $SourceResourceGroup -Force

#Get the list of disks for the VM, the move is actually on the disks not the VM, the VM is recreated in this process as part of the work around.
$VMDisks = New-Object System.Collections.ArrayList
$OSDisk = Get-AzureRMDisk -ResourceGroupName $SourceResourceGroup -DiskName $SourceVMConfig.StorageProfile.OsDisk.Name
$VMDisks.Add($OSDisk)

foreach($disk in $SourceVMConfig.StorageProfile.DataDisks)
{
$Disk = Get-AzureRmDisk -ResourceGroupName $SourceResourceGroup -DiskName $disk.name
$VMDisks.Add($Disk)
}

#Switch context to the destination subscription. Note that it is assumed that the same user account has permissions in both subscriptions. I don't believe this allows multiple authentication.
Select-AzureRmSubscription $DestinationSubscription

#Set the location value if destinationlocation is set.
IF($location)
{
$location = $Location
}
ELSE
{
$location = $SourceVMConfig.Location
}

#Copy the Disks to the new location.
foreach($disk in $VMDisks)
{
$diskConfig = New-AzureRmDiskConfig -SourceResourceId $Disk.Id -Location $Location -CreateOption Copy 
#Create a new managed disk in the target subscription and resource group
New-AzureRmDisk `
    -Disk $diskConfig `
    -DiskName $disk.Name `
    -ResourceGroupName $DestinationResourceGroup
}

#Create the new resources.
IF($AvailabilitySet)
{
    $availabilityset = New-AzureRmAvailabilitySet `
        -ResourceGroupName $DestinationResourceGroup `
        -Location $Location `
        -Name ($AvailabilitySetParameters -split ",").GetValue(0) `
        -PlatformFaultDomainCount ($AvailabilitySetParameters -split ",").GetValue(1) `
        -PlatformUpdateDomainCount ($AvailabilitySetParameters -split ",").GetValue(2)`
        -Sku Aligned

    $NewVMConfig = New-AzureRmVMConfig -VMName $SourceVMConfig.Name -VMSize $SourceVMConfig.HardwareProfile.VmSize -AvailabilitySetId $AvailabilitySet.Id
    $NewOSDisk = Get-AzureRmDisk -ResourceGroupName $DestinationResourceGroup -DiskName $OSDisk.Name
    
    Set-AzureRmVMOSDisk `
        -VM $NewVMConfig `
        -CreateOption Attach `
        -ManagedDiskId $NewOSDisk.Id `
        -Name $NewOSDisk.Name `
        -Windows

    foreach($disk in $VMDisks)
    {
        IF($disk.Name -ne $NewOSDisk.Name)
        {
        $DiskID = Get-AzureRmDisk -ResourceGroupName $DestinationResourceGroup -DiskName $Disk.Name
        Add-AzureRmVMDataDisk `
            -VM $NewVMConfig `
            -Name $disk.Name `
            -ManagedDiskId $DiskID.Id `
            -Caching $disk.Caching `
            -Lun $Disk.Lun `
            -DiskSizeInGB $disk.DiskSizeGB `
            -CreateOption Attach
        }
    }
#Create the destination VM
New-AzureRMVM `
    -ResourceGroupName $DestinationResourceGroup `
    -Location $Location `
    -VM $NewVMConfig `
    -DisableBginfoExtension
    
}
ELSE
{
    $NewVMConfig = New-AzureRmVMConfig -VMName $SourceVMConfig.Name -VMSize $SourceVMConfig.HardwareProfile.VmSize
    $NewOSDisk = Get-AzureRmDisk -ResourceGroupName $DestinationResourceGroup -DiskName $OSDisk.Name
    
    Set-AzureRmVMOSDisk `
        -VM $NewVMConfig `
        -CreateOption Attach `
        -ManagedDiskId $NewOSDisk.Id `
        -Name $NewOSDisk.Name `
        -Windows

    foreach($disk in $VMDisks)
    {
        IF($disk.Name -ne $NewOSDisk.Name)
        {
        $DiskID = Get-AzureRmDisk -ResourceGroupName $DestinationResourceGroup -DiskName $Disk.Name
        Add-AzureRmVMDataDisk `
            -VM $NewVMConfig `
            -Name $disk.Name `
            -ManagedDiskId $DiskID.Id `
            -Caching $disk.Caching `
            -Lun $Disk.Lun `
            -DiskSizeInGB $disk.DiskSizeGB `
            -CreateOption Attach
        }
    }
#Create the destination VM
New-AzureRMVM `
    -ResourceGroupName $DestinationResourceGroup `
    -Location $Location `
    -VM $NewVMConfig `
    -DisableBginfoExtension
    
}






