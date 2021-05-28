$DTFormats = (Get-Date).GetDateTimeFormats()
$Formats = @()
$i=0
While ($i -lt $DTFormats.Count){
    $row = [PSCustomObject]@{
        'IndexNumber' = $i
        'DateTime Format' = $DTFormats[$i]
    }
    $Formats += $row
    $i++
}

$DTSelection = ($Formats | Out-GridView -OutputMode Single -Title 'Select DateTime Format').IndexNumber
$MyDTFormat = "(Get-Date).GetDateTimeFormats()[$DTSelection]"
Write-Host " "
Write-Host " Use the following code snippet to get the DateTime format you selected:"
Write-Host "    $MyDTFormat" -ForegroundColor Green
Write-Host " "
$MyDTFormat | Clip
Write-Host " The code snippet has been copied to your clipboard. Paste snippet where needed."
