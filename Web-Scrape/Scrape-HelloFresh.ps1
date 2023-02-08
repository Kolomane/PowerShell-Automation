
# Get the recipe list
$TheRecipeList = Get-Content "C:\Scripts\hello_fresh_recipes.txt"
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
    Write-Output "$RegexMatch | TYPE = $(($RegexMatch.Matches.Groups[1].Value).GetType().Name)"
    Switch ($RegexMatch.Matches.Groups[1].Value) {
        {([String]$_).length -eq 1} {}
        "¼" {$TempNumber = 0.25}
        "½" {$TempNumber = 0.5}
        "¾" {$TempNumber = 0.75}
        Default {$TempNumber = $_}
    }
    # Write-Output "TEMP NUMBER = $TempNumber"
    $TempTable | Add-Member -MemberType NoteProperty -Name 'CountOf' -Value "$TempNumber"
    $TempTable | Add-Member -MemberType NoteProperty -Name 'Measurement' -Value "$($RegexMatch.Matches.Groups[2].Value)"
    $TempTable | Add-Member -MemberType NoteProperty -Name 'Items' -Value "$($RegexMatch.Matches.Groups[3].Value)"
    $IngredientsList += $TempTable
}
break
$IngredientsList

$IngredientsList | Group-Object Items,Measurement | Select-Object Group | Where-Object {$_.Group -match '\S.*'} | ForEach-Object {
    # Write-Output "$($_.Group[0].CountOf)"
    $TemporaryThingy = [PSCustomObject]@{}
    $TemporaryNumber = 0
    $_.Group | ForEach-Object {
        $TemporaryNumber += $_.CountOf
    }
    if ($ServingSizeReg -ne "") {
        $TemporaryNumber = $TemporaryNumber * 2
    }
    else {
        switch ($ServingSizeNumber) {
            3 {$TemporaryNumber = [int]($TemporaryNumber * 0.66)}
            2 {$TemporaryNumber = ($TemporaryNumber * 2)}
            1 {$TemporaryNumber = ($TemporaryNumber * 4)}
            Default {
                # Do nothing
            }
        }
    }
    # Write-Output "$TemporaryNumber, $($_.Group[0].Measurement), $($_.Group[0].Items)"
    $TemporaryThingy | Add-Member -MemberType NoteProperty -Name 'CountOf' -Value "$TemporaryNumber"
    $TemporaryThingy | Add-Member -MemberType NoteProperty -Name 'Measurement' -Value "$($_.Group[0].Measurement)"
    $TemporaryThingy | Add-Member -MemberType NoteProperty -Name 'Items' -Value "$($_.Group[0].Items)"
    $TemporaryThingy | Export-Csv -NoTypeInformation "C:\Scripts\Ingredients.csv" -Append
}

# $FinalList = Import-Csv "C:\Scripts\Ingredients.csv"

# Write-Output '<!doctype html>
# <html lang="en" data-bs-theme="dark">

# <head>
#     <meta charset="utf-8">
#     <meta name="viewport" content="width=device-width, initial-scale=1">
#     <title>Meal Planning For </title>
#     <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet"
#         integrity="sha384-GLhlTQ8iRABdZLl6O3oVMWSktQOp6b7In1Zl3/Jr59b6EGGoI1aFkw7cmDA6j6gD" crossorigin="anonymous">
# </head>

# <body>
#     <nav class="navbar bg-body-tertiary mb-3">
#         <div class="container-fluid">
#             <span class="navbar-brand mb-0 h1">Meal Planning</span>
#         </div>
#     </nav>

#     <div class="row">
#         <div class="col mx-4">

#             <!-- CARD START -->
#             <div class="card">
#                 <h5 class="card-header">Shopping List</h5>
#                 <div class="card-body">

#                     <!-- START MAIN BODY -->' | Out-File $TheOutput -Append

#                     <div class="form-check">
#                         <input class="form-check-input" type="checkbox" value="" id="flexCheckDefault">
#                         <label class="form-check-label" for="flexCheckDefault">
#                             someText
#                         </label>
#                     </div>

# Write-Output '                    <!-- END MAIN BODY -->
#                 </div>
#             </div>
#             <!-- CARD END -->

#         </div>
#     </div>

#     <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"
#         integrity="sha384-w76AqPfDkMBDXo30jS1Sgez6pr3x5MlQ1ZAGC+nuZB+EYdgRZgiwxhTBTkF7CXvN"
#         crossorigin="anonymous"></script>
#     <script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.6/dist/umd/popper.min.js"
#         integrity="sha384-oBqDVmMz9ATKxIep9tiCxS/Z9fNfEXiDAYTujMAeBAsjFuCZSmKbSSUnQlmh/jp3"
#         crossorigin="anonymous"></script>
#     <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.min.js"
#         integrity="sha384-mQ93GR66B00ZXjt0YO5KlohRA5SY2XofN4zfuZxLkoj1gXtW8ANNCe9d5Y3eG5eD"
#         crossorigin="anonymous"></script>
# </body>

# </html>' | Out-File $TheOutput -Append