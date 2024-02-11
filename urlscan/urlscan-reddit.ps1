# URLScan API using PowerShell
# # https://urlscan.io/docs/api/

# Need the API Key, and need a URL to scan
$apikey = "x"
$url = Read-Host "Feed me a URL"

# Header and Body information, both splatted out; body is converted to JSON
$theHead = @{
    "API-Key"="$apikey"
}

$theBody = @{
    "url"="$url"
    "visibility"="private"
} | ConvertTo-Json

# Invoke-RestMethod, Posting to URLscan w/ API Key and URL
$urlScanIt = Invoke-RestMethod -Method Post -Uri "https://urlscan.io/api/v1/scan/" -Headers $theHead -Body $theBody -ContentType application/json

# Getting just the section of data that is relevant... Only need $urlSCanIt.api, but the UUID is nice to have as well
$scanlink = $urlScanIt.api
$scanuuid = $urlScanIt.uuid

# URLScan recommends 10 seconds to call, then retrying every 2 seconds... OR just wait 30-45 seconds :)
Start-Sleep 45

# Getting the results, pretty easy stuff here; no headers or body required!
$scanResult = Invoke-RestMethod -Method Get -Uri "$scanlink"


# List out the Domain and Server information
$scanResult.page | ForEach-Object {
    Write-Output "$($_.url)"
    Write-Output "$($_.domain)"
    Write-Output "$($_.city), $($_.country)"
    Write-Output "$($_.ip), $($_.asn), $($_.asnname)"
}

# Get all links on the webpage
$scanResult.data.links | Select-Object "href" -First 3 | ForEach-Object {
    Write-Output "$($_.href)"
}

# Query for Firewall searching... this example uses Palo Alto's Panorama
$scanResult.data.links | Select-Object "href" -First 3 | ForEach-Object {
    $query = ([System.Uri]$($_.href)).Authority -replace '^www.\.'
    Write-Output "(url contains '$query')"
}

# List all IP addresses the client connects to when visiting the webpage...
$scanResult.lists.ips | ForEach-Object {
    Write-Output "$($_)"
}

# List all countries that the IPs are registered to...
$scanResult.lists.countries | ForEach-Object {
    Write-Output "$($_)"
}

# List all countries that the IPs are registered to...
$scanResult.lists.servers | ForEach-Object {
    Write-Output "$($_)"
}

# Get Verdicts...
$scanResult.verdicts.overall
$scanResult.verdicts.engines
$scanResult.verdicts.community
$scanResult.verdicts.urlscan
$scanResult.verdicts.urlscan.categories

# Get the Live Screenshot .png - thanks for reading this far! This is where that UUID variable comes into play. ;)
#$scanPic = Invoke-WebRequest -Method Get -Uri "https://urlscan.io/screenshots/$scanuuid.png" -UseBasicParsing -OutFile "C:\scripts\$urltld.png"