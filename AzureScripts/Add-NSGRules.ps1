$NSGName = ""
$NSGRg = ""
$sourceAddresses = @("","")
$destAddresses = @("","")
$sourceName = ""
$destName = ""
$sourcePortRange = ""
$destPortRange = ""
$description = ""
$protocol = ""
$direction = ""
$priority = 150

$nsg = Get-AzureRmNetworkSecurityGroup -Name NSGName -ResourceGroupName $NSGRg

Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "$($sourceName)$($node)_to_$($destName)" -Description $description -Protocol $protocol -SourcePortRange $sourcePortRange -DestinationPortRange $destPortRange -SourceAddressPrefix $sourceAddresses -DestinationAddressPrefix $destAddresses -Access Allow -Priority $priority -Direction $direction


