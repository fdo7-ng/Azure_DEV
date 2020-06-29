
<#
    Description: Script to process json file with vlan information generated from ansible report 
        - Script will generate vlan object
        - determine the address space it should belong to for VNET creation
        - determine parameters required to create subnet
    Assumption:
        - Currently assuming Network Domain will be equivalent to Resource Group in Azure
        - CC Vlans if /24, this tool will create a /16 address
        - All server vlans will be created under same VNET. 
        - vNet will be named after the CND name
    Considerations:
        - In CC we create server vlans using /24, we can create /24 size VNET/Subnet. 
        or 
        - Create a /16 address for each corresponding /24 server vlan.
    Updates:
    06/16/2020: Added vNet Creation and Subnet creation
        - vNet and subnet name cannot contains spaces, replaced spaces " " with underscore "_"
#>


$file = '.\output\vlans\vlans_ECL-MCP migration.json'
$rg_name = 'fdpsrg01'
$location = 'eastus'



$json_data = Get-Content $file | ConvertFrom-Json

$vlan_list = $json_data.data.vlan

$rpt = @()

foreach ($vlan in $vlan_list){

    Write-Host "Processing on " $vlan.Name
    $vlan_obj = $vlan | select Name, datacenterId, ipv4GatewayAddress, Ipv6GatewayAddress, 
        networkDomain, privateIpv4Range
    
    $vnet_name = $vlan.networkDomain.name.replace(" ","_")
    $subnetprefix = $vlan_obj.privateIpv4Range.address +"/"+ $vlan_obj.privateIpv4Range.prefixSize
    if ( $vlan.privateIpv4Range.prefixSize -eq 24 ){
        $address_split = $vlan_obj.privateIpv4Range.address.split('.')
        $address_split[2] = '0'
        $address_split[3] = '0'
        $address_space = $address_split -join '.'
        $addressprefix = $address_space + "/16"
    }

    
    $vlan_obj | Add-Member NoteProperty -Name addressprefix -Value $addressprefix # to create vNET
    $vlan_obj | Add-Member NoteProperty -Name subnetprefix -Value $subnetprefix # to create subnet
    $vlan_obj | Add-Member NoteProperty -Name ResourceGroup -Value $rg_name

    Write-Host "`t --- resource group name: $rg_name"
    Write-Host "`t --- vNet Name: $vnet_name"
    Write-Host "`t --- Address Space: $addressprefix"
        
    $vlan_obj


    $vNet = Get-AzVirtualNetwork -ResourceGroupName $rg_name -Name $vnet_name -ErrorAction SilentlyContinue
    #$vnet = $true
    if ($vNet){
        Write-Host "Adding Subnet [ $subnetname] to Vnet [$vnet_name] " -yellow

        # Verify if address space exist and create if not
        if (! $vNet.AddressSpace.AddressPrefixes.contains($addressprefix)){
            Write-Host "Creating Address Prefix [$addressprefix]"
            $vNet.AddressSpace.AddressPrefixes.add($addressprefix)
            Set-AzureRmVirtualNetwork -VirtualNetwork $vNet   
            $vNet = Get-AzVirtualNetwork -ResourceGroupName $rg_name -Name $vnet_name -ErrorAction SilentlyContinue
        }

        $subnetname = $vlan_obj.name.replace(" ","_")

        $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetname -ErrorAction SilentlyContinue

        if (! $subnet) {
            Add-AzVirtualNetworkSubnetConfig `
                -Name $subnetname `
                -AddressPrefix $subnetprefix `
                -VirtualNetwork $vNet
            Set-AzVirtualNetwork -VirtualNetwork $vNet
        # $cmd = "Add-AzVirtualNetworkSubnetConfig `
        #           -Name $subnetname `
        #           -AddressPrefix $subnetprefix `
        #           -VirtualNetwork $virtualNetwork"
        # Write-Host "Add Subnet: `n`t$cmd" -ForegroundColor Yellow
        # Invoke-Expression $cmd

        }
    }else{
        # Only run if VNET Does not exist
        Write-Host "Creating VNET : $vnet_name" -ForegroundColor Yellow  
        

        #Write-Host "Create VNET: `n`t$cmd"   -ForegroundColor Yellow     
        #Invoke-Expression $cmd
    
        ## before actually running this need to have the $VNET inside $virtualNetwork
        $subnetname = $vlan_obj.name
        # $cmd = "Add-AzVirtualNetworkSubnetConfig `
        #           -Name $subnetname `
        #           -AddressPrefix $subnetprefix `
        #           -VirtualNetwork $virtualNetwork"
        # Write-Host "Add Subnet: `n`t$cmd" -ForegroundColor Yellow
        # Invoke-Expression $cmd
        $subnet = New-AzVirtualNetworkSubnetConfig `
            -Name $subnetname `
            -AddressPrefix $subnetprefix `
            -VirtualNetwork $vNet

        $vNet = New-AzVirtualNetwork `
            -ResourceGroupName $rg_name `
            -Location EastUS `
            -Name $vnet_name `
            -AddressPrefix $addressprefix `
            -Subnet $subnet

    }
    

    $rpt += $vlan_obj    
}


#Write-Host "`t`t ---- Show Full Report ---" -ForegroundColor Green
#$rpt 