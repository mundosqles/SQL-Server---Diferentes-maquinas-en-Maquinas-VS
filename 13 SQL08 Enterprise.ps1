#
# sql08.ps1
# Edicion Enterprise
# WS2012R2
# http://www.mundosql.es/
#

Clear

# Datos GR
$rgName                = "SQL2008R2SP3-WS2008R2SP1"
$location              = "North Europe"

# Datos red
$vnetName              = "sql08red"
$vnetPrefix            = "10.0.8.0/16"
$subnetName            = "sql08subred"
$subnetPrefix          = "10.0.8.0/24"

# Datos almacenamiento
$stdStorageAccountName = "sql08alma"

# Datos VM
$vmSize                = "Standard_D2_v2" #7GB 2Nic
#$vmSize               = "Standard_D3_v2" #14GB 4Nic
$diskSize              = 150
$publisher             = "MicrosoftSQLServer"
$offer                 = "SQL2008R2SP3-WS2008R2SP1"
$sku                   = "Enterprise"
$version               = "latest"
$vmName                = "sql08vm"
$osDiskName            = "osdisk"
$nicName               = "sql08nic"
$privateIPAddress      = "10.0.8.8"
$pipName               = "sql08ip"
$dnsName               = "sql08dns"
          
Write-Host("Desplegando Grupo de Recursos ... SQL2008R2SP3-WS2008R2SP1") 

# Inicio despliegue
$ini = get-date

# Crea GR
Write-Host("Creacion GR") -ForegroundColor Yellow
New-AzureRmResourceGroup -Name $rgName -Location $location

# Crea redes
Write-Host("Configuracion de las Redes") -ForegroundColor Yellow
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName `
    -AddressPrefix $vnetPrefix -Location $location   
Add-AzureRmVirtualNetworkSubnetConfig -Name $subnetName `
    -VirtualNetwork $vnet -AddressPrefix $subnetPrefix
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet 

# Crea Ip Publica
Write-Host("Configuracion de Ip Publica") -ForegroundColor Yellow
$pip = New-AzureRmPublicIpAddress -Name $pipName -ResourceGroupName $rgName `
    -AllocationMethod Static -DomainNameLabel $dnsName -Location $location

# Crea NIC
Write-Host("Configuracion de Nic Externa") -ForegroundColor Yellow
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName `
    -Subnet $subnet -Location $location -PrivateIpAddress $privateIPAddress `
    -PublicIpAddress $pip

# Crea almacenmiento
Write-Host("Configuracion de Almacenamiento") -ForegroundColor Yellow
$stdStorageAccount = New-AzureRmStorageAccount -Name $stdStorageAccountName `
    -ResourceGroupName $rgName -Type Standard_LRS -Location $location
    
# Crea VM
Write-Host("Configuracion de Maquina Virtual") -ForegroundColor Yellow
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize 
    
# Credentiales, OS e Imagen
Write-Host("Configuracion de Credentiales, OS e Imagen") -ForegroundColor Yellow
$cred = Get-Credential -Message "Meter datos administrador local"
$vmConfig = Set-AzureRmVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName `
    -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vmConfig = Set-AzureRmVMSourceImage -VM $vmConfig -PublisherName $publisher `
    -Offer $offer -Skus $sku -Version $version

# Vhd
Write-Host("Configuracion de Vhd") -ForegroundColor Yellow
$osVhdUri = $stdStorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $osDiskName + ".vhd"
$vmConfig = Set-AzureRmVMOSDisk -VM $vmConfig -Name $osDiskName -VhdUri $osVhdUri -CreateOption fromImage

# NIC interna
Write-Host("Configuracion de NIC interna") -ForegroundColor Yellow
$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $nic.Id -Primary

# Crea VM
Write-Host("Configuracion de Maquina Virtual") -ForegroundColor Yellow
New-AzureRmVM -VM $vmConfig -ResourceGroupName $rgName -Location $location

#Fin desliegue
$fin = get-date

# Para VM
Write-Host("Parar maquina") -ForegroundColor Yellow
Stop-AzureRmVM -ResourceGroupName $rgName -Name $vmName -Force

# Grupo Seguridad
Write-Host("Configuracion de Grupo Seguridad") 
$regla3389 = New-AzureRmNetworkSecurityRuleConfig -Name "regla3389" -Description "Regla 3389" `
			-Protocol Tcp -SourcePortRange * -DestinationPortRange 3389 -SourceAddressPrefix * -DestinationAddressPrefix * `
			-Access Allow -Priority 100 -Direction Inbound
$nsg = New-AzureRmNetworkSecurityGroup -Name sql08seg -ResourceGroupName $rgName -Location $location -SecurityRules $regla3389
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName 
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName -AddressPrefix $subnetPrefix  -NetworkSecurityGroup $nsg
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

# Control tiempo despliegue - Inicio
$fin = get-date
Write-Host("Inicio Despliegue SQL2008R2SP3-WS2008R2SP1: ",$ini) -ForegroundColor Magenta
Write-Host("Fin Despliegue SQL2008R2SP3-WS2008R2SP1:    ",$fin) -ForegroundColor Magenta

Write-Host("Grupo de Recursos sql08 .... Listo") 
