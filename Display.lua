-- Turns the saved lists into what the window shows: recipe icons, reagent totals
-- and craftable status.
local _, ns = ...

-- Icon candidates for a recipe, from several sources
function ns.RecipeIconSources(id)
    local src = {}
    if not ns.IsNum(id) then
        return src
    end

    -- the item the recipe produces (what you'd expect to see)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local schematic = ns.Try(C_TradeSkillUI.GetRecipeSchematic, id, false)
        if type(schematic) == "table" and ns.IsNum(schematic.outputItemID) then
            local _, itemIcon = ns.ItemNameIcon(schematic.outputItemID)
            src.item = itemIcon
        end
    end

    -- the recipe spell's own icon
    local spellIcon
    if C_Spell and C_Spell.GetSpellTexture then
        spellIcon = ns.Try(C_Spell.GetSpellTexture, id)
    elseif GetSpellTexture then
        spellIcon = ns.Try(GetSpellTexture, id)
    end
    if ns.IsNum(spellIcon) or ns.IsStr(spellIcon) then
        src.spell = spellIcon
    end

    -- the profession API's recipe info
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local info = ns.Try(C_TradeSkillUI.GetRecipeInfo, id)
        if type(info) == "table" and (ns.IsNum(info.icon) or ns.IsStr(info.icon)) then
            src.info = info.icon
        end
    end

    return src
end

local function ResolveRecipeIcon(r)
    if r.icon then
        return r.icon
    end
    if r.spellID then
        local src = ns.RecipeIconSources(r.spellID)
        local icon = src.item or src.spell or src.info
        if icon then
            r.icon = icon
            return icon
        end
    end
    return ns.QUESTION_MARK
end

-- Build the reagent-grouped list
local function BuildList(recipes)
    local totals = {}
    for _, recipe in pairs(recipes or ns.cdb.recipes) do
        for itemID, reg in pairs(recipe.reagents) do
            local t = totals[itemID]
            if not t then
                local name, icon = ns.ItemNameIcon(itemID)
                t = {
                    id = itemID,
                    name = name or reg.name or ("Item " .. itemID),
                    icon = icon or reg.icon,
                    need = 0,
                    uses = {}
                }
                totals[itemID] = t
            end
            t.need = t.need + reg.qty * recipe.count
            t.uses[#t.uses + 1] = {
                name = recipe.owner and (recipe.name .. " (" .. recipe.owner .. ")") or recipe.name,
                count = recipe.count,
                per = reg.qty
            }
        end
    end

    local list = {}
    for _, t in pairs(totals) do
        local inBags = ns.GetOwned(t.id, false)
        t.have = ns.GetOwned(t.id, ns.db.includeBank)
        t.done = t.have >= t.need
        -- True only when total owned is enough, AND inventory/bags alone aren't enough
        t.needsBank = ns.db.includeBank and t.done and (inBags < t.need)
        list[#list + 1] = t
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

-- Combined list shown in the window: Recipes section, then Reagents section
function ns.BuildDisplay()
    -- Walk the recipes top to bottom. Each one reserves the reagents it needs
    -- for its full queued count, so recipes further down only see what is left.
    -- A recipe is craftable when everything it needs is still available after
    -- the recipes above it have taken their share.
    local viewed = ns.ViewRecipes()
    local recipes = {}
    local remaining = {}
    for _, item in ipairs(ns.SortedRecipes(viewed)) do
        local r = item.r
        local units = r.count
        for itemID, reg in pairs(r.reagents) do
            if remaining[itemID] == nil then
                remaining[itemID] = ns.GetOwned(itemID, ns.db.includeBank)
            end
            local avail = remaining[itemID]
            units = math.min(units, math.max(0, math.floor(avail / reg.qty)))
            remaining[itemID] = avail - reg.qty * r.count
        end
        recipes[#recipes + 1] = {
            kind = "recipe",
            key = item.key,
            name = r.name,
            count = r.count,
            icon = ResolveRecipeIcon(r),
            recipe = r,
            owner = r.owner,
            craftable = units,
            done = units >= r.count
        }
    end

    local display = {}
    if #recipes == 0 then
        return display
    end

    display[#display + 1] = {
        kind = "header",
        text = "Recipes"
    }
    for _, e in ipairs(recipes) do
        display[#display + 1] = e
    end

    display[#display + 1] = {
        kind = "header",
        text = ns.IsAllView() and "Reagents (all characters)" or "Reagents"
    }
    for _, e in ipairs(BuildList(viewed)) do
        e.kind = "reagent"
        display[#display + 1] = e
    end
    return display, recipes[1]
end
