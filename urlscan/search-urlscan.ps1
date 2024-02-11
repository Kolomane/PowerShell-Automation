# Script Name: search-urlscan.ps1
# Script Purpose: Searches URLScan based on given criteria, dumps results to .json file(s)
# Created On: 02/10/2024
# Created By: Coleman Dole

function Search-URLScan {
    <#
    .SYNOPSIS
    Uses the /search/ endpoint from URLScan.io's API. Counts the total number of results received, outputs them to .json file(s).

    .DESCRIPTION
    A quick weekend project to create a PowerShell function that uses URLScan's search feature.
    Supply it with an API key from urlscan.io, a search query, maximum results you want to retrieve, and a folder to dump result files to.
    The result files are stored in .json so if you want to use PowerShell to loop on them, be sure to check the | ConvertFrom-Json commandlet.

    .PARAMETER apiKey
    *REQUIRED* [STRING] URLScan.io API Key. If you do not have one, sign up at urlscan.io for a free API key. This script accommodates for the free tier (max return 1,000). If you're not on the free tier be sure to change the $sizeLimit variable.

    .PARAMETER query
    *REQUIRED* [STRING] A query to send. Check the official documentation here: https://urlscan.io/docs/search/ for more information. Note that prepending with q= is not required and will be added automatically if your input does not start with it. Examples include:
    page.url:"CD/New"
    q=task.tags:cryptoscam
    task.tags:phishing

    .PARAMETER maxLimit
    *REQUIRED* [INTEGER] Maximum number of results to pull. Assuming the query has an endless supply, such as "task.tags:phishing"

    .PARAMETER outputLocation
    *REQUIRED* [STRING] A valid folder path to store the result .json file(s) in.

    .EXAMPLE
    Search-URLScan -apiKey "x" -query 'task.tags:cryptoscam' -maxLimit 11500 -outputLocation "C:\Scripts\urlscanit"

    .NOTES
    Be sure to chekc URLScan.io's documentation for API usage, Search usage, and more.
    For example, after 10,000 results URLScan continues to flag "has_more=True", which this script accommodates for.
    However, if there are exactly <result size limit> results and it flags as "has_more=False", this script will terminate.
    You may need to tinker with things to get it just right. This is not a perfect function/module.
    #>
    param (
        [Parameter(Mandatory)]
        [String]$apiKey,
        [Parameter(Mandatory)]
        [String]$query,
        [Parameter(Mandatory)]
        [Int]$maxLimit,
        [Parameter(Mandatory)]
        [String]$outputLocation
    ) # This is my first function with parameter validation, don't judge me too hard

    $theHeader = @{
        "API-Key" = "$apikey"
    } # Set the Headers for the API call
    $baseUrl = 'https://urlscan.io/api/v1' # Static variable for the base URL
    $theEndpoint = '/search/' # Static variable for the endpoint... Yes it's more lines of code but it's a bit more malleable this way :)
    $sizeLimit = 1000 # Max limit for a single Search API call... At least with the Free version of URLScan
    if (-Not($query | Select-String 'q=.*')) {
        $query = "q=$($query)"
    }
    $error.clear() # Clear out the Error cache

    # There's a lot going on in the conditional for this IF statement...
    # # IF the MaxLimit specified is within the DAILY maximum limit (see above)
    # # AND IF the output file path is a valid path  -and ((Test-Path $outputLocation))
    if (Test-Path $outputLocation) {
        $theIterations = [math]::Ceiling($maxLimit / $sizeLimit) # Split the user-defined limit against the API size limit
        $theSize = 1000
        $runningTotal = 0
        $theSearch = $false
        $keepGoing = $true
        # There's a lot going on in the conditional for this FOR statement...
        # # SET tempInt to 1
        # # WHILE (tempInt less than theIterations) AND (keepGoing is true) AND (no new errors)
        # # THEN add +1 to tempInt
        for ($tempInt = 1; ($tempInt -le $theIterations) -and ($keepGoing) -and (($error | Measure-Object).Count -eq 0); $tempInt++) {
            if (($tempInt -eq 1) -and ($maxLimit -lt $sizeLimit)) {
                # If it's the first time running, grab the full 1,000
                $theQuery = "$($baseUrl)$($theEndpoint)?$($query)&size=$maxLimit"
            }
            else {
                if ($runningTotal -gt 0) {
                    if (($maxLimit / $runningTotal) | Select-String '^1\.\d+') {
                        # Check if it's on the last loop; Doing some math and Regex'ing for the condition
                        $theSize = $maxLimit - $runningTotal # Trimming down to only searching against the difference
                    }
                }
                else {
                    # Otherwise, we set the size to the max
                    $theSize = 1000
                }
                if ($theSearch) {
                    # If there's been a previous search...
                    $theSortToken = ($theSearch.results | Select-Object -Last 1).sort # Take the last object's list named "sort"
                    $theAfter = "$($theSortToken[0]),$($theSortToken[1])" # Write the output how URLScan likes it, comma separated
                }
                else {
                    # Otherwise we're null'ing it out, since URLScan is cool with it being blank as well
                    $theAfter = $null
                }
                # Finally, the long URL with all parameters
                $theQuery = "$($baseUrl)$($theEndpoint)?$($query)&size=$theSize&search_after=$theAfter"
            }
            try {
                # Write-Output "theQuery = $($theQuery)"
                $theSearch = Invoke-RestMethod -Method Get -Uri $theQuery -Headers $theHeader -ContentType application/json # Run the search
                $keepGoing = [bool]$theSearch.has_more # Reset conditional, if we should keep going/looping or not
                # Write-Output "HAS_MORE FLAG - $($theSearch.has_more) | BOOL IT = $([bool]$theSearch.has_more) | KEEPGOING = $($keepGoing)`r`n`r`nTHE DATA $($theSearch)"
                $resultCount = ($theSearch.results | Measure-Object).Count # Capture the count of result objects
                $runningTotal += $resultCount # Add the total to runningTotal
                Write-Output "Finished Search $($tempInt)/$($theIterations) with $($resultCount) results.`r`n - Total possible(?): $($theSearch.total)`r`n - Total taken this batch(?): $($theSearch.took)`r`n - More search results after this: $($keepGoing)`r`n - Running Total: $($runningTotal)"
                Write-Output "Saving results to: $($outputLocation)\search_results_$($tempInt).json"
                if ($theSize -lt $sizeLimit) {
                    # Output the results to a file; Only selecting the first N (here it is $theSize), since it's the remainder of what's requested
                    # # Probably not needed, but it's a good fail-safe
                    $theSearch.results | Select-Object -First $theSize | ConvertTo-Json | Out-File "$($outputLocation)\search_results_$($tempInt).json"
                }
                else {
                    # Output the results to a file; dumping $maxSize of results to file
                    $theSearch.results | ConvertTo-Json | Out-File "$($outputLocation)\search_results_$($tempInt).json"
                }
            }
            catch {
                Write-Output "An error occurred :(`r`n`r`n$($error | Select-Object -Last 1)`r`n`r`nAnd remember: 4XX codes means it's your fault, 5XX codes means it's their fault!`r`n`r`n"
            }

        }
    }
}

# Example usage. Be sure to replace the API key with your actual API key.
Search-URLScan -apiKey "x" -query 'task.tags:cryptoscam' -maxLimit 11500 -outputLocation "C:\Scripts\urlscanit"