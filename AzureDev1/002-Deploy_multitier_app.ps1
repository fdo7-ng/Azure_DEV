<#
    Project: Powershell Deployment of Multi Tier Application
    Version: This is the initial version all parameters are defined in this script
    Future enhancement:
        - Create Array to loops thru subnet arrays and nsg arrays instead of manually defining each.

#>
# https://docs.microsoft.com/en-us/azure/virtual-network/scripts/virtual-network-powershell-sample-multi-tier-application

###### Start of Variables for common values

$rgName = 'fdpsrg01'
$location = 'eastus'

#VM Admin Credentials
[string]$vmAdmin = 'maki'
[string]$vmAdminPW = 'Blizzard123!'

# Virtual Network Information
$vnetName = 'MyVnet'
$subnet1Name = 'MySubnet-FrontEnd'
$subnet1Prefix = '10.0.1.0/24'
$subnet2Name = 'MySubnet-BackEnd'
$subnet2Prefix = '10.0.2.0/24'

###### End of Variable Definition

Write-Host "Running Script - "$MyInvocation.MyCommand.Name

# Create user object
#$cred = Get-Credential -Message "Enter a username and password for the virtual machine."
[securestring]$secStringPassword = ConvertTo-SecureString $vmAdminPW -AsPlainText -Force
[pscredential]$cred = New-Object System.Management.Automation.PSCredential ($vmAdmin, $secStringPassword)

# Create a resource group.
Write-Host "Creating Resource Group [ $rgName]" -ForegroundColor Magenta
if (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue){
    Write-Host "`t[ $rgName] resource group found" -ForegroundColor Yellow
}else{
    Write-Host "`t[ $rgName] creating resource group" -ForegroundColor Green
    New-AzResourceGroup -Name $rgName -Location $location
}



# Create a virtual network with a front-end subnet and back-end subnet.
Write-host "Creating virtual networks" -ForegroundColor Magenta

