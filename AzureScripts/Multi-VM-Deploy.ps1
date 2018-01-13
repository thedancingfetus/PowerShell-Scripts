Import-Module AzureRM.Profile
Import-Module AzureRM.Compute
Import-Module AzureRM.Network

$vms = @()
<#Ubuntu
    publisher = "Canonical"
	offer = "UbuntuServer"
	sku = "16.04-LTS"
	version = "16.04.201710110"
#>
<#Windows 2012 R2
	publisher = "MicrosoftWindowsServer"
	offer = "WindowsServer"
	sku = "2012-R2-Datacenter"
	version = "4.127.20170510"

Example VM Object:
$vms +=New-Object -TypeName psobject -Property @{
	vmname = "US3AZCONF01"                              Name of VM
	vmRg = "AppGrp-Placeholder-Prod-rg"                 Name of VM Resource Group
    avset = "US3AZCONF"                                 Name of Availability Set (can be $null)
	subnetName = "610_Management_srvcs_eastus2"         Name of Subnet
	vmSize = "Standard_E4_v3"                           VM Size
	publisher = "Canonical"                             Publisher of Market Place Image
	offer = "UbuntuServer"                              Offer of Market Place Image
	sku = "16.04-LTS"                                   Sku of Market Place Image
	version = "16.04.201710110"                         Version of Market Place Image
    managed = $true                                     Does it use Managed disks? $true or $false
	storageAccount = ""                                 If managed = $false put in storage account name
	storageAccountRg = ""                               If managed = $false Resource Group of Storage Account
	azrCred = New-Object System.Management.Automation.PSCredential("[UserName of Azure Admin]", (ConvertTo-SecureString "[Password of Azure Admin]" -AsPlainText -Force))   
	localCred = New-Object System.Management.Automation.PSCredential("[Default Admin on the VM Username]", (ConvertTo-SecureString "[Default Admin on the VM Password]" -AsPlainText -Force))
	subscriptionId = "[Subscription ID of the Subscription you are deploying to]"     
	cloud = "AzureCloud"                                Type of Cloud, can be AzureCloud or AzureUSGovernment
	vnetName = "vnet_services_eastus2"                  Name of Virtual Network
	vnetRg = "rg_vnet_services_eastus2"                 Virtual Network Resource Group
    region = "eastus2"                                  Region you are deploying
    tags = @{"Deployed By"="AirNet Group Inc.";"Application"="Specimen Gate Lab"}   Tags that will be on VMs
    disks = @()                                         Additional Datadisks Object format below
    os = "linux"}                                       OS Windows or Linux

    Disk Object formation
    New-Object -TypeName psobject -Property @{
        name = "US3AZCONF01-datadisk0"
        container = ""
        sizeGB = 2047
    }

    Within the vm 
#>

