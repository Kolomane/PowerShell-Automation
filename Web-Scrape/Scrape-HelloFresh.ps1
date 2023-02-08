# Drop HF recipe links, one line at a time, into a .txt file
$TheInput = "C:\scripts\hello_fresh_recipes.txt"
# Designate where the .csv file will be saved
$TheOutput = "C:\scripts\IngredientsList.csv"
# Set the number for how many people you intend to feed
$NumberOfPeopleToServe = 3

############################################################
# Get the recipe list
$TheRecipeList = Get-Content $TheInput
# Create a null array/table
[Array]$RecipeIngredientsList = $null
$ServingSizeNumber = ""
$ServingSizeReg = ""

# For each link... scrape the website and compile the ingredients into the array
$TheRecipeList | ForEach-Object {
    # Perform the web request
    $HelloRecipes = Invoke-RestMethod -Method Get -Uri "$_"
    # Get the JSON for just the recipe
    $RecipeCard = ($HelloRecipes | Select-String '\<script type\="application\/ld\+json" id\="schema\-org"\>(\{.*?\})\<\/script\>').Matches.Groups[1].Value | ConvertFrom-Json
    try {
         # Get the serving size number, IF it's for a set amount (usually 4)
        $ServingSizeNumber = ($HelloRecipes | Select-String 'serving (\d) people').Matches.Groups[1].Value
    }
    catch {
        # Get the serving size; most recipes use this, where it's EITHER 2 or 4, with the default being 2
        $ServingSizeReg = ($HelloRecipes | Select-String 'serving amount').Matches.Value
    }
    
    # Get the nutritional information
    $RecipeNutrition = ($RecipeCard | Select-Object nutrition).nutrition | Select-Object calories, fatContent, saturatedFatContent, carbohydrateContent, sugarContent, proteinContent, fiberContent, cholesterolContent, sodiumContent
    # Get the ingredients, most important part
    $RecipeIngredients = ($RecipeCard | Select-Object recipeIngredient).recipeIngredient
    # Get the instructions
    $RecipeInstructions = ($RecipeCard | Select-Object recipeInstructions).recipeInstructions.text
    # Get misc. information for the recipe
    $RecipeInfo = $RecipeCard | Select-Object name, recipeYield, keywords, recipeCuisine

    # Add the ingredients to the array/table
    $RecipeIngredientsList += $RecipeIngredients
}

# $RecipeIngredientsList = Get-Content "C:\Scripts\total_list.txt"
[Array]$IngredientsList = $null

$RecipeIngredientsList | Where-Object {($_ -notmatch '(unit\s)?Kosher Salt') -and ($_ -notmatch '(unit\s)?Pepper')} | ForEach-Object {
    $TempTable = [PSCustomObject]@{}
    $TempNumber = 0
    $RegexMatch = ($_ | Select-String -Pattern '(\S+)\s(\w+)\s(.*)')
    Switch ($RegexMatch.Matches.Groups[1].Value) {
        "¼" {$TempNumber = 0.25}
        "½" {$TempNumber = 0.5}
        "¾" {$TempNumber = 0.75}
        Default {$TempNumber = $_}
    }
    $TempTable | Add-Member -MemberType NoteProperty -Name 'CountOf' -Value "$TempNumber"
    $TempTable | Add-Member -MemberType NoteProperty -Name 'Measurement' -Value "$($RegexMatch.Matches.Groups[2].Value)"
    $TempTable | Add-Member -MemberType NoteProperty -Name 'Items' -Value "$($RegexMatch.Matches.Groups[3].Value)"
    $IngredientsList += $TempTable
}

$IngredientsList | Group-Object Items,Measurement | Select-Object Group | Where-Object {$_.Group -match '\S.*'} | ForEach-Object {
    # Write-Output "$($_.Group[0].CountOf)"
    $TemporaryThingy = [PSCustomObject]@{}
    $TemporaryNumber = 0
    $_.Group | ForEach-Object {
        $TemporaryNumber += $_.CountOf
    }
    if ($ServingSizeReg -ne "") {
        $TemporaryNumber = ($TemporaryNumber / 2) * $NumberOfPeopleToServe
    }
    else {
        switch ($ServingSizeNumber) {
            4 {$TemporaryNumber = (($TemporaryNumber * 0.25) * $NumberOfPeopleToServe)}
            3 {$TemporaryNumber = (($TemporaryNumber * 0.33) * $NumberOfPeopleToServe)}
            2 {$TemporaryNumber = (($TemporaryNumber / 2) * $NumberOfPeopleToServe)}
            1 {$TemporaryNumber = ($TemporaryNumber * $NumberOfPeopleToServe)}
            Default {
                # Do nothing
            }
        }
    }
    # Write-Output "$TemporaryNumber, $($_.Group[0].Measurement), $($_.Group[0].Items)"
    $TemporaryThingy | Add-Member -MemberType NoteProperty -Name 'CountOf' -Value "$TemporaryNumber"
    $TemporaryThingy | Add-Member -MemberType NoteProperty -Name 'Measurement' -Value "$($_.Group[0].Measurement)"
    $TemporaryThingy | Add-Member -MemberType NoteProperty -Name 'Items' -Value "$($_.Group[0].Items)"
    $TemporaryThingy | Export-Csv -NoTypeInformation $TheOutput -Append
}
