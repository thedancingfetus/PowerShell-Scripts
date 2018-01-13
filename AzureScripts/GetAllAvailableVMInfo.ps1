$locations = (Get-AzureRmLocation).Location
$report = @()
foreach ($location in $locations)
{
    $report += New-Object -TypeName psobject -Property @{
        region = $location
        vms= Get-AzureRmVMSize -Location $location
    }
}
$vms = $report.vms | Group-Object Name | %{ $_.Group | Select Name,NumberOfCores,MemoryInMB,MaxDataDiskCount,OSDiskSizeInMB,ResourceDiskSizeInMB -First 1} | Sort Name

