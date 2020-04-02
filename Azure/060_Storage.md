---
title: Azure Storage
---

# Azure Storage

## Converting Disks

see https://docs.microsoft.com/en-us/azure/virtual-machines/windows/convert-disk-storage

````
# connect and select subscription
Connect-AzAccount -UseDeviceAuthentication
$subscriptionObject = Get-AzSubscription | Sort-Object -Property Name | Out-GridView -PassThru | Select-AzSubscription

# Name of the resource group that contains the VM
$rgName = 'yourResourceGroup'

# Name of the your virtual machine
$vmName = 'yourVM'

# Choose between Standard_LRS and Premium_LRS based on your scenario
$storageType = 'Premium_LRS'

# Premium capable size
# Required only if converting storage from Standard to Premium
# $newsize = 'Standard_DS2_v2'

# Stop and deallocate the VM before changing the size
Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force

$vm = Get-AzVM -Name $vmName -resourceGroupName $rgName
if ($newsize) {
    # Change the VM size to a size that supports Premium storage
    # Skip this step if converting storage from Premium to Standard
    $vm.HardwareProfile.VmSize = $newsize

    Update-AzVM -VM $vm -ResourceGroupName $rgName
}

# Get all disks in the resource group of the VM
$vmDisks = Get-AzDisk -ResourceGroupName $rgName

# For disks that belong to the selected VM, convert to Premium storage
foreach ($disk in $vmDisks)
{
	if ($disk.ManagedBy -eq $vm.Id)
	{
		$disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
		$disk | Update-AzDisk
	}
}

Start-AzVM -ResourceGroupName $rgName -Name $vmName
````

## Creating a VHD file from an online disk / shrink VHD disk size

Follow the instructions for [Disk2vhd](https://docs.microsoft.com/de-de/sysinternals/downloads/disk2vhd) by Mark Russinovich

Here are some additional information about how to shrink the size of a VM's VHD file: https://roadtoalm.com/2016/10/25/shrink-the-physical-size-of-an-azure-virtual-machine-vhd/

## Azure Shared Disks

| Title                       | Location                                                                                |
| :-------------------------- | :-------------------------------------------------------------------------------------: |
| Azure Shared Disks - Preview | [Link](https://azure.microsoft.com/de-de/blog/announcing-the-preview-of-azure-shared-disks-for-clustered-applications/) |
| Azure Shared Disks - Documentation | [Link](https://aka.ms/azureshareddiskdocs) |
| Azure Shared Disks - Ignite 2019 Video | [Link](https://myignite.techcommunity.microsoft.com/sessions/82058) |
|  | [Link]() |

## Other interesting articles

| Title                       | Location                                                                                |
| :-------------------------- | :-------------------------------------------------------------------------------------: |
| Premium SSD: Bursting  | [Link](https://azure.microsoft.com/de-de/blog/general-availability-of-new-azure-disk-sizes-and-bursting/) |
| AD Authentication for Azure fileshares (Preview) | [Link](https://azure.microsoft.com/de-de/blog/preview-of-active-directory-for-authentication-on-azure-file/) |
| INCREMENTAL snapshots of managed Disks | [Link](https://azure.microsoft.com/de-de/blog/announcing-general-availability-of-incremental-snapshots-of-managed-disks/) |
