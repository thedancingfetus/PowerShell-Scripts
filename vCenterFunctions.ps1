############### Check-vSphereFIPinning ###############
#	This Function may not work for every config.	 #
#	In my UCS Environment vNICs that are pinned 	 #
#	to FI A have a Mac in the like 00:00:00:ba:00:00 #
#	and FI B is like 00:00:00:bb:00:00. 			 #
#	Requires PowerCLI Installed						 #
######################################################

# Ex: Check-vSphereFIPinning -vCenters @("vCenter1","vCenter2") -cred (Get-Credential)
function Check-vSphereFIPinning ($vCenters, $cred) 
{
    Import-Module VMware.VimAutomation.SDK
    Import-Module VMware.VimAutomation.Core
    $misConfig = @()
    foreach ($vCenter in $vCenters)
    {
		Write-Host "Connecting to vCenter:" $vCenter
        Connect-VIServer -Server $vCenter -Credential $cred
        $clusters = Get-Cluster 
        foreach($cluster in $clusters)
        {
			Write-Host "Checking Cluster" $cluster.Name
			$vmHosts = (Get-VMHost -Location $cluster | Where-Object Manufacturer -eq "Cisco Systems Inc" | Where-Object Model -NotLike "UCSC*").Name #Getting the Name of all hosts that are Cisco, but ignoring C-Series hosts
			foreach ($vmHost in $vmHosts)
			{
				Write-Host "Checking Host" $vmHost
				$vSwitches = Get-VirtualSwitch -VMHost $vmHost
				foreach ($vSwitch in $vSwitches)
				{
					$mac = @()
					$vmNics = Get-VMHostNetworkAdapter -VirtualSwitch $vSwitch | Where-Object Name -like "vmnic*"                
					foreach ($vmNic in $vmNics)
					{
						$mac += ($vmNic.Mac -split ":")[3] 
					}
					$mac = $mac | select -Unique
					if($mac[1].Length -eq 1)
					{
						Write-Host "Pinning issue Detected:" $vSwitch
						$misConfig += New-Object -TypeName psobject -Property @{
							Cluster = $cluster.Name
							VMhost = $vmHost
							vSwitch = $vSwitch
						}
					}
				}
			}       
		}
		Disconnect-VIServer -Server $vCenter -Force -Confirm:$false
    }
    return $misConfig #returns all Mis-Configured hosts
}