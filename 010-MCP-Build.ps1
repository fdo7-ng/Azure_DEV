
$location = 'eastus'

$cnd_file = "./output/cloud_network_domains.json"
$cnd_data = Get-Content $cnd_file | ConvertFrom-JSON 

# Section to deploy resource groups
foreach ($itm in $cnd_data.data.network_domain){

    Write-host  "$($itm.Name)"
    Write-host  "$($itm.description)"

    $rgName = "rg_" + $itm.Name

    # Create a resource group.
    Write-Host "Creating Resource Group [ $rgName]" -ForegroundColor Magenta
    if (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue){
        Write-Host "`t[ $rgName] resource group found" -ForegroundColor Yellow
    }else{
        Write-Host "`t[ $rgName] creating resource group" -ForegroundColor Green
        New-AzResourceGroup -Name $rgName -Location $location
}
}
