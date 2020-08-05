#param($rgname, $location, $subscriptionName)
#connect-azaccount   
#Network source Data

$rgname = "fd-RG0"
$location = "eastus2"
$subscriptionName = "azure-subscription-devtest"

$sub = Get-AzSubscription | where{$_.name -like $subscriptionName}
select-azsubscription $sub

$vlans_file = "output/vlans_Advanced_POC.json"
$vlans_Json = (get-content $vlans_file) | convertfrom-json
$vlans = $vlans_Json.data.vlan

$firewall_file = "output/firewall_Advanced_POC.json"
$firewall_Json = (get-content $firewall_file) | convertfrom-json
$firewall = $firewall_json.data.acl | where{$_.ipVersion -eq "IPv4"}

#$defaultRules = $firewall | where{$_.ruleType -eq"DEFAULT_RULE"}
$clientRules = $firewall #| where {$_.ruletype -eq "CLIENT_RULE"}
$defaultRule = New-AzNetworkSecurityRuleConfig -Name DENY-ALL -Description "Deny All" -Access Deny -Protocol Tcp -Direction Inbound -Priority 4096 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *

foreach($vlan in $vlans)
{
    $netDomName = $vlan.networkDomain.name
    $ipv4prefix = $vlan.privateIpv4Range.prefixSize
    $subnet = $vlan.name
    $ipv4range = $vlan.privateipv4range.address
    $addressPrefix = $ipv4range+"/"+$ipv4prefix
    $chunks = $ipv4range.split(".")
    $ipchunks = $chunks[0]+"."+$chunks[1]+"."+$chunks[2]
    $priority = 1000

    
    write-host("Getting vNet by name: ",$netDomName)
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgname -name $netDomName -erroraction silentlycontinue
    $nsgname = $vlan.name +"-NSG"
    write-host("NSG Name: ", $nsgname)
    #sleep 15
    # Create vNet and SubNets
    if(!$vnet)
    {
        write-host("Creating new vNet: ", $netDomName)
        $networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $rgname -Location $location -Name $nsgname -SecurityRules $defaultRule
        write-host("Creating Security Group: ", $networkSecurityGroup.name)
        $newnet = new-AzVirtualNetworkSubnetConfig -name $vlan.name -addressprefix $addressPrefix -NetworkSecurityGroup $networkSecurityGroup
        $vNet = new-azvirtualNetwork -ResourceGroupName $rgname -Location $location -name $netDomName -AddressPrefix $addressPrefix -subnet $newnet
        $vnet | set-azvirtualnetwork
        #Create rules associated with the new vNet
        foreach($rule in $clientRules){
            write-host("Checking Rule to Network Security Group: ", $vlan.name)
            write-host("Rule IP: ",$rule.destination.ip.address)
            write-host("Subnet IP: ", $ipchunks)
            sleep 5
            if($rule.destination.ip.address -like $ipchunks+"*"){
                write-host("Rule Matched, adding rule: ",$rule.name, "To: ",$nsgname)

                if($rule.action -eq "ACCEPT_DECISIVELY"){
                    $action = "ALLOW"
                }else{
                    $action = "DENY"
                }

                if($rule.source.ip.address -eq "ANY"){
                    $sourceaddress = "*"
                }else{
                    $sourceaddress = $rule.source.ip.address
                }

                
                if($rule.destination.ip.address -eq "ANY"){
                    $destinationaddress = "*"
                }else{
                    $destinationaddress = $rule.destination.ip.address
                }

                if($rule.destination.port.begin -eq "ANY"){
                    $destinationport = "*"
                }else{
                    $destinationport = $rule.destination.port.begin
                }


                $nsg =  Get-AzNetworkSecurityGroup -Name $nsgname -ResourceGroupName $rgname 
                $newrule = Add-AzNetworkSecurityRuleConfig -Name $rule.name  -Access $action -direction inbound -priority $priority -Protocol Tcp -SourceAddressPrefix $sourceaddress -SourcePortRange * -DestinationAddressPrefix $destinationaddress -DestinationPortRange $destinationport -NetworkSecurityGroup $nsg
                $newrule | Set-AzNetworkSecurityGroup
                $priority++

            }

            if($rule.source.ip.address -like $ipchunks+"*"){
                write-host("Rule Matched, adding rule: ",$rule.name, "To: ",$nsgname)

                if($rule.action -eq "ACCEPT_DECISIVELY"){
                    $action = "ALLOW"
                }else{
                    $action = "DENY"
                }

                if($rule.source.ip.address -eq "ANY"){
                    $sourceaddress = "*"
                }else{
                    $sourceaddress = $rule.source.ip.address
                }

                if($rule.source.port.begin -eq "ANY"){
                    $sourceport = "*"
                }else{
                    $sourceport = $rule.source.port.begin
                }

                if($rule.destination.ip.address -eq "ANY"){
                    $destinationaddress = "*"
                }else{
                    $destinationaddress = $rule.destination.ip.address
                }

                if($rule.destination.port.begin -eq "ANY"){
                    $destinationport = "*"
                }else{
                    $destinationport = $rule.destination.port.begin
                }

                $nsg =  Get-AzNetworkSecurityGroup -Name $nsgname -ResourceGroupName $rgname 
                $newrule = Add-AzNetworkSecurityRuleConfig -Name $rule.name  -Access $action -direction outbound -priority $priority -Protocol Tcp -SourceAddressPrefix $sourceaddress -SourcePortRange * -DestinationAddressPrefix $destinationaddress -DestinationPortRange $destinationport -NetworkSecurityGroup $nsg
                $newrule | Set-AzNetworkSecurityGroup
                $priority++

            }



        }
        

    }Else{
       #Create new rules to an existing SubNet     
       write-host ("Adding new IP PRefix to: ",$addressPrefix, " to vNet: ", $netDomName )
       write-host ("Adding new subnet ",$vlan.name, " to vNet: ", $netDomName )
       $vnet.AddressSpace.AddressPrefixes.Add($addressPrefix)
       $networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $rgname -Location $location -Name $nsgname -SecurityRules $defaultRule
       Add-AzVirtualNetworkSubnetConfig -name $vlan.name -addressprefix $addressPrefix -virtualnetwork $vnet -NetworkSecurityGroup $networkSecurityGroup
       $vnet | set-azvirtualnetwork

       foreach($rule in $clientRules){
        write-host("Adding Rule to Network Security Group: ", $vlan.name)
            write-host("Rule IP: ",$rule.destination.ip.address)
            write-host("Subnet IP: ", $ipchunks)
            sleep 5
         if($rule.destination.ip.address -like $ipchunks+"*"){
                write-host("Rule Matched, adding rule: ",$rule.name, "To: ",$nsgname)
            if($rule.action -eq "ACCEPT_DECISIVELY"){
                $action = "ALLOW"
            }else{
                $action = "DENY"
            }

            if($rule.source.ip.address -eq "ANY"){
                $sourceaddress = "*"
            }else{
                $sourceaddress = $rule.source.ip.address
            }

            if($rule.source.port.begin -eq "ANY"){
                $sourceport = "*"
            }else{
                $sourceport = $rule.source.port.begin
            }

            if($rule.destination.ip.address -eq "ANY"){
                $destinationaddress = "*"
            }else{
                $destinationaddress = $rule.destination.ip.address
            }

            if($rule.destination.port.begin -eq "ANY"){
                $destinationport = "*"
            }else{
                $destinationport = $rule.destination.port.begin
            }


            $nsg =  Get-AzNetworkSecurityGroup -Name $nsgname -ResourceGroupName $rgname 
            $newrule = Add-AzNetworkSecurityRuleConfig -Name $rule.name  -Access $action -direction inbound -priority $priority -Protocol Tcp -SourceAddressPrefix $sourceaddress -SourcePortRange * -DestinationAddressPrefix $destinationaddress -DestinationPortRange $destinationport -NetworkSecurityGroup $nsg
            $newrule | Set-AzNetworkSecurityGroup
            $priority++
        }

            if($rule.source.ip.address -like $ipchunks+"*"){
                write-host("Rule Matched, adding rule: ",$rule.name, "To: ",$nsgname)

                if($rule.action -eq "ACCEPT_DECISIVELY"){
                    $action = "ALLOW"
                }else{
                    $action = "DENY"
                }

                if($rule.source.ip.address -eq "ANY"){
                    $sourceaddress = "*"
                }else{
                    $sourceaddress = $rule.source.ip.address
                }

                if($rule.source.port.begin -eq "ANY"){
                    $sourceport = "*"
                }else{
                    $sourceport = $rule.source.port.begin
                }

                if($rule.destination.ip.address -eq "ANY"){
                    $destinationaddress = "*"
                }else{
                    $destinationaddress = $rule.destination.ip.address
                }

                if($rule.destination.port.begin -eq "ANY"){
                    $destinationport = "*"
                }else{
                    $destinationport = $rule.destination.port.begin
                }

                $nsg =  Get-AzNetworkSecurityGroup -Name $nsgname -ResourceGroupName $rgname 
                $newrule = Add-AzNetworkSecurityRuleConfig -Name $rule.name  -Access $action -direction outbound -priority $priority -Protocol Tcp -SourceAddressPrefix $sourceaddress -SourcePortRange * -DestinationAddressPrefix $destinationaddress -DestinationPortRange $destinationport -NetworkSecurityGroup $nsg
                $newrule | Set-AzNetworkSecurityGroup
                $priority++

            }




    }
    }



}

