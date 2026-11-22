-- The shopping list data: add, remove, reorder and adjust recipes.
local _, ns = ...

-- Recipes in the order the player arranged them: { {key=, r=}, ... }
function ns.SortedRecipes(recipes)
    local list = {}
    for key, r in pairs(recipes or ns.cdb.recipes) do
        if type(r) == "table" and ns.IsStr(r.name) then
            list[#list + 1] = {
                key = key,
                r = r
            }
        end
    end
    table.sort(list, function(a, b)
        local sa = ns.IsNum(a.r.seq) and a.r.seq or math.huge
        local sb = ns.IsNum(b.r.seq) and b.r.seq or math.huge
        if sa ~= sb then
            return sa < sb
        end
        return a.r.name < b.r.name
    end)
    return list
end

local function NextSeq(recipes)
    local highest = 0
    for _, r in pairs(recipes or ns.cdb.recipes) do
        if ns.IsNum(r.seq) and r.seq > highest then
            highest = r.seq
        end
    end
    return highest + 1
end

------------------------------------------------------------
-- Shopping list data
-- cdb.recipes[key] = { name, spellID, count, icon, reagents = { [itemID] = {name, icon, qty} } }
------------------------------------------------------------
-- recipes (optional): the list to add to; default is this character's own list (Alt+click).
-- count (optional): starting quantity for a recipe that isn't on the list yet.
-- insertAtTop (optional): put a new recipe first in the list instead of appending it.
function ns.AddTracked(key, spellID, name, reagents, icon, recipes, count, insertAtTop)
    if not ns.IsStr(key) or not ns.IsStr(name) or type(reagents) ~= "table" then
        return
    end

    local ownList = recipes == nil
    recipes = recipes or ns.cdb.recipes
    count = (ns.IsNum(count) and count >= 1) and math.min(math.floor(count), ns.MAX_COUNT) or 1

    local entry = recipes[key]
    if entry then
        if entry.count >= ns.MAX_COUNT then
            ns.Print(name .. " is already at the maximum count (" .. ns.MAX_COUNT .. ").")
            return
        end
        entry.count = entry.count + 1
        entry.icon = entry.icon or icon
    else
        if next(reagents) == nil then
            ns.Print(name .. " has no reagents to track.")
            return
        end
        local seq
        if insertAtTop then
            for i, item in ipairs(ns.SortedRecipes(recipes)) do
                item.r.seq = i + 1
            end
            seq = 1
        else
            seq = NextSeq(recipes)
        end
        entry = {
            name = name,
            spellID = ns.IsNum(spellID) and spellID or nil,
            count = count,
            reagents = reagents,
            icon = icon,
            seq = seq
        }
        recipes[key] = entry
    end

    ns.Print(name .. " x" .. entry.count)
    if ownList then
        ns.viewKey = nil -- show the list that just changed
    end
    ns.cdb.shown = true
    if ns.frame then
        ns.frame:Show()
    end
    ns.Refresh()
end

function ns.RemoveTracked(key, name, recipes)
    recipes = recipes or ns.cdb.recipes
    if ns.IsStr(key) and recipes[key] then
        recipes[key] = nil
        ns.Print("Removed " .. (ns.IsStr(name) and name or "recipe"))
        ns.Refresh()
    end
end

function ns.RemoveReagent(itemID)
    local recipes = ns.ViewRecipes()
    for key, recipe in pairs(recipes) do
        recipe.reagents[itemID] = nil
        if next(recipe.reagents) == nil then
            recipes[key] = nil
        end
    end
    ns.Refresh()
end

-- Move a recipe next to another one (after = true puts it below the target)
function ns.MoveRecipe(srcKey, dstKey, after)
    local recipes = ns.ViewRecipes()
    if srcKey == dstKey or not recipes[srcKey] or not recipes[dstKey] then
        ns.Refresh()
        return
    end

    local keys = {}
    for _, item in ipairs(ns.SortedRecipes(recipes)) do
        if item.key ~= srcKey then
            keys[#keys + 1] = item.key
        end
    end

    local at = #keys + 1
    for i, k in ipairs(keys) do
        if k == dstKey then
            at = after and i + 1 or i
            break
        end
    end
    table.insert(keys, at, srcKey)

    for i, k in ipairs(keys) do
        recipes[k].seq = i
    end
    ns.Refresh()
end

function ns.AdjustCount(key, delta)
    if ns.IsAllView() then
        return
    end
    local recipes = ns.ViewRecipes()
    local entry = ns.IsStr(key) and recipes[key]
    if not entry or not ns.IsNum(delta) then
        return
    end
    entry.count = math.min(entry.count + delta, ns.MAX_COUNT)
    if entry.count <= 0 then
        recipes[key] = nil
    end
    ns.Refresh()
end
