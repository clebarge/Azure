# Azure

Powershell Scripts and ARM Templates for Management of Azure Resources.

Move-ManagedVM.PS1: This script is intended to help work around moving Azure RM VMs with Managed Disks as it is currently not possible to move these resources.

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
