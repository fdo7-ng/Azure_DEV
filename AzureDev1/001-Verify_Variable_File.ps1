# 001 Verify Variable File

$var_file = "./variable.ps1"

if (Test-Path $var_file -ErrorAction SilentlyContinue){
    Write-Host $var_file + " : Found"
    . $var_file
}else{
    Write-Host $var_file + " : Not Found"
}

Write-Host "`n`n"
Write-Host "ResourceGroup Name: $resourceGroupName" -ForegroundColor Green
Write-Host "Resrouce Group location: $location" -ForegroundColor Green
Write-Host "Storage Account: $storageAccountName" -ForegroundColor Green
Write-Host "`n`n"


# Create Resource Group
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if ($resourceGroup){
    Write-Host $resourceGroup + ": Found"
}else{
    Write-Host "Creating Resource Group [" $resourceGroupName "] " -ForegroundColor Yellow
    $resourceGroup =   New-AzResourceGroup -Name $resourceGroupName -Location $location
}


# Create the storage account.
$storageAccount = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($storageAccount){
    Write-Host $storageAccountName + ": Found"
}else{
    Write-Host "Creating storage account [ " $storageAccountName " ]" -ForegroundColor Yellow
    $storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName `
        -Name $storageAccountName `
        -Location $location `
        -SkuName "Standard_LRS"
}