###. Create Bastion Host Subnet
write-host("Creating AzureBastionSubnet now: ")
$vnet.AddressSpace.AddressPrefixes.add("192.168.1.0/27")
add-AzVirtualNetworkSubnetConfig -name AzureBastionSubnet -AddressPrefix "192.168.1.0/27" -virtualnetwork $vnet
$vnet | set-azvirtualnetwork

####. Create Basiton Host
write-host("Creating Basiton host")
$bastionName = $vlan.networkDomain.name + "-BasitonHost"
$publicip = New-AzPublicIpAddress -ResourceGroupName $rgname -name "BastionHostPublicIP" -location $location -AllocationMethod Static -Sku Standard
#$bastionSubnet = Get-AzureRMVirtualNetworkSubnetConfig -VirtualNetwork $vnet -name "AzureBastionSubnet"
write-host("vNet name: ") $vnet.name
$bastion = New-AzBastion -asjob -ResourceGroupName $rgname -Name $bastionName -PublicIpAddress $publicip -VirtualNetwork $vnet

sleep 10


$server_file = 'F:\AzureTools\servers.json'
$server_data = Get-Content $server_file | ConvertFrom-JSON 
$server_count = $server_data.data.count
$server_list = $server_data.data.server

# Configure destroy parameter to delete network interface created by this script ($true|$false)
$destroy = $false
# Code Section
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgname -Name $vlans[0].networkDomain.name
foreach ($vm in $server_list){
    $vmname = $vm.name
    $vmNicName = $vmname + "-nic0"
    $primaryNIC = $vm.networkInfo.primaryNIC
    $vlanName = $vm.networkInfo.primaryNIC.vlanName
    $privateIpv4 = $primaryNIC.privateIpv4
    Write-Host "Server Name: " $vmname
    Write-Host " --- vlanName: " $vlanName
    Write-Host " --- Primary Nic IP: " $privateIpv4
    $network_interface = Get-AzNetworkInterface -ResourceGroupName $rgname -Name $vmNicName -ErrorAction SilentlyContinue
    if($network_interface) {
        Write-Host " --- Found network interface - " $vmNicName -ForegroundColor Green
    }else{
        Write-Host " --- Creating network interface - " $vmNicName -ForegroundColor Yellow
        #$selectedSubnet = $vnet | where{$_.name -eq }
        $subnetID = (Get-AzVirtualNetworkSubnetConfig -Name $vlanName -VirtualNetwork $vnet).id
        New-AzNetworkInterface -Name $vmNicName -ResourceGroupName $rgname -Location $location -SubnetId $subnetID -PrivateIpAddress $privateIpv4 | Out-Null
    }
    if ($destroy){
        Write-Host " --- Destroy network interface - "  $vmNicName -ForegroundColor Red
        $network_interface | Remove-AzNetworkInterface -Force -Confirm:$false
    }
}




