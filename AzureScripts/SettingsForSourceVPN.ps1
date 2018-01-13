$rg = ""
$name = ""
$gw = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $rg -Name $name
$location = $gw.Location
$peerIp = ""
$localSubnets = @("","")
$localGatewayName = ""
$sharedKey = ""

$localGateway = New-AzureRmLocalNetworkGateway -Name $localGatewayName -ResourceGroupName $rg -Location $gw.Location -GatewayIpAddress $peerIp -AddressPrefix $localSubnets

$ipsecPolicy = New-AzureRmIpsecPolicy -IkeEncryption AES256 -IkeIntegrity SHA1 -DhGroup DHGroup2 -PfsGroup PFS2 -IpsecEncryption AES256 -IpsecIntegrity SHA1 -SALifeTimeSeconds 28800 -SADataSizeKilobytes 4608000 

$localGateway = Get-AzureRmLocalNetworkGateway -ResourceGroupName $rg

New-AzureRmVirtualNetworkGatewayConnection -Name To-Corp -ResourceGroupName $rg -Location $location -SharedKey $sharedKey -VirtualNetworkGateway1 $gw -LocalNetworkGateway2 $localGateway -ConnectionType IPsec -UsePolicyBasedTrafficSelectors $true -IpsecPolicies $ipsecPolicy
