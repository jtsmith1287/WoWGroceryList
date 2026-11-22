-- Crafting detection: removes one of a recipe when a craft succeeds.
local _, ns = ...

------------------------------------------------------------
-- Crafting detection: remove one of the recipe when a craft succeeds
------------------------------------------------------------
function ns.OnCraftSucceeded(spellID)
    if not ns.IsNum(spellID) then
        return
    end

    local key = "s" .. spellID
    local recipe = ns.cdb.recipes[key]

    if not recipe then
        -- fallback for recipes we could only identify by name
        local spellName = ns.GetSpellNameByID(spellID)
        if spellName then
            for k, r in pairs(ns.cdb.recipes) do
                if not r.spellID and r.name == spellName then
                    key, recipe = k, r
                    break
                end
            end
        end
    end
    if not recipe then
        return
    end

    recipe.count = recipe.count - 1
    if recipe.count <= 0 then
        ns.cdb.recipes[key] = nil
    end
    ns.Refresh()
end
