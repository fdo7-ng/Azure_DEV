
$subnet_name = 'Advanced_POC'

$cnd_file = './output/cloud_network_domains.json'
$cnd_data = Get-Content $cnd_file | ConvertFrom-JSON 
$cnd_list = $cnd_data.data.network_domain
$cnd_count  = $cnd_data.data.count

foreach ($cnd in $cnd_list){

    Write-Host "Network Domain Name [ $($cnd.Name) ]"
    Write-Host "`t---Id: $($cnd.Id)"
    Write-Host "`t---datacenterId: $($cnd.datacenterId)"
    Write-Host "`t---Type: $($cnd.type)"
}

Write-Host "Searching for match" -ForegroundColor Yellow
$cnd_list | ? {$_.Name -eq $subnet_name}