function Search-URLScan {
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
    $maxDailyLimit = 10000 # Daily max limit for URL Scan searching... At least with the Free version of URLScan
    if (-Not($query | Select-String 'q=.*')) {
        $query = "q=$($query)"
    }
    $error.clear() # Clear out the Error cache

    # There's a lot going on in the conditional for this IF statement...
    # # IF the MaxLimit specified is within the DAILY maximum limit (see above)
    # # AND IF the output file path is a valid path  -and ((Test-Path $outputLocation))
    if ((($maxLimit / $maxDailyLimit) -le 1) -and (Test-Path $outputLocation)) {
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
                    if (($maxLimit / $runningTotal) | Select-String '1\.\d+') {
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
                $resultCount = ($theSearch.results | Measure-Object).Count # Capture the count of result objects
                $runningTotal += $resultCount # Add the total to runningTotal
                Write-Output "Finished Search $($tempInt)/$($theIterations) with $($resultCount) results.`r`n - More search results after this: $($keepGoing)`r`n - Running Total: $($runningTotal)"
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
Search-URLScan -apiKey "x" -query "task.tags:cryptoscam" -maxLimit 1000 -outputLocation "C:\Scripts\urlscanit"