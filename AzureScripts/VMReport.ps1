$report = @()
$subscriptions = @("","")
foreach($sub in $subscriptions)
{
    Select-AzureRmSubscription -Subscription $sub
    $vms = Get-AzureRmVM -Status
    foreach($vm in $vms)
    {
        $report += New-Object -TypeName psobject -Property @{
            Name = $vm.Name
            Size = $vm.HardwareProfile.VmSize
            Subscription = $sub
            State = $vm.PowerState
        }
    }
}