function Deploy($vm)
{
    Import-Module AzureRM.Profile
    Import-Module AzureRM.Compute
    Import-Module AzureRM.Network

	Add-AzureRmAccount -Environment $vm.cloud -Credential $vm.azrCred -Subscription $vm.subscriptionId
	$vnet = Get-AzureRmVirtualNetwork -Name $vm.vnetName -ResourceGroupName $vm.vnetRg
    if($vm.managed -eq $false)
    {
        $storageAccount = Get-AzureRmStorageAccount -Name $vm.storageAccount -ResourceGroupName $vm.storageAccountRg
	    $container = Get-AzureStorageContainer -Name vhds -Context $storageAccount.Context
    }
    if($vm.avSet -ne $null -and $vm.avSet -ne "")
    {
        $aSet = Get-AzureRmAvailabilitySet -ResourceGroupName $vm.vmRg -Name $vm.avSet  
        $vmConfig = New-AzureRmVMConfig -VMName $vm.vmname -VMSize $vm.vmSize -AvailabilitySetId $aSet.Id  
    }
    else
    {        
	    $vmConfig = New-AzureRmVMConfig -VMName $vm.vmname -VMSize $vm.vmSize
    }
    if($vm.os -eq "windows")
    {
        Set-AzureRmVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vm.vmname -Credential $vm.localCred -ProvisionVMAgent
    }
	else
    {
        Set-AzureRmVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vm.vmname -Credential $vm.localCred 
    } 
	Set-AzureRmVMSourceImage -VM $vmConfig -PublisherName $vm.publisher -Offer $vm.offer -Skus $vm.sku -Version $vm.version
    if($vm.managed -eq $false)
    {
	    Set-AzureRmVMOSDisk -VM $vmConfig -Name $($vm.vmname + "-OS") -VhdUri $($container.CloudBlobContainer.Uri.AbsoluteUri + "/" + $vm.vmname + "-OS.vhd") -CreateOption FromImage
    }
    else
    {
        Set-AzureRmVMOSDisk -VM $vmConfig -Name $($vm.vmname + "-OS") -StorageAccountType StandardLRS -CreateOption FromImage
    }
	$nic = Get-AzureRmNetworkInterface -Name $($vm.vmname + "-nic") -ResourceGroupName $vm.vmRg
	if($nic -eq $null)
    {
        $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $vm.subnetName -VirtualNetwork $vnet
		$nic = New-AzureRmNetworkInterface -Name $($vm.vmname + "-nic") -ResourceGroupName $vm.vmRg -Subnet $subnet -Location $vm.region
    }    
    $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
    Set-AzureRmNetworkInterface -NetworkInterface $nic
	Add-AzureRmVMNetworkInterface -VM $vmConfig -NetworkInterface $nic
    $lun = 0
    foreach($disk in $vm.disks)
    {
        if($vm.managed -eq $false)
        {
            $storageAccount = Get-AzureRmStorageAccount -Name $vm.storageAccount -ResourceGroupName $vm.storageAccountRg
            $diskContainer = Get-AzureStorageContainer -Name $disk.container -Context $storageAccount.Context       
            if($diskContainer -eq $null)
            {
                $diskContainer = New-AzureStorageContainer -Name $disk.container -Context $storageAccount.Context
            }
            Add-AzureRmVMDataDisk -VM $vmConfig -Name $disk.name -VhdUri $($diskContainer.CloudBlobContainer.Uri.AbsoluteUri + "/" + $disk.name + ".vhd") -DiskSizeInGB $disk.sizeGB -CreateOption Empty -Lun $lun
        } 
        else
        {
            Add-AzureRmVMDataDisk -VM $vmConfig -Name $disk.name -DiskSizeInGB $disk.sizeGB -StorageAccountType StandardLRS -CreateOption Empty -Lun $lun
        }
        $lun++
    }  
	New-AzureRmVm -ResourceGroupName $vm.vmRg -Location $vm.region -VM $vmConfig -Tags $vm.tags 
}

function Stop($vm)
{
    Import-Module AzureRM.Profile

    Add-AzureRmAccount -EnvironmentName $vm.cloud -Credential $vm.azrCred -SubscriptionId $vm.subscriptionId
    Stop-AzureRmVM -Name $vm.vmname -ResourceGroupName $vm.vmRg -Force
}

foreach ($vm in $vms)
{
    $provider = Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Storage
    if($provider[0].RegistrationState -eq "NotRegistered")
    {
        Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Storage
    }
    Add-AzureRmAccount -Environment $vm.cloud -Credential $vm.azrCred -Subscription $vm.subscriptionId
    $vmRg = Get-AzureRmResourceGroup -Name $vm.vmRg -Location $vm.region
    if($vmRg -eq $null)
    {
        New-AzureRmResourceGroup -Name $vm.vmRg -Location $vm.region -Tag $vm.tags
    }
    if($vm.managed -eq $false)
    {
	    $storageAccount = Get-AzureRmStorageAccount -Name $vm.storageAccount -ResourceGroupName $vm.storageAccountRg

        if($storageAccount -eq $null)
        {
            $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $vm.storageAccountRg -Name $vm.storageAccount -SkuName Standard_LRS -Location $vm.region -Kind Storage -Tag $vm.tags
        }
        $container = Get-AzureStorageContainer -Name vhds -Context $storageAccount.Context
	    if($container -eq $null)
	    {
		    $container = New-AzureStorageContainer -Name vhds -Context $storageAccount.Context 
	    }
    }
    if($vm.avSet -ne "" -and $vm.avSet -ne $null)
    {
        $aSet = Get-AzureRmAvailabilitySet -ResourceGroupName $vm.vmRg -Name $vm.avSet
        if($aSet -eq $null)
        {
            if($vm.managed -eq $false)
            {
                New-AzureRmAvailabilitySet -ResourceGroupName $vm.vmRg -Name $vm.avSet -Location $vm.region -Sku Classic -PlatformFaultDomainCount 3 -PlatformUpdateDomainCount 5
            }
            else
            {
                New-AzureRmAvailabilitySet -ResourceGroupName $vm.vmRg -Name $vm.avSet -Location $vm.region -Sku Aligned -PlatformFaultDomainCount 3 -PlatformUpdateDomainCount 5
            }
        }
    }
	Start-Job -ScriptBlock ${function:Deploy} -ArgumentList $vm
}

Get-Job | Wait-Job
Get-Job | Remove-Job


foreach ($vm in $vms)
{
    Start-Job -ScriptBlock ${function:Stop} -ArgumentList $vm
}
Get-Job | Wait-Job
Get-Job | Remove-Job