$vnet = Get-AzVirtualNetwork -Name $vnetName -ErrorAction SilentlyContinue
if ($vnet){
    Write-Host "`t[ $vnetName ] - virtual network found" -ForegroundColor Yellow
    $fesubnet = Get-AzVirtualNetworkSubnetConfig -Name $subnet1Name -VirtualNetwork $vnet -ErrorAction SilentlyContinue
    $besubnet = Get-AzVirtualNetworkSubnetConfig -Name $subnet2Name -VirtualNetwork $vnet  -ErrorAction SilentlyContinue

    if ($fesubnet -and $besubnet){
        Write-Host "`t[ $subnet1Name ] - subnet found" -ForegroundColor Yellow
        Write-Host "`t[ $subnet2Name ] - subnet found" -ForegroundColor Yellow
    }else{
        if (!$fesubnet){
            Write-Host "`t[ $subnet1Name ] - creating subnet" -ForegroundColor green
            $fesubnet = New-AzVirtualNetworkSubnetConfig -Name $subnet1Name -AddressPrefix $subnet1Prefix -WarningAction Ignore
        }else{
            Write-Host "`t[ $subnet1Name ] - subnet found" -ForegroundColor Yellow
        }
        if (!$besubnet) {
            Write-Host "`t[ $subnet2Name ] - creating subnet" -ForegroundColor green 
            $besubnet = New-AzVirtualNetworkSubnetConfig -Name $subnet2Name -AddressPrefix $subnet2Prefix -WarningAction Ignore
        }else{
            Write-Host "`t[ $subnet2Name ] - subnet found" -ForegroundColor Yellow
        }
        $vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName  -AddressPrefix '10.0.0.0/16' `
            -Location $location -Subnet $besubnet,$fesubnet -Confirm:$false -Force
    }

}else{
    Write-Host "`t[ $vnetName ] - Not Found. Start creating." -ForegroundColor Green
    write-host "`t Creating $subnet1Name subnet" -ForegroundColor Green 
    $fesubnet = New-AzVirtualNetworkSubnetConfig -Name $subnet1Name -AddressPrefix '10.0.1.0/24' -WarningAction Ignore
    Write-Host "`t Creating $subnet2Name subnet" -ForegroundColor Green 
    $besubnet = New-AzVirtualNetworkSubnetConfig -Name $subnet2Name -AddressPrefix '10.0.2.0/24' -WarningAction Ignore
    Write-Host "`t Creating $vnetName and subnets"
    $vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName  -AddressPrefix '10.0.0.0/16' `
        -Location $location -Subnet $fesubnet, $besubnet
}


$nsgName = 'MyNsg-FrontEnd'
$rule1Name = 'Allow-HTTP-All'
$rule1Description = 'Allow HTTP' 
$rule1Priority = 100
$rule1DPortRange = 80
$rule2Name = 'Allow-RPD-All'
$rule2Description = 'Allow RDP'
$rule2Priority = 200
$rule2DPortRange = 3389
Write-Host "Creating Front-End Network Security Groups" -ForegroundColor Magenta

$nsgfe = Get-AzNetworkSecurityGroup -Name $nsgName -ErrorAction SilentlyContinue
if ($nsgfe){
    Write-Host "`t[ $nsgName ] - network security group found" -ForegroundColor Yellow
    
    $rule1 = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgfe -Name $rule1Name -ErrorAction SilentlyContinue
    $rule2 = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgfe -Name $rule2Name -ErrorAction SilentlyContinue
    
    if($rule1 -and $rule2){
        Write-Host "`t[ $rule1Name ] - found" -ForegroundColor Yellow
        Write-Host "`t[ $rule2Name ] - found" -ForegroundColor Yellow
    }else{
        if ($rule1){
            Write-Host "`t[ $rule1Name ] - found" -ForegroundColor Yellow
        }else{
            Write-Host "`t[ $rule1Name ] - creating" -ForegroundColor green
            $rule1 = New-AzNetworkSecurityRuleConfig -Name $rule1Name -Description $rule1Description `
                -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule1Priority `
                -SourceAddressPrefix Internet -SourcePortRange * `
                -DestinationAddressPrefix * -DestinationPortRange $rule1DPortRange
        }
    
        if ($rule2) {
            Write-Host "`t[ $rule2Name ] - found" -ForegroundColor Yellow
        }
        else {
            Write-Host "`t[ $rule2Name ] - creating" -ForegroundColor green
            $rule2 = New-AzNetworkSecurityRuleConfig -Name $rule2Name -Description $rule2Description `
                -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule2Priority `
                -SourceAddressPrefix Internet -SourcePortRange * `
                -DestinationAddressPrefix * -DestinationPortRange $rule2DPortRange
        }
        $nsgfe = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
            -Name 'MyNsg-FrontEnd' -SecurityRules $rule1, $rule2 -Confirm:$false -Force
    }

}else{
    Write-Host "`t[ $nsgName ] - creating network security group" -ForegroundColor green

    # Create an NSG rule to allow HTTP traffic in from the Internet to the front-end subnet.
    Write-Host "`t[ $rule1Name ] - creating network security group" -ForegroundColor green
    $rule1 = New-AzNetworkSecurityRuleConfig -Name $rule1Name -Description $rule1Description `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule1Priority `
        -SourceAddressPrefix Internet -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange $rule1DPortRange

    # Create an NSG rule to allow RDP traffic from the Internet to the front-end subnet.
    Write-Host "`t[ $rule2Name ] - creating network security group" -ForegroundColor green
    $rule2 = New-AzNetworkSecurityRuleConfig -Name $rule2Name -Description $rule2Description `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule2Priority `
        -SourceAddressPrefix Internet -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange $rule2DPortRange

    # Create a network security group for the front-end subnet.
    $nsgfe = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
        -Name 'MyNsg-FrontEnd' -SecurityRules $rule1, $rule2

    
}

Write-Host "`t[ MyNsg-FrontEnd ] - Associate the front-end NSG to front-end subnet" -ForegroundColor yellow
# Associate the front-end NSG to the front-end subnet.
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-FrontEnd' `
    -AddressPrefix '10.0.1.0/24' -NetworkSecurityGroup $nsgfe -WarningAction Ignore | Out-Null

$vnet = Get-AzVirtualNetwork -Name $vnetName -ErrorAction SilentlyContinue
$vnet | Set-AzVirtualNetwork  | Out-Null



##########################    Create Back-End NSG Part 2


$nsgName = 'MyNsg-BackEnd'
$rule1Name = 'Allow-SQL-FrontEnd'
$rule1Description = 'Allow SQL' 
$rule1Priority = 100
$rule1DPortRange = 1433
$rule2Name = 'Allow-RPD-All'
$rule2Description = 'Allow RDP'
$rule2Priority = 200
$rule2DPortRange = 3389


Write-Host "Creating Back-End Network Security Groups SQL RDP" -ForegroundColor Magenta
$nsgbe = Get-AzNetworkSecurityGroup -Name $nsgName -ErrorAction SilentlyContinue
if ($nsgbe){
    Write-Host "`t[ $nsgName ] - network security group found" -ForegroundColor Yellow
    $rule1 = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgbe -Name $rule1Name -ErrorAction SilentlyContinue
    $rule2 = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgbe -Name $rule2Name -ErrorAction SilentlyContinue
    
    if ($rule1 -and $rule2) {
        Write-Host "`t[ $rule1Name ] - found" -ForegroundColor Yellow
        Write-Host "`t[ $rule2Name ] - found" -ForegroundColor Yellow
    }
    else {
        if ($rule1) {
            Write-Host "`t[ $rule1Name ] - found" -ForegroundColor Yellow
        }
        else {
            Write-Host "`t[ $rule1Name ] - creating" -ForegroundColor green
            $rule1 = New-AzNetworkSecurityRuleConfig -Name $rule1Name -Description $rule1Description `
                -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule1Priority `
                -SourceAddressPrefix Internet -SourcePortRange * `
                -DestinationAddressPrefix * -DestinationPortRange $rule1DPortRange
        }
    
        if ($rule2) {
            Write-Host "`t[ $rule2Name ] - found" -ForegroundColor Yellow
        }
        else {
            Write-Host "`t[ $rule2Name ] - creating" -ForegroundColor green
            $rule2 = New-AzNetworkSecurityRuleConfig -Name $rule2Name -Description $rule2Description `
                -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule2Priority `
                -SourceAddressPrefix Internet -SourcePortRange * `
                -DestinationAddressPrefix * -DestinationPortRange $rule2DPortRange
        }
        $nsgbe = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
            -Name 'MyNsg-BackEnd' -SecurityRules $rule1, $rule2 -Confirm:$false -Force
        
        # Write-Host "`t[ MyNsg-BackEnd ] - Associate the Back-end NSG to Back-End subnet" -ForegroundColor yellow   
        # # Associate the back-end NSG to the back-end subnet
        # Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-BackEnd' `
        #     -AddressPrefix '10.0.2.0/24' -NetworkSecurityGroup $nsgbe -WarningAction Ignore | Out-Null
        # Set-AzVirtualNetwork  -VirtualNetwork $vnet 


    }

}else{
    Write-Host "`t[ $nsgName ] - creating network security group" -ForegroundColor Green
    # Create an NSG rule to allow SQL traffic from the front-end subnet to the back-end subnet.

    Write-Host "`t[ $rule1Name ] - creating network security group" -ForegroundColor green
    $rule1 = New-AzNetworkSecurityRuleConfig -Name $rule1Name -Description $rule1Description `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule1Priority `
        -SourceAddressPrefix '10.0.1.0/24' -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange $rule1DPortRange

    # Create an NSG rule to allow RDP traffic from the Internet to the back-end subnet.

    Write-Host "`t[ $rule2Name ] - creating network security group" -ForegroundColor green
    $rule2 = New-AzNetworkSecurityRuleConfig -Name $rule2Name -Description $rule2Description `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority $rule2Priority `
        -SourceAddressPrefix Internet -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange $rule2DPortRange

    # Create a network security group for back-end subnet.
    $nsgbe = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
        -Name $nsgName -SecurityRules $rule1, $rule2
    # Associate the back-end NSG to the back-end subnet
    Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-BackEnd' `
        -AddressPrefix '10.0.2.0/24' -NetworkSecurityGroup $nsgbe -WarningAction Ignore | Out-Null
    Set-AzVirtualNetwork  -VirtualNetwork $vnet 
  
}

Write-Host "`t[ MyNsg-BackEnd ] - Associate the Back-end NSG to Back-End subnet" -ForegroundColor yellow   
# Associate the back-end NSG to the back-end subnet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ErrorAction SilentlyContinue
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-BackEnd' `
   -AddressPrefix '10.0.2.0/24' -NetworkSecurityGroup $nsgbe -WarningAction Ignore | Out-Null
Set-AzVirtualNetwork  -VirtualNetwork $vnet  | Out-Null


### Deploying VMs 

$publicIPName1= 'MyPublicIp-Web'

Write-Host "Deploy Web VM" -ForegroundColor Magenta
# Create a public IP address for the web server VM.
$publicipvm1 = Get-AzPublicIpAddress -Name $publicIPName1 -ErrorAction SilentlyContinue

if ($publicipvm1){
    Write-Host "`t[ $publicIPName1 ] - public ip address pool found" -ForegroundColor Yellow
}else{

    Write-Host "`t[ $publicIPName1 ] - creating public ip address pool" -ForegroundColor Green
    $publicipvm1 = New-AzPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName1 `
        -location $location -AllocationMethod Dynamic
}


$nicVMwebname = 'MyNic-Web'

# Create a NIC for the web server VM.
$nicVMweb = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nicVMwebname -ErrorAction SilentlyContinue
if ($nicVMweb){
    Write-Host "`t[ $nicVMwebname ] - found network interface" -ForegroundColor Yellow
}else{
    Write-Host "`t[ $nicVMwebname ] - creating network interface" -ForegroundColor Green
    $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-BackEnd'
    $nicVMweb = New-AzNetworkInterface -ResourceGroupName $rgName -Location $location `
        -Name 'MyNic-Web' -PublicIpAddress $publicipvm1 -NetworkSecurityGroup $nsgfe -Subnet $subnet
}

# $vmweb = Get-AzVm -ResourceGroupName $rgName -Name 'MyVm-Web' -ErrorAction SilentlyContinue
# if ($vmweb){
#     Write-Host "`t[ MyVm-Web ] - found" -ForegroundColor yellow
# }else{
#     Write-Host "`t[ MyVm-Web ] - deploying vm" -ForegroundColor Green
#     # Create a Web Server VM in the front-end subnet
#     $vmConfig = New-AzVMConfig -VMName 'MyVm-Web' -VMSize 'Standard_DS2_v2' | `
#         Set-AzVMOperatingSystem -Windows -ComputerName 'MyVm-Web' -Credential $cred | `
#         Set-AzVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
#         -Skus '2016-Datacenter' -Version latest | Add-AzVMNetworkInterface -Id $nicVMweb.Id

#     $vmweb = New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig
# }







$vmWEB = @{
    'vmsize'='Standard_DS2'
    'vmname'='MyVm-Web'
    'publishername'='MicrosoftWindowsServer'
    'offer'='WindowsServer'
    'sku'='2016-Datacenter'
    'nicname' = 'MyNic-Web'
    'location' = 'eastus'
}



Write-Host "Deploy SQL VM" -ForegroundColor Magenta

$publicIPName2= 'MyPublicIP-Sql'

# Create a public IP address for the SQL VM.

$publicipvm2 = Get-AzPublicIpAddress -Name $publicIPName2 -ErrorAction SilentlyContinue
if ($publicipvm2){
    Write-Host "`t[ $publicIPName2 ] - public ip address pool found" -ForegroundColor Yellow
}else{

    Write-Host "`t[ $publicIPName2 ] - creating public ip address pool" -ForegroundColor Green
    $publicipvm2 = New-AzPublicIpAddress -ResourceGroupName $rgName -Name $publicIPName2 `
        -location $location -AllocationMethod Dynamic
}



$nicVMsqlname = 'MyNic-Sql'

# Create a NIC for the web server VM.
$nicVMsql = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nicVMsqlname -ErrorAction SilentlyContinue
if ($nicVMsql){
    Write-Host "`t[ $nicVMsqlname ] - found network interface" -ForegroundColor Yellow
}else{
    Write-Host "`t[ $nicVMsqlname ] - creating network interface" -ForegroundColor Green
    $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-FrontEnd'
    $nicVMsql = New-AzNetworkInterface -ResourceGroupName $rgName -Location $location `
        -Name 'MyNic-Sql' -PublicIpAddress $publicipvm2 -NetworkSecurityGroup $nsgfe -Subnet $subnet
}


# $vmsql = Get-AzVm -ResourceGroupName $rgName -Name 'MyVm-Sql' -ErrorAction SilentlyContinue
# if ($vmsql){
#     Write-Host "`t[ MyVm-Sql ] - found" -ForegroundColor yellow
# }else{
#     Write-Host "`t[ MyVm-Sql ] - deploying vm" -ForegroundColor Green

#     # Create a SQL VM in the back-end subnet.
#     $vmConfig = New-AzVMConfig -VMName 'MyVm-Sql' -VMSize 'Standard_DS2_v2' | `
#         Set-AzVMOperatingSystem -Windows -ComputerName 'MyVm-Sql' -Credential $cred | `
#         Set-AzVMSourceImage -PublisherName 'MicrosoftSQLServer' -Offer 'SQL2016SP2-WS2016' `
#         -Skus 'Web' -Version latest | Add-AzVMNetworkInterface -Id $nicVMsql.Id

#     $vmsql = New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig
# }



# Create an NSG rule to block all outbound traffic from the back-end subnet to the Internet (must be done after VM creation)
$rule3Name = 'Deny-Internet-All'
$rule3 = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgbe -Name $rule3Name -ErrorAction SilentlyContinue
if ($rule3){
    Write-Host "`t[ $rule3Name ] - outbount network security rule found" -ForegroundColor Yellow
}else{

    Write-Host "`t[ $rule3Name ] - creating outbound network security rule" -ForegroundColor green
    $rule3 = New-AzNetworkSecurityRuleConfig -Name 'Deny-Internet-All' -Description "Deny Internet All" `
        -Access Deny -Protocol Tcp -Direction Outbound -Priority 300 `
        -SourceAddressPrefix * -SourcePortRange * `
        -DestinationAddressPrefix Internet -DestinationPortRange *

    # Add NSG rule to Back-end NSG
    $nsgbe.SecurityRules.add($rule3)

    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsgbe | Out-Null
}



