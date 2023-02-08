# Scrape Shopify
function Scrape-ShopifyStore {

    param (
        $URL,
        $Material
    )
    # Perform the webrequest, match for "offers" JSON on the Shopify webpage
    # This is for the INDIVIDUAL ITEM PAGE
    $Item_Page = "{$(((Invoke-WebRequest -Method GET -uri "$URL").content | Select-String -Pattern '\"offers\"\: \[\{([\n\S\s]*?)\]').Matches.Value)}"
    # Create an empty Array
    [Array]$Output_Table = $null

    # Foreach "offers" on the item page...
    ($Item_Page | ConvertFrom-Json).offers | ForEach-Object {
        # Create a temporary array/table, load it with all available property types
        # Excluding country currency, I didn't feel that was quite necessary
        $Temporary_Table = New-Object -TypeName PSObject
        $Temporary_Table | Add-Member -MemberType NoteProperty -Name "Material" -Value "$($Material)"
        $Temporary_Table | Add-Member -MemberType NoteProperty -Name "SKU" -Value "$($_.sku)"
        # Regex on the Availability part, cut out the "http://schema.org/"
        # Probably could have trim'd the string, but eh...
        $Temporary_Table | Add-Member -MemberType NoteProperty -Name "Availability" -Value "$(($_.availability | Select-String -Pattern 'http\:\/\/schema\.org\/(\S+)').Matches.Groups[1])"
        $Temporary_Table | Add-Member -MemberType NoteProperty -Name "Price" -Value "$($_.price)"
        $Temporary_Table | Add-Member -MemberType NoteProperty -Name "URL" -Value "$($_.url)"
        # Append the final output with the temporary table
        $Output_Table += $Temporary_Table
    }
    # Call the final output, this is the 'result' of the Function
    $Output_Table
}

# CoEx Material Info Pull
function Get-CoexInventory {
    param (
        $OutJsonPath,
        $OutCsvPath
    )
    # Creating empty Arrays
    [Array]$CoexAllFilaments = $null
    [Array]$CoexFilamentsTable = $null

    # Coex's inventory is large, and not all items are displayed on one page... So 2x webrequests
    # These are for the "All Items" webpages
    $CoexAllFilamentsWebRequestPt1 = (Invoke-WebRequest -Method Get -Uri "https://coex3d.com/collections/3d-filaments").content
    $CoexAllFilamentsWebRequestPt2 = (Invoke-WebRequest -Method Get -Uri "https://coex3d.com/collections/3d-filaments?page=2").content
    # Quick glance at source code and the quickest win is an anchor tab linking to each ITEM
    # Regex to match all ITEMS
    ($CoexAllFilamentsWebRequestPt1 | Select-String '\<a href\="\/products\/(\S+)" id' -AllMatches).Matches | ForEach-Object {
        # Take the match and append it to the first array/table
        $CoexAllFilaments += "$($_.Groups[1].Value)"
    }
    ($CoexAllFilamentsWebRequestPt2 | Select-String '\<a href\="\/products\/(\S+)" id' -AllMatches).Matches | ForEach-Object {
        # Take the match and append it to the first array/table
        # Now both pages of items are condensed into the single array/table
        $CoexAllFilaments += "$($_.Groups[1].Value)"
    }
    # This is where the magic happens... for each ITEM identified from the "All Items" page(s)
    $CoexAllFilaments | Sort-Object -Unique | ForEach-Object {
        # Start it out by sleeping for 1 second, self-throttling
        Start-Sleep -Seconds 1
        # Send it to Scrape-ShopifyStore
        # AND FILTER WHERE THE SKU MATCHES ...-18-..., this is 1.75mm filament (check source code of webpage)
        $CoexFilamentsTable += Scrape-ShopifyStore -URL "https://coex3d.com/products/$_" -Material "$_" | Where-Object {$_.sku -match '\S{4}\-\d{4}\-18\-\S+'}
    }
    # Output to both .json and .csv files
    $CoexFilamentsTable | ConvertTo-Json | Out-File $OutJsonPath
    $CoexFilamentsTable | Export-Csv $OutCsvPath -NoTypeInformation
}

# CookieCAD Material Info Pull
function Get-CookieCADInventory {
    param (
        $OutJsonPath,
        $OutCsvPath
    )
    # Creating empty Arrays
    [Array]$CookieCADAllFilaments = $null
    [Array]$CookieCADFilamentsTable = $null

    # WebRequest for the "All Items" webpage
    $CookieCADAllFilamentsWebRequest = (Invoke-WebRequest -Method Get -Uri "https://shops.cookiecad.com/collections/3d-printer-filament").content
    # Quick glance at source code and the quickest win is selecting the value for "handle" found in JSON on the page
    # Regex to match all ITEMS
    ($CookieCADAllFilamentsWebRequest | Select-String 'handle: "(.*?)",' -AllMatches).Matches | ForEach-Object {
        # Take the match and append it to the first array/table
        $CookieCADAllFilaments += "$($_.Groups[1].Value)"
    }
    # This is where the magic happens... for each ITEM identified from the "All Items" page(s)
    $CookieCADAllFilaments | Sort-Object -Unique | ForEach-Object {
        # Send it to Scrape-ShopifyStore
        # AND FILTER WHERE THE SKU MATCHES ...-18-..., this is 1.75mm filament (check source code of webpage)
        $CookieCADFilamentsTable += Scrape-ShopifyStore -URL "https://shops.cookiecad.com/collections/3d-printer-filament/products/$_" -Material "$_"
    }
    # Output to both .json and .csv files
    $CookieCADFilamentsTable | ConvertTo-Json | Out-File $OutJsonPath
    $CookieCADFilamentsTable | Export-Csv $OutCsvPath -NoTypeInformation
}

Write-Output "Starting Script..."
Get-CookieCADInventory -OutJsonPath "C:\scripts\CookieCAD_Scrape.json" -OutCsvPath "C:\scripts\CookieCAD_Scrape.csv"
Write-Output "Finished scraping CookieCAD"
Get-CoexInventory -OutJsonPath "C:\scripts\Coex_Scrape.json" -OutCsvPath "C:\scripts\Coex_Scrape.csv"
Write-Output "Finished scraping Coex"
Write-Output "Ending Script"