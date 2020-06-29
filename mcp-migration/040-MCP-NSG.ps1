<#
    Powershell Script convert MCP Firewall rules into to Azure NSG

    Assumption:
    - MCP Firewall rules are all under a network domain
    - Previously we created all server vlans under same VNET
      - All server vlans will be added to same VNET
      - Create all necesary address space and subnets.
    - In Azure, Network Domain will be represented by a VNET
      - All firewall rulles belonging to network domain will be created for VNET



    Updates:
    - 06/16/2020: Initial Version
#>

Write-Host "Running Firewall Rules Script"
$location = 'eastus'
$networkdomainID = 'd6f0740b-9026-4222-a0a5-f21e37c2a767'
$resourcegroup = 'fdpsrg01'
$vnet_name = 'HQ-Network' 
$subnet_name = 'Advanced_POC'


$cnd_file = './output/cloud_network_domains.json'
$cnd_data = Get-Content $cnd_file -ErrorAction SilentlyContinue | ConvertFrom-JSON 
if ($?){
  Write-Host "[$cnd_file] - Loaded succesfully" -ForegroundColor Yellow
}else{
  Write-Host "[$cnd_file] - Failed to load. Please verify filename or existence" -ForegroundColor Red
  break
}

$cnd_list = $cnd_data.data.network_domain
$cnd_count  = $cnd_data.data.count
Write-Host "Searching for match" -ForegroundColor Yellow
$cnd = $cnd_list | ? {$_.Name -eq $subnet_name}
Write-Host "Found CND [ $($cnd.Name) , $($cnd.Id)]"

$firewall_file = './output/firewall_Advanced_POC.json'
$firewall_data = Get-Content $firewall_file | ConvertFrom-JSON 
$firewall_list = $firewall_data.data.acl
$firewall_count  = $firewall_data.data.acl.count
if ($?){
  Write-Host "[$firewall_file] - Loaded succesfully" -ForegroundColor Yellow
}else{
  Write-Host "[$firewall_file] - Failed to load. Please verify filename or existence" -ForegroundColor Red
  break
}

Write-Host "FireWall Rules Count [ $firewall_count ] "

foreach ($fw in $firewall_list){

  $fw

}
# # Create an NSG rule to allow HTTP traffic in from the Internet to the front-end subnet.
# $rule1 = New-AzNetworkSecurityRuleConfig -Name 'Allow-HTTP-All' -Description 'Allow HTTP' `
#   -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
#   -SourceAddressPrefix Internet -SourcePortRange * `
#   -DestinationAddressPrefix * -DestinationPortRange 80

# # Create an NSG rule to allow RDP traffic from the Internet to the front-end subnet.
# $rule2 = New-AzNetworkSecurityRuleConfig -Name 'Allow-RDP-All' -Description "Allow RDP" `
#   -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 `
#   -SourceAddressPrefix Internet -SourcePortRange * `
#   -DestinationAddressPrefix * -DestinationPortRange 3389

# Create a network security group for the front-end subnet.
#  $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RgName -Location $location `
#   -Name 'MyNsg-FrontEnd' -SecurityRules $rule1,$rule2

$nsg_name = $subnet_name + "_nsg"
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourcegroup -Name $nsg_name -ErrorAction SilentlyContinue
if ($?){

}
else{
  Write-Host "[ $nsg_name ] - Not Found. Creating"
}