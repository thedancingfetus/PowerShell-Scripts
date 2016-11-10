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
    $workingDir = "$($env:USERPROFILE)\Documents\Azure\Availability Set Change\Logs\"
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

function Update-AzureRmVmAvailabilitySet 
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$vm, 
        [Parameter(Mandatory=$true)]
        [string]$vmRg, 
        [Parameter(Mandatory=$true)]
        [string]$AvailabilitySet, 
        [switch]$createNew,
        [string]$asRg,
        [string]$subscription,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$cred=(Get-Credential)
    )
    #Import required Modules
    Import-Module AzureRM.Profile
    Import-Module AzureRM.Compute
    #Set Logfile Name
    $logFile = "$($AvailabilitySet)_$($vm)_$($vmRg)_$((Get-Date -Format s).Replace(":","-")).txt"

    #Login
    try
    {
        Write-Log -fileName $logFile -type Informational -message "Logging in to Azure Subscription"
        if($subscription.Length -ne 0)
        {
            $login = Add-AzureRmAccount -SubscriptionId $subscription -Credential $cred -ErrorAction Stop
        }
        else
        {
            $login = Add-AzureAccount -Credential $cred -ErrorAction Stop
        }
        Write-Log -fileName $logFile -type Informational -message "[Complete] Log in to Azure Subscription [Complete]"
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }    

    #Creating VM Config
    Write-Log -fileName $logFile -type Informational -message "Getting $($vm) information"
    try
    {
        $azureVM = Get-AzureRmVM -ResourceGroupName $vmRg -Name $vm
        Write-Log -fileName $logFile -type Informational -message "VM Config:`n$($azureVM | ConvertTo-Json -Depth 100)"
        $OS = $azureVM.StorageProfile.OsDisk.OsType
        #Get/Create Availability Set
        Write-Log -fileName $logFile -type Informational -message "Getting $($AvailabilitySet) information"
        try
        {
            if($asRg.Length -eq 0)
            {
                $as = Get-AzureRmAvailabilitySet -ResourceGroupName $vmRg -Name $AvailabilitySet -ErrorAction SilentlyContinue
            }
            else
            {
                $as = Get-AzureRmAvailabilitySet -ResourceGroupName $asRg -Name $AvailabilitySet -ErrorAction SilentlyContinue
            }
            if($as -eq $null -and $createNew -eq $true)
            {
                if($asRg.Length -eq 0)
                {
                    New-AzureRmAvailabilitySet -ResourceGroupName $vmRg -Name $AvailabilitySet -Location $azureVM.Location
                    $as = Get-AzureRmAvailabilitySet -ResourceGroupName $vmRg -Name $AvailabilitySet -ErrorAction SilentlyContinue
                }
                else
                {
                    New-AzureRmAvailabilitySet -ResourceGroupName $asRg -Name $AvailabilitySet -Location $azureVM.Location
                    $as = Get-AzureRmAvailabilitySet -ResourceGroupName $asRg -Name $AvailabilitySet -ErrorAction SilentlyContinue
                }
            } 
            elseif ($as -eq $null -and $createNew -eq $false)
            {
                Write-Log -fileName $logFile -type Error -message "Could not get $($AvailabilitySet) information and Create New was not selected"
                Throw "No Availability Set is available - Name: $($AvailabilitySet), ResourceGroup: $($vmRg)"       
            }
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-Log -fileName $logFile -type Error -message $ErrorMessage
        }
        $VmConfig = New-AzureRmVMConfig -VMName $azureVM.Name -VMSize $azureVM.HardwareProfile.VmSize -AvailabilitySetId $as.id
        Write-Log -fileName $logFile -type Informational -message "[Complete] Getting $($vm) information [Complete]"
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }

    #Configuring for New Deploy
    Write-Log -fileName $logFile -type Informational -message "Setting up new $($vm) deploy"
    try
    {
        Write-Log -fileName $logFile -type Informational -message "Attaching OS Disk $($azureVM.StorageProfile.OsDisk.Name) to VM Config"
        Set-AzureRmVMOSDisk -VM $VmConfig -Name $azureVM.StorageProfile.OsDisk.Name -VhdUri $azureVM.StorageProfile.OsDisk.Vhd.Uri -CreateOption Attach  
        $VmConfig.StorageProfile.OsDisk.OsType = $OS  
        #Looping Through Data Disks
        if($azureVM.DataDiskNames.Count -gt 0)
        {
            Write-Log -fileName $logFile -type Informational -message "Looping through Other Disks $($azureVM.StorageProfile.OsDisk.Name) to VM Config"
            foreach($disk in $azureVM.StorageProfile.DataDisks)
            {
                Write-Log -fileName $logFile -type Informational -message "Adding Disk $($disk.Name) to VM Config"
                Add-AzureRmVMDataDisk -VM $VmConfig -Name $disk.Name -VhdUri $disk.Vhd.Uri -CreateOption Attach -DiskSizeInGB $null
            }  
        }
        #Looping Through Network Interfaces
        Write-Log -fileName $logFile -type Informational -message "Adding NICs to VM Config"
        foreach($interface in $azureVM.NetworkProfile.NetworkInterfaces)
        {
            $nicResource = Get-AzureRmResource -ResourceId $interface.Id
            $nic = Get-AzureRmNetworkInterface -Name $nicResource.Name -ResourceGroupName $nicResource.ResourceGroupName
            Write-Log -fileName $logFile -type Informational -message "Adding NIC $($nic.Name) to VM Config"
            Add-AzureRmVMNetworkInterface -VM $VmConfig -NetworkInterface $nic
        }
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
        New-AzureRmVm -VM $VmConfig -ResourceGroupName $azureVM.ResourceGroupName -Location $azureVM.Location -Tags $azureVM.Tags 
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Log -fileName $logFile -type Error -message $ErrorMessage
    }
    Write-Log -fileName $logFile -type Informational -message "[Complete] Deploying $($vm) [Complete]"
}
    