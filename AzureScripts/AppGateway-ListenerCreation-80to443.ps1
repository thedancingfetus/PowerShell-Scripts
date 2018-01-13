$appGatewayName = ""
$appGatewayRG = ""
$listnersPrefix = @("") #Array of listener prefixes Ex. Jenkins
$listenerHostname = @("") #Arrary of hostnames.  $listnersPrefix[0] should be paired with $listenerHostname[0] and so on
$backendPort = @() #Array of backend ports $backendPort[0] should be paired with $listnersPrefix[0] and $listenerHostname[0]

$gw = Get-AzureRmApplicationGateway -ResourceGroupName $appGatewayRG -Name $appGatewayName
$frontEndIPId = (Get-AzureRmApplicationGatewayFrontendIPConfig -ApplicationGateway $gw | ?{$_.PublicIPAddress -ne $null}).Id
$frontEnd80PortId = (Get-AzureRmApplicationGatewayFrontendPort -ApplicationGateway $gw | ?{$_.Port -eq 80}).Id
if($frontEnd80PortId -eq $null)
{
    Add-AzureRmApplicationGatewayFrontendPort -ApplicationGateway $gw -Name "HTTP" -Port 80
    $frontEnd80PortId = (Get-AzureRmApplicationGatewayFrontendPort -ApplicationGateway $gw | ?{$_.Port -eq 80}).Id
}
$frontEnd443PortId = (Get-AzureRmApplicationGatewayFrontendPort -ApplicationGateway $gw | ?{$_.Port -eq 443}).Id
if($frontEnd443PortId -eq $null)
{
    Add-AzureRmApplicationGatewayFrontendPort -ApplicationGateway $gw -Name "HTTPs" -Port 443
    $frontEnd443PortId = (Get-AzureRmApplicationGatewayFrontendPort -ApplicationGateway $gw | ?{$_.Port -eq 80}).Id
}
$certId = (Get-AzureRmApplicationGatewaySslCertificate -ApplicationGateway $gw)[0].Id

for($i = 0; $i -lt $listnersPrefix.Length; $i++)
{
    $80ListenerName = $listnersPrefix[$i] + "80"
    $443ListenrName = $listnersPrefix[$i] + "443"
    $redirectName = $listnersPrefix[$i] + "80to443"
    $httpBackend = Get-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $gw | ?{$_.Port -eq $backendPort[$i]}
    if($httpBackend -eq $null)
    {
        Add-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $gw -Name $("Port"+$backendPort[$i].ToString()) -Port $backendPort[$i] -Protocol Http -CookieBasedAffinity Enabled -RequestTimeout 30
        $httpBackend = Get-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $gw | ?{$_.Port -eq $backendPort[$i]}
    }
    Add-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $gw -Name $listnersPrefix[$i] 
    $backendPool = Get-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $gw -Name $listnersPrefix[$i]

    Add-AzureRmApplicationGatewayHttpListener -ApplicationGateway $gw -Name $80ListenerName -FrontendIPConfigurationId $frontEndIPId -FrontendPortId $frontEnd80PortId -HostName $listenerHostname[$i] -Protocol Http 
    Add-AzureRmApplicationGatewayHttpListener -ApplicationGateway $gw -Name $443ListenrName -FrontendIPConfigurationId $frontEndIPId -FrontendPortId $frontEnd443PortId -HostName $listenerHostname[$i] -Protocol Https -SslCertificateId $certId
    $source = Get-AzureRmApplicationGatewayHttpListener -Name $80ListenerName -ApplicationGateway $gw
    $target = Get-AzureRmApplicationGatewayHttpListener -Name $443ListenrName -ApplicationGateway $gw

    Add-AzureRmApplicationGatewayRedirectConfiguration -Name "$($redirectName + "-conf")" -RedirectType Permanent -TargetListener $target -IncludePath $true -IncludeQueryString $true -ApplicationGateway $gw
    $redirectConfig = Get-AzureRmApplicationGatewayRedirectConfiguration -Name $($redirectName + "-conf") -ApplicationGateway $gw

    Add-AzureRmApplicationGatewayRequestRoutingRule -Name $redirectName -RuleType Basic -HttpListener $source -RedirectConfiguration $redirectConfig -ApplicationGateway $gw

    Add-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $gw -Name "$($listnersPrefix[$i] + "-backend")" -RuleType Basic -BackendHttpSettingsId $httpBackend.Id -HttpListenerId $target.Id -BackendAddressPoolId $backendPool.id
}

#Set-AzureRmApplicationGateway -ApplicationGateway $gw
