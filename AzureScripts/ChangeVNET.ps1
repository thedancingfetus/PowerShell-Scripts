function Write-Log
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$fileName, 
        [Parameter(Mandatory=$true)]
        [ValidateSet("Informational","Error")]
        [string]$type,
        [Parameter(Mandatory=$true)]
        [string]$message
    )    
    $workingDir = "$($env:USERPROFILE)\Documents\Azure\VNET Change\Logs\"
    $file = $workingDir+$fileName
    if($type -eq "Informational")
    {
        $string = "$(Get-Date -Format s)`t:`t$($type)`t:`t$($message)"
    }
    else
    {
        $string = "$(Get-Date -Format s)`t:`t$($type)`t`t:`t$($message)"
    }
    if(Get-Item -Path $workingDir)
    {
        Add-Content $file $string
    } 
    else
    {
        New-Item -Path $workingDir -ItemType directory
        Add-Content $file $string
    }   
}

function Change-VNET
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$vm, 
        [Parameter(Mandatory=$true)]
        [string]$vmRg,
        [Parameter(Mandatory=$true)]
        [string]$subscription,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$azureCred#,
        #[Parameter(Mandatory=$true)]
        #[string]$newNic,
        #[Parameter(Mandatory=$true)]
        #[string]$newNicRg
        
    )
    #Import required Modules
    Import-Module AzureRM.Profile
    Import-Module AzureRM.Compute
    #Set Logfile Name
    $logFile = "VNETChange_$($vm)_$($vmRg)_$((Get-Date -Format s).Replace(":","-")).txt"
    if($azureCred -ne $null)
    {
    #Login
        try
        {
            Write-Log -fileName $logFile -type Informational -message "Logging in to Azure Subscription"
            if($azureCred -ne $null)
            {
                $login = Add-AzureRmAccount -SubscriptionId $subscription -Credential $azureCred -EnvironmentName "AzureUSGovernment" -ErrorAction Stop
            }
            else
            {
                $login = Add-AzureAccount 
                Select-AzureRmSubscription -SubscriptionId $subscription
            }
            Write-Log -fileName $logFile -type Informational -message "[Complete] Log in to Azure Subscription [Complete]"
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-Log -fileName $logFile -type Error -message $ErrorMessage
        }    
    }
    #Creating VM Config
    Write-Log -fileName $logFile -type Informational -message "Getting $($vm) information"
    try
    {
        $azureVM = Get-AzureRmVM -ResourceGroupName $vmRg -Name $vm
        Write-Log -fileName $logFile -type Informational -message "VM Config:`n$($azureVM | ConvertTo-Json -Depth 100)"
        $OS = $azureVM.StorageProfile.OsDisk.OsType
        
        $VmConfig = New-AzureRmVMConfig -VMName $azureVM.Name -VMSize $azureVM.HardwareProfile.VmSize     
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }
    try
    {
        Set-AzureRmVMOSDisk -VM $VmConfig -Name $azureVM.StorageProfile.OsDisk.Name -VhdUri $azureVM.StorageProfile.OsDisk.Vhd.Uri -CreateOption Attach 
        $VmConfig.StorageProfile.OsDisk.OsType = $OS  
        #Looping Through Data Disks
        $luns = 0
        if($azureVM.StorageProfile.DataDisks.Count -gt 0)
        {
            Write-Log -fileName $logFile -type Informational -message "Looping through Other Disks $($azureVM.StorageProfile.OsDisk.Name) to VM Config"
            foreach($disk in $azureVM.StorageProfile.DataDisks)
            {
                Write-Log -fileName $logFile -type Informational -message "Adding Disk $($disk.Name) to VM Config"
                Add-AzureRmVMDataDisk -VM $VmConfig -Name $disk.Name -VhdUri $disk.Vhd.Uri -CreateOption Attach -DiskSizeInGB $null -Lun $luns.ToString()
                $luns++
            }  
        }
        #Looping Through Network Interfaces
        Write-Log -fileName $logFile -type Informational -message "Adding NICs to VM Config"
        <#foreach($interface in $azureVM.NetworkProfile.NetworkInterfaces)
        {
            $nicResource = Get-AzureRmResource -ResourceId $interface.Id
            $nic = Get-AzureRmNetworkInterface -Name $nicResource.Name -ResourceGroupName $nicResource.ResourceGroupName
            Write-Log -fileName $logFile -type Informational -message "Adding NIC $($nic.Name) to VM Config"
            Add-AzureRmVMNetworkInterface -VM $VmConfig -NetworkInterface $nic
        }#>
        $nic = Get-AzureRmNetworkInterface -Name $($azureVM.Name + "-new-nic") -ResourceGroupName $azureVM.ResourceGroupName
        Write-Log -fileName $logFile -type Informational -message "Adding NIC $($nic.Name) to VM Config"
        Add-AzureRmVMNetworkInterface -VM $VmConfig -NetworkInterface $nic
        Write-Log -fileName $logFile -type Informational -message "[Complete] Setting up new $($vm) deploy [Complete]"
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }

    #RemoveVM
    Write-Log -fileName $logFile -type Informational -message "Removing $($vm)"
    try
    {
        Stop-AzureRmVm -Name $azureVM.Name -ResourceGroupName $azureVM.ResourceGroupName -Force -ErrorAction Stop
        Remove-AzureRmVm -Name $azureVM.Name -ResourceGroupName $azureVM.ResourceGroupName -Force -ErrorAction Stop
        Write-Log -fileName $logFile -type Informational -message "[Complete] Removing $($vm) [Complete]"
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }    
    
    #Deploy New VM
    Write-Log -fileName $logFile -type Informational -message "Deploying:`n$($VmConfig | ConvertTo-Json -Depth 100)"
    try
    {
        if($azureVM.LicenseType -eq $null)
        {
            New-AzureRmVm -VM $VmConfig -ResourceGroupName $azureVM.ResourceGroupName -Location $azureVM.Location -Tags $azureVM.Tags
        }
        else
        {
            New-AzureRmVm -VM $VmConfig -ResourceGroupName $azureVM.ResourceGroupName -Location $azureVM.Location -Tags $azureVM.Tags -LicenseType $azureVM.LicenseType 
        }
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }
    Write-Log -fileName $logFile -type Informational -message "[Complete] Deploying $($vm) [Complete]"
}

