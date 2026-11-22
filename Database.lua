-- Saved variables: validates GroceryListDB and every character's saved list so a
-- damaged or old file can never break the addon.
local _, ns = ...

------------------------------------------------------------
-- Saved variables: validate everything so a damaged or old
-- GroceryListDB can never break the addon.
------------------------------------------------------------
ns.VALID_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true
}

-- Validates one character's saved list: drops damaged entries and renumbers the order.
function ns.SanitizeCharacter(data, resetIcons)
    if type(data.recipes) ~= "table" then
        data.recipes = {}
    end
    if resetIcons then
        for _, r in pairs(data.recipes) do
            if type(r) == "table" then
                r.icon = nil
            end
        end
    end

    for key, r in pairs(data.recipes) do
        local valid = ns.IsStr(key) and type(r) == "table" and ns.IsStr(r.name) and ns.IsNum(r.count) and r.count >= 1 and
                          type(r.reagents) == "table"

        if valid then
            r.count = math.min(math.floor(r.count), ns.MAX_COUNT)
            if not ns.IsNum(r.spellID) then
                r.spellID = nil
            end
            if r.icon ~= nil and not ns.IsNum(r.icon) and not ns.IsStr(r.icon) then
                r.icon = nil
            end

            local any = false
            for itemID, reg in pairs(r.reagents) do
                if ns.IsNum(itemID) and type(reg) == "table" and ns.IsNum(reg.qty) and reg.qty >= 1 then
                    reg.qty = math.floor(reg.qty)
                    if not ns.IsStr(reg.name) then
                        reg.name = nil
                    end
                    any = true
                else
                    r.reagents[itemID] = nil
                end
            end
            valid = any
        end

        if not valid then
            data.recipes[key] = nil
        end
    end

    -- stable, gap-free display order (legacy recipes without one sort by name)
    local ordered = {}
    for key, r in pairs(data.recipes) do
        ordered[#ordered + 1] = {
            key = key,
            r = r
        }
    end
    table.sort(ordered, function(a, b)
        local sa = ns.IsNum(a.r.seq) and a.r.seq or math.huge
        local sb = ns.IsNum(b.r.seq) and b.r.seq or math.huge
        if sa ~= sb then
            return sa < sb
        end
        return a.r.name < b.r.name
    end)
    for i, item in ipairs(ordered) do
        item.r.seq = i
    end
end

function ns.SanitizeDB()
    if type(GroceryListDB) ~= "table" then
        GroceryListDB = {}
    end
    ns.db = GroceryListDB

    -- Per-character data (recipe list, window shown/hidden) is stored inside
    -- GroceryListDB.chars under "Name-Realm". Which character is playing is only
    -- worked out later, at login (see SelectCharacter).
    if type(ns.db.chars) ~= "table" then
        ns.db.chars = {}
    end

    -- User-configurable settings
    if type(ns.db.includeBank) ~= "boolean" then
        ns.db.includeBank = true
    end

    if not ns.IsNum(ns.db.maxRows) then
        ns.db.maxRows = 24
    end

    ns.db.maxRows = math.max(8, math.min(40, math.floor(ns.db.maxRows)))
    if not (ns.IsStr(ns.db.modifier) and ns.MODIFIERS[ns.db.modifier]) then
        ns.db.modifier = "alt"
    end

    local pos = ns.db.pos
    if type(pos) ~= "table" or not ns.VALID_POINTS[pos.point] or not ns.VALID_POINTS[pos.relPoint] or not ns.IsNum(pos.x) or
        not ns.IsNum(pos.y) then
        ns.db.pos = nil
    end

    -- check every character's saved recipes; icons cached by older versions
    -- may be wrong, so they are re-resolved once
    local resetIcons = ns.db.iconVersion ~= 2
    for _, data in pairs(ns.db.chars) do
        if type(data) == "table" then
            ns.SanitizeCharacter(data, resetIcons)
        end
    end
    ns.db.iconVersion = 2
end
