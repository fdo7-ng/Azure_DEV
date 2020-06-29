<#
    Powershell Script to Create Network Interface

    Assumption:
    - Vnet and Subnet are already created and exist
    - All VMs in the list belong to the same vNet / Subnet
    - Accepts server.json file exported from Ansible MCP Module

    Updates:
    - 06/16/2020: Initial Version
#>


## Parameter Section

$location = 'eastus'
$networkdomainID = 'd6f0740b-9026-4222-a0a5-f21e37c2a767'
$resourcegroup = 'fdpsrg01'
$vnet_name = 'HQ-Network' 
$subnet_name = 'SAPDRSPOC_VLAN'

$server_file = './output/servers.json'
$server_data = Get-Content $server_file | ConvertFrom-JSON 
$server_count = $server_data.data.count
$server_list = $server_data.data.server

# Configure destroy parameter to delete network interface created by this script ($true|$false)
$destroy = $true

# Code Section

$vnet = Get-AzureRmVirtualNetwork -Name $vnet_name

foreach ($vm in $server_list){
    $vmname = $vm.name
    $vmNicName = $vmname + "-nic0"
    $primaryNIC = $vm.networkInfo.primaryNIC
    $vlanName = $primaryNIC.vlanName
    $privateIpv4 = $primaryNIC.privateIpv4

    Write-Host "Server Name: " $vmname
    Write-Host " --- vlanName: " $vlanName
    Write-Host " --- Primary Nic IP: " $privateIpv4

    $network_interface = Get-AzNetworkInterface -ResourceGroupName $resourcegroup -Name $vmNicName -ErrorAction SilentlyContinue

    if($network_interface) {
        Write-Host " --- Found network interface - " $vmNicName -ForegroundColor Green

    }else{
        Write-Host " --- Creating network interface - " $vmNicName -ForegroundColor Yellow
        $subnetID = (Get-AzureRmVirtualNetworkSubnetConfig -Name $vlanName -VirtualNetwork $vnet).id

        New-AzureRmNetworkInterface -Name $vmNicName -ResourceGroupName $resourcegroup -Location $location -SubnetId $subnetID -PrivateIpAddress $privateIpv4 | Out-Null
    }

    if ($destroy){
        Write-Host " --- Destroy network interface - "  $vmNicName -ForegroundColor Red
        $network_interface | Remove-AzNetworkInterface -Force -Confirm:$false
    }

}