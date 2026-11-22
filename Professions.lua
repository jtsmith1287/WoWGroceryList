-- Talking to the profession window: opening a recipe, and the reagent -> recipe lookup.
local _, ns = ...

-- Open a recipe in the profession window (same call the objective tracker uses)
function ns.OpenRecipe(entry)
    local id = type(entry) == "table" and entry.spellID
    local name = type(entry) == "table" and ns.IsStr(entry.name) and entry.name or "that recipe"
    if ns.IsNum(id) and C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        if pcall(C_TradeSkillUI.OpenRecipe, id) then
            return
        end
    end
    ns.Print("Can't open " .. name .. " from here. Open its profession window manually.")
end

------------------------------------------------------------
-- Reagent -> recipe lookup
-- Every time a profession window is opened, the recipes this character knows are
-- remembered as "item made -> recipe" (cdb.crafted), so a reagent in the list can
-- be opened or added as a recipe later, even with the window closed.
------------------------------------------------------------
local indexedProfessions = {} -- professions already scanned this session
local indexPending = false

-- Scans the profession window that is open right now.
-- Returns nil when there is nothing to do, false when the profession's data isn't loaded yet,
-- otherwise: how many recipes are known, how many recipes the profession has.
function ns.IndexProfession(force)
    local api = C_TradeSkillUI
    if not (ns.cdb and api and api.GetAllRecipeIDs and api.GetRecipeInfo and api.GetRecipeSchematic) then
        return nil
    end
    local ids = ns.Try(api.GetAllRecipeIDs)
    if type(ids) ~= "table" or #ids == 0 then
        return false
    end

    local base = ns.Try(api.GetBaseProfessionInfo)
    local signature = tostring(type(base) == "table" and base.professionID or "?") .. ":" .. #ids .. ":" ..
                          tostring(ids[1])
    if not force and indexedProfessions[signature] then
        return nil
    end

    if type(ns.cdb.crafted) ~= "table" then
        ns.cdb.crafted = {}
    end
    local crafted = ns.cdb.crafted
    local learned, added = 0, 0
    for _, id in ipairs(ids) do
        local info = ns.Try(api.GetRecipeInfo, id)
        if type(info) == "table" and info.learned then
            learned = learned + 1
            local schematic = ns.Try(api.GetRecipeSchematic, id, false)
            if type(schematic) == "table" and ns.IsNum(schematic.outputItemID) then
                if crafted[schematic.outputItemID] ~= id then
                    added = added + 1
                end
                crafted[schematic.outputItemID] = id
            end
        end
    end

    if learned > 0 then
        indexedProfessions[signature] = true
    end
    if added > 0 and not force then
        ns.Print("Learned " .. added .. " craftable items from this profession.")
    end
    return learned, #ids
end

-- Scans shortly after a profession window opens or changes; tries again a few times
-- if the profession's recipes haven't finished loading.
function ns.ScheduleIndex(attempt)
    if not (C_Timer and C_Timer.After) then
        pcall(ns.IndexProfession)
        return
    end
    if not attempt then
        if indexPending then
            return
        end
        indexPending = true
        attempt = 1
    end
    C_Timer.After(attempt == 1 and 1 or 2, function()
        local ok, learned = pcall(ns.IndexProfession)
        if not ok then
            ns.LogError("recipe index", learned)
        elseif (learned == false or learned == 0) and attempt < 4 then
            ns.ScheduleIndex(attempt + 1)
            return
        end
        indexPending = false
    end)
end

-- The recipe that makes an item. ownOnly: only recipes this character knows (needed to open it).
-- Otherwise: preferData's character first, then this one, then any other saved character.
function ns.FindRecipeID(itemID, preferData, ownOnly)
    local function Lookup(data)
        local id = type(data) == "table" and type(data.crafted) == "table" and data.crafted[itemID]
        return ns.IsNum(id) and id or nil
    end
    if ownOnly then
        return Lookup(ns.cdb)
    end
    local id = Lookup(preferData) or Lookup(ns.cdb)
    if id then
        return id
    end
    for _, data in pairs(ns.db.chars) do
        id = Lookup(data)
        if id then
            return id
        end
    end
end

local function RecipeName(id)
    local info = C_TradeSkillUI and ns.Try(C_TradeSkillUI.GetRecipeInfo, id)
    if type(info) == "table" and ns.IsStr(info.name) and info.name ~= "" then
        return info.name
    end
    local spellName
    if C_Spell and C_Spell.GetSpellName then
        spellName = ns.Try(C_Spell.GetSpellName, id)
    elseif GetSpellInfo then
        spellName = ns.Try(GetSpellInfo, id)
    end
    if ns.IsStr(spellName) and spellName ~= "" then
        return spellName
    end
end


-- Adds the recipe that makes a reagent to the list being viewed, with enough crafts to cover
-- the quantity the list needs.
function ns.AddReagentAsRecipe(itemID, itemName, need)
    if ns.IsAllView() then
        ns.Print("Pick a single character in the list selector first.")
        return
    end
    local recipeID = ns.FindRecipeID(itemID, ns.db.chars[ns.viewKey or ns.charKey])
    if not recipeID then
        ns.Print("No known recipe makes " .. tostring(itemName) .. " yet.")
        return
    end

    local recipes = ns.ViewRecipes()
    local key = "s" .. recipeID
    local name = RecipeName(recipeID) or itemName
    if recipes[key] then
        ns.Print(name .. " is already on the list (x" .. recipes[key].count .. ").")
        return
    end

    local reagents = ns.ReadRetailReagents(recipeID)
    if not reagents or next(reagents) == nil then
        ns.Print("Couldn't read the reagents for " .. name .. ". Open its profession window once and try again.")
        return
    end

    local required = ns.IsNum(need) and need >= 1 and math.ceil(need) or 1
    local shortage = required - ns.GetOwned(itemID, ns.db.includeBank)
    if shortage <= 0 then
        ns.Print("You already own enough " .. tostring(itemName) .. " to cover the list.")
        return
    end

    -- some recipes make several items per craft
    local schematic = ns.Try(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    local perCraft = type(schematic) == "table" and ns.IsNum(schematic.quantityMin) and schematic.quantityMin >= 1 and
                         schematic.quantityMin or 1
    local crafts = math.ceil(shortage / perCraft)
    ns.AddTracked(key, recipeID, name, reagents, nil, recipes, crafts, true)
end
