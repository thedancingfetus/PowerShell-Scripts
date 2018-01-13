$azureAdUsers = Get-AzureADUser -All $true | Select UserPrincipalName, ObjectId
$roles = Get-AzureADDirectoryRole
$admins = @()
foreach($role in $roles)
{
    $admins += New-Object -TypeName psobject -Property @{
        users = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId | Select  UserPrincipalName
        role = $role.DisplayName
    }
}
$admins = $admins | ?{$_.users.UserPrincipalName -ne $null} 
$userReport = @()
foreach($user in $azureAdUsers)
{    
    $admin = @()
    foreach($a in $admins)
    {
        $count = 0
        foreach($u in $a.users)
        {
            if($u.UserPrincipalName -eq $user.UserPrincipalName)
            {
                $count++
            }
        }
        if($count -ne 0)
        {
            $admin += New-Object -TypeName psobject -Property @{
                roleName = $a.role
            }
        }
    }
    $licenses = (Get-AzureADUserLicenseDetail -ObjectId $user.ObjectId).ServicePlans | Sort-Object -Property ServicePlanName
    $appliedLicenses = @()
    foreach($license in $licenses)
    {
        if($license.ProvisioningStatus -ne "Disabled")
        {
            $appliedLicenses += $license.ServicePlanName
        }
    }
    if($admin.Count -eq 0)
    {
        $userReport += New-Object -TypeName psobject -Property @{
            user = $user.UserPrincipalName
            isAdmin = $false
            roles = $null
            licenses = $appliedLicenses -join ","
        }
    }
    else
    {
        $userReport += New-Object -TypeName psobject -Property @{
            user = $user.UserPrincipalName
            isAdmin = $true
            roles = $admin.roleName -join ","
            licenses = $appliedLicenses -join ","
        }
    }
}
$userReport | Export-Csv -Path C:\Users\larp\Desktop\Aimco\UserLicenseReport_8-3.csv
