# I (senjou) am not the author of this script. Fuzz#3212 is the og creator. I just added a logging feature to know whether the script running fine on server or not

$discordHook = ""
$logdiscordHook = ""
$seadexURL = "https://docs.google.com/spreadsheets/d/1emW2Zsb0gEtEHiub_YHpazvBd4lL4saxCwyPhbtxXYM"

$rootDir = $pwd
$trackerFileName = "seadex-series_tracker.csv"
$latestFileName = "seadex-series_tracker_new.csv"

$logcontent = @"
**Seadex (TV) script executed on :** $(Get-Date -UFormat "%B %d, %Y %T %Z")
"@
$logpayload = [PSCustomObject]@{content = $logcontent}

[System.Collections.ArrayList]$embedArray = @()
[System.Collections.ArrayList]$fieldArray = @()


function generateField($itemProperty, $existingItemProperty)
{
    $inline = $true
    $value = "``````$($itemProperty.Value)``````"

    if($existingItemProperty)
    {
        if($itemProperty.Value -ne $existingItemProperty.Value)
        {
            if(!($existingItemProperty.Value))
            {
                $value = @"
``````diff
+ $($itemPRoperty.Value -replace ("`r`n", "`r`n+ "))``````
"@
            }
            elseif(!($itemProperty.Value))
            {
                $value = @"
``````diff
- $($existingItemProperty.Value -replace ("`r`n", "`r`n- "))``````
"@
            }
            else 
            {
                $value = @"
``````diff
- $($existingItemProperty.Value -replace ("`r`n", "`r`n- "))``````
``````diff
+ $($itemPRoperty.Value -replace ("`r`n", "`r`n+ "))``````
"@
            }
        }
    }

    if($itemProperty.Name -match "Title|Notes")
    {
        $inline = $false
    }

    if($itemProperty.Value -or $existingItemProperty.Value)
    {
        $fieldObject = [PSCustomObject]@{
            name = $itemProperty.Name
            value = $value
            inline = $inline
        }
        $fieldArray.Add($fieldObject) | Out-Null
    }
}

function releaseEmbed($fields, $type)
{
    $embedObject = [PSCustomObject]@{
        title       = $type
        color       = 4886754
        timestamp = $(get-date -Format "yyyy-MM-ddTHH:mm:ss.ffffZ")
        fields = $fieldArray
    }
    $embedArray.Add($embedObject) | Out-Null
    $payload = [PSCustomObject]@{
        embeds = $embedArray
    }
    Invoke-RestMethod -Uri $discordHook -Method Post -Body ($payload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json'
}

function errorEmbed($description)
{
    $embedObject = [PSCustomObject]@{
        title       = "Seadexbot (TV) Encountered an Error"
        description = $description
        color       = 4886754
        timestamp = $(get-date -Format "yyyy-MM-ddTHH:mm:ss.ffffZ")
    }
    $embedArray.Add($embedObject) | Out-Null
    $payload = [PSCustomObject]@{
        embeds = $embedArray
    }
    Invoke-RestMethod -Uri $discordHook -Method Post -Body ($payload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json'
}        

try {
    Invoke-WebRequest -Uri "$seadexURL/export?format=csv" -OutFile "$rootDir\$latestFileName"
    (Get-Content "$rootDir\$latestFileName" | Select-Object -Skip 1) | Set-Content "$rootDir\$latestFileName"
}
catch {
    errorEmbed "Failed to Download new CSV (TV)"
    Invoke-RestMethod -Uri $logdiscordHook -Method Post -Body ($logpayload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json'
    break
}

if(!(Test-Path "$rootDir\$trackerFileName"))
{
    Rename-Item -Path "$rootDir\$latestFileName" -NewName $trackerFileName
}
else
{
    $trackerFile = Import-Csv "$rootDir\$trackerFileName"
    $latestFile = Import-Csv "$rootDir\$latestFileName"

    $diff = Compare-Object $trackerFile $latestFile -Property "Title", "Best Release", "Alternate Release", "Notes"

    foreach($diffItem in $diff | Where-Object SideIndicator -eq "=>")
    {
        $type = "New TV Release Found!"
        $embedArray.Clear()
        $fieldArray.Clear()

        $existingItem = $diff | Where-Object Title -Match $diffItem.Title | Where-Object SideIndicator -eq "<="

        foreach($itemProperty in $diffItem.PsObject.Properties | Where-Object name -ne "SideIndicator")
        {
            if($existingItem)
            {
                $existingItemProperty = $existingItem.PsObject.Properties | Where-Object Name -Match $itemProperty.Name
                generateField $itemProperty $existingItemProperty
            }
            else 
            {
                generateField $itemProperty
            }
            
        }
        
        if($existingItem)
        {
            $type = "TV Release Updated!"
        }

        try {
            releaseEmbed $fieldArray $type
            Start-Sleep -Milliseconds 1000
        }
        catch {
            errorEmbed "Failed to post to discord Webhook."
            Invoke-RestMethod -Uri $logdiscordHook -Method Post -Body ($logpayload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json'
            break
        }
    }

    Remove-Item -Path "$rootDir\$trackerFileName" -Force
    Rename-Item -Path "$rootDir\$latestFileName" -NewName $trackerFileName
}
Invoke-RestMethod -Uri $logdiscordHook -Method Post -Body ($logpayload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json'
