function Set-AzureAuthToken ($creds, $subscriptionId)
{
    Add-AzureRmAccount -SubscriptionId $subscriptionId -Credential $creds
}

function Get-MyCred ($user)
{
    $file = "C:\MyPass.txt"
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $file | ConvertTo-SecureString)
    return $cred
}

function Update-MyCred ($pass)
{
    $pass | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "C:\MyPass.txt"
    Write-Host "Updated"
}

function Start-AzureVMs
{

	$userName = "" #username
	$cred = Get-MyCred -user $userName
	$resourceGroup = "" #ResourceGroup the VMs are in
    
	$azureSubscriptionId = "" # subscriptionId
    Add-AzureRmAccount -SubscriptionId $azureSubscriptionId -Credential $cred
    $vms = Get-AzureRmVm -ResourceGroupName $resourceGroup

	foreach($vm in $vms)
	{
		$scriptBlock = {
            Import-Module AzureRm.Profile
			function Set-AzureAuthToken ($creds, $subscriptionId)
			{
				Add-AzureRmAccount -SubscriptionId $subscriptionId -Credential $creds
			}
			Set-AzureAuthToken -creds $args[2] -subscriptionId $args[3]
			Start-AzureRmVm -Name $args[0] -ResourceGroupName $args[1] -Confirm:$false
		}
        $session = New-PSSession -ComputerName localhost
		Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $vm.Name,$resourceGroup,$cred,$azureSubscriptionId -AsJob
	}

	Get-Job | Wait-Job
	Get-Job | Remove-Job
	Get-PSSession | Remove-PSSession
}


function Stop-AzureVMs
{

	$userName = "" #username
	$cred = Get-MyCred -user $userName
	$resourceGroup = "" #ResourceGroup the VMs are in
    
	$azureSubscriptionId = "" # subscriptionId
    Add-AzureRmAccount -SubscriptionId $azureSubscriptionId -Credential $cred
    $vms = Get-AzureRmVm -ResourceGroupName $resourceGroup

	foreach($vm in $vms)
	{
		$scriptBlock = {
            Import-Module AzureRm.Profile
			function Set-AzureAuthToken ($creds, $subscriptionId)
			{
				Add-AzureRmAccount -SubscriptionId $subscriptionId -Credential $creds
			}
			Set-AzureAuthToken -creds $args[2] -subscriptionId $args[3]
			Stop-AzureRmVm -Name $args[0] -ResourceGroupName $args[1] -Force -Confirm:$false
		}
        $session = New-PSSession -ComputerName localhost
		Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $vm.Name,$resourceGroup,$cred,$azureSubscriptionId -AsJob
	}

	Get-Job | Wait-Job
    Get-Job | Remove-Job
	Get-PSSession | Remove-PSSession
}

