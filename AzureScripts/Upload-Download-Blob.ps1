<#
    Source and Destination Object Format

    $obj = New-Object -TypeName psobject -Property @{
        path = C:\ or Https://blob.blob.blob/blob > NO FILE NAME!!! Directory Only
        key = If Azure Storage, access key, if not $null
        file = Name of file you want to upload, or pattern for a group of files * for all files, all child folders will be replicated
    }

    Path to the AzCopy EXE
    .

    dphappstorage
        Key: 
        URI: 
#>
$src = New-Object -TypeName psobject -Property @{
        path = ""
        key = ""
        file = "*"
    }

$dst = New-Object -TypeName psobject -Property @{
        path = ""
        key = $null
        file = $null
    }

function Upload-Download-Blob ($src, $dst, $azCopyPath)
{
    $azAppdata = "$($env:LOCALAPPDATA)\Microsoft\Azure\AzCopy"
    $item = Get-Item -Path $azAppdata
    if($item -ne $null)
    {
        Remove-Item -Path $azAppdata -Recurse -Force -Confirm:$false
    }
    $directory = "AzCopy.exe"
    if($src.key -eq $null -and $dst.key -ne $null)
    {
        $cmd = "/Source:`"$($src.path)`" /Dest:`"$($dst.path)`" /DestKey:$($dst.key) /Pattern:`"$($src.file)`" /XO  /S" 
    }
    if ($src.key -ne $null -and $dsk.key -eq $null)
    {
        $cmd = "/Source:`"$($src.path)`" /Dest:`"$($dst.path)`" /SourceKey:`"$($src.key)`" /Pattern:`"$($src.file)`" /XO  /S"
    }
    if ($src.key -ne $null -and $dst.key -ne $null)
    {
        $cmd = "`/Source:`"$($src.path)`" /Dest:`"$($dst.path)`" /SourceKey:`"$($src.key)`" /DestKey:`"$($dst.key)`" /Pattern:`"$($src.file)`" /XO /S"
    }

    Start-Process -FilePath $azCopyPath -ArgumentList $cmd
    Get-Process -Name AzCopy | Wait-Process
    Remove-Item -Path $azAppdata -Recurse -Force -Confirm:$false
}
 