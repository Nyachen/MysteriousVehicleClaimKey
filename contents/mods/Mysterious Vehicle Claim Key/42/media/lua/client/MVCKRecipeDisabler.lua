local function DisableCraftKey()
    if SandboxVars.MVCK.DisableCraftKey then
        local recipeName = "Craft Mysterious Vehicle Claim Key"
        local removed = DisableCraftRecipeByName(recipeName)

        if removed then
            print("Disabled craftRecipe:", recipeName)
        else
            print("CraftRecipe not found:", recipeName)
        end
    end
end

function DisableCraftRecipeByName(recipeName)
    local allCraftRecipes = getScriptManager():getAllCraftRecipes()
    if not allCraftRecipes then return false end

    for i = 0, allCraftRecipes:size() - 1 do
        local recipe = allCraftRecipes:get(i)

        if recipe:getName() == tostring(recipeName) then
            print("Found craftRecipe:", recipe:getName())
            print("craftRecipe methods:")
            for k, v in pairs(getmetatable(recipe).__index) do
                print(k)
            end
            recipe:clearRequiredSkills()
            recipe:addRequiredSkill(Perks.None, 10)
            return true
        end
    end

    return false
end

Events.OnGameStart.Add(DisableCraftKey)