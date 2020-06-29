<#
    Overview: This script is used to replace a network interface for a particular VM

#>


$vmname = "fdtvm01"
$resource_group = "fdpsrg01"
$nic_name = "fdtvm01315"
$new_nic = "fdtvm-nic1"

# put back original nic
$revert = $true
Write-Host "Processing Modify Nic Script"

$vm = Get-AzVm -Name $vmname -ResourceGroupName $resource_group

if ($?){
    Write-Host "Found VM - [$($vm.Name)]"  -ForegroundColor "Yellow"
    # https://docs.microsoft.com/en-us/azure/virtual-machines/windows/multiple-nics?toc=/azure/virtual-network/toc.json

    $network_interfaces = $vm.NetworkProfile.NetworkInterfaces
    Write-Host "Number of network interfaces [ $($network_interfaces.count) ]"

    $nicId = $vm.NetworkProfile.NetworkInterfaces.Id
    #remove network AzVMNetworkInterface only if Dynamic

    $network_interface = Get-AzNetworkInterface -ResourceId $nicId

    Write-Host "Network interface name [ $($network_interface.Name) ]"

    if ( $network_interface.IpConfigurations.PrivateIpAllocationMethod -eq "Dynamic" ){
        Write-Host "Detected Dynamic Network Interface" -ForegroundColor "Yellow"
        write-Host "Removing Network Interface [$($network_interface.Id)]" -ForegroundColor "Yellow"
        Remove-AzVMNetworkInterface -VM $vm -NetworkInterfaceIDs $($network_interface.Id) | Update-AzVm -ResourceGroupName $resource_group


        $network_interface = Get-AzNetworkInterface -ResourceGroupName $resource_group -Name $new_nic
        if ($?){
            write-Host "Found Network Interface [$($network_interface.Name)]"
            Write-Host "Adding new network interface" -ForegroundColor "Yellow"
            Add-AzVMNetworkInterface -VM $vm -Id $($network_interface.Id) | Update-AzVm -ResourceGroupName $resource_group
        }

    }Else{
        Write-Host "No Dynamic Network Interface found."

    }


}

# Reevert Configuration
if ($revert){
    Write-Host "Revert Configuration"
    $network_interface = Get-AzNetworkInterface -ResourceGroupName $resource_group -Name $new_nic

    Remove-AzVMNetworkInterface -VM $vm -NetworkInterfaceIDs $($network_interface.Id) | Update-AzVm -ResourceGroupName $resource_group

    $network_interface = Get-AzNetworkInterface -ResourceGroupName $resource_group -Name $nic_name

    Add-AzVMNetworkInterface -VM $vm -Id $($network_interface.Id) | Update-AzVm -ResourceGroupName $resource_group

}










