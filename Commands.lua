-- Slash commands.
local _, ns = ...

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
local function PathExists(path)
    local obj = _G
    for part in path:gmatch("[^%.]+") do
        if type(obj) ~= "table" then
            return false
        end
        obj = obj[part]
        if obj == nil then
            return false
        end
    end
    return true
end

local function SetWindowShown(show)
    if not ns.frame then
        ns.Print("The list window isn't available. Type /gl errors for details.")
        return
    end
    ns.cdb.shown = show and true or false
    ns.frame:SetShown(show)
end

local function PrintHelp()
    ns.Print("Commands:")
    print("  /gl - show or hide the list")
    print("  /gl clear - empty the list")
    print("  /gl modifier alt|ctrl|shift - key used with clicks (currently " .. ns.CurrentModifier() .. ")")
    print("  /gl skin forever|classic - window style (currently " .. ns.CurrentSkin() .. ")")
    print("  /gl recipes - re-scan the open profession and show how many recipes are remembered")
    print("  /gl chars - list every saved character list")
    print("  /gl merge N, /gl forget N - merge or delete list number N from /gl chars")
    print("  /gl errors - show recent errors")
    print("  /gl debug, /gl trace, /gl icons - troubleshooting")
end

SLASH_GROCERYLIST1 = "/grocerylist"
SLASH_GROCERYLIST2 = "/gl"
SlashCmdList["GROCERYLIST"] = ns.Guard("slash command", function(msg)
    if not ns.db or not ns.cdb then
        ns.Print("Still loading, try again in a moment.")
        return
    end

    msg = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")

    if cmd == "" or cmd == "toggle" then
        SetWindowShown(not (ns.frame and ns.frame:IsShown()))
    elseif cmd == "show" then
        SetWindowShown(true)
    elseif cmd == "hide" then
        SetWindowShown(false)
    elseif cmd == "clear" then
        wipe(ns.cdb.recipes)
        ns.Refresh()
        ns.Print("List cleared.")
    elseif cmd == "modifier" then
        if ns.MODIFIERS[arg] then
            ns.db.modifier = arg
            ns.Refresh()
            ns.Print("Modifier set to " .. ns.ModifierLabel() .. ". " .. ns.ModifierLabel() .. "+Left-click adds a recipe, " ..
                      ns.ModifierLabel() .. "+Right-click removes it.")
        else
            ns.Print("Usage: /gl modifier alt|ctrl|shift (currently " .. ns.CurrentModifier() .. ")")
        end
    elseif cmd == "skin" then
        if arg == "classic" or ns.SKIN_LAYOUTS[arg] then
            ns.db.skin = arg
            if ns.ReskinAll() then
                ns.Print("Window style set to " .. arg .. ".")
            else
                ns.Print("The " .. arg .. " style isn't available on this client, so the classic look is used.")
            end
        else
            ns.Print("Usage: /gl skin forever|classic (currently " .. ns.CurrentSkin() .. ")")
        end
    elseif cmd == "chars" then
        for i, key in ipairs(ns.CharacterKeys()) do
            print(string.format("  %d. %s - %d recipes%s", i, key, ns.CountRecipes(ns.db.chars[key]),
                key == ns.charKey and "  (this character)" or ""))
        end
        print("  Same order as the list selector. /gl merge N adds list N to this character's list and removes it.")
    elseif cmd == "merge" or cmd == "forget" then
        local key = tonumber(arg) and ns.CharacterKeys()[tonumber(arg)]
        if not key then
            ns.Print("Use /gl chars to see the list numbers, e.g. /gl " .. cmd .. " 2")
        elseif key == ns.charKey then
            ns.Print("That is this character's own list.")
        else
            if cmd == "merge" then
                ns.MergeInto(ns.cdb, ns.db.chars[key])
                ns.SanitizeCharacter(ns.cdb, false)
                ns.Print("Merged " .. key .. " into " .. ns.charKey .. ".")
            else
                ns.Print("Deleted the list for " .. key .. ".")
            end
            ns.db.chars[key] = nil
            if ns.viewKey == key then
                ns.viewKey = nil
            end
            ns.Refresh()
        end
    elseif cmd == "recipes" then
        local learned, total = ns.IndexProfession(true)
        if learned then
            ns.Print("Scanned the open profession: you know " .. learned .. " of its " .. total .. " recipes.")
        else
            ns.Print("No profession window is open, or its recipes haven't loaded yet. Open one and try again.")
        end
        local count = 0
        if type(ns.cdb.crafted) == "table" then
            for _ in pairs(ns.cdb.crafted) do
                count = count + 1
            end
        end
        ns.Print(count .. " craftable items remembered for " .. ns.charKey .. ".")
    elseif cmd == "errors" then
        if #ns.errorLog == 0 then
            ns.Print("No errors recorded this session.")
        else
            ns.Print("Recent errors (newest last):")
            for _, line in ipairs(ns.errorLog) do
                print("  " .. line)
            end
        end
    elseif cmd == "icons" then
        for _, r in pairs(ns.cdb.recipes) do
            local src = ns.RecipeIconSources(r.spellID)
            ns.Print(string.format("%s: item=%s spell=%s info=%s used=%s", r.name, tostring(src.item), tostring(src.spell),
                tostring(src.info), tostring(r.icon)))
        end
    elseif cmd == "trace" then
        ns.trace = not ns.trace
        ns.Print("Click trace " .. (ns.trace and "ON: click things with your modifier held." or "OFF."))
    elseif cmd == "debug" then
        ns.Print("Interface " .. tostring((select(4, GetBuildInfo()))) .. ", modifier " .. ns.CurrentModifier())
        local count = 0
        for _ in pairs(ns.cdb.recipes) do
            count = count + 1
        end
        ns.Print("List belongs to " .. tostring(ns.charKey) .. " (" .. count .. " recipes)")
        ns.Print("GLOBAL_MOUSE_DOWN registered: " .. tostring(ns.registered["GLOBAL_MOUSE_DOWN"]))
        for _, path in ipairs({"GetMouseFoci", "GetMouseFocus", "C_TradeSkillUI.GetRecipeSchematic",
                               "C_TradeSkillUI.CraftRecipe", "C_TradeSkillUI.OpenRecipe", "ProfessionsFrame",
                               "ProfessionsFrame.CraftingPage.RecipeList.ScrollBox", "TradeSkillFrame",
                               "TradeSkillSkill1", "CraftFrame", "Craft1"}) do
            ns.Print(path .. ": " .. (PathExists(path) and "yes" or "no"))
        end
    else
        PrintHelp()
    end
end)
