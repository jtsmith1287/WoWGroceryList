-- Game API wrappers: owned item counts, item and spell names and icons.
local _, ns = ...

------------------------------------------------------------
-- Game API wrappers
------------------------------------------------------------
function ns.GetOwned(itemID, includeBank)
    if includeBank == nil then
        includeBank = ns.db.includeBank
    end
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    local n = ns.Try(fn, itemID, includeBank)
    if ns.IsNum(n) then
        return n
    end
    return 0
end

function ns.GetSpellNameByID(spellID)
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = ns.Try(C_Spell.GetSpellName, spellID)
    elseif GetSpellInfo then
        name = ns.Try(GetSpellInfo, spellID)
    end
    if ns.IsStr(name) then
        return name
    end
end

-- name / icon for an item id (either may be nil until the item is cached)
function ns.ItemNameIcon(itemID)
    if not ns.IsNum(itemID) then
        return nil, nil
    end
    local name, icon

    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local ok, n, _, _, _, _, _, _, _, _, i = pcall(getInfo, itemID)
        if ok then
            if ns.IsStr(n) then
                name = n
            end
            icon = i
        end
    end

    if not icon then
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if instant then
            local ok, _, _, _, _, i = pcall(instant, itemID)
            if ok then
                icon = i
            end
        end
    end

    if not ns.IsNum(icon) and not ns.IsStr(icon) then
        icon = nil
    end
    return name, icon
end

function ns.AddReagent(reagents, itemID, qty, name, icon)
    if not ns.IsNum(itemID) or not ns.IsNum(qty) or qty < 1 then
        return
    end
    qty = math.floor(qty)
    local r = reagents[itemID]
    if r then
        r.qty = r.qty + qty
    else
        reagents[itemID] = {
            name = ns.IsStr(name) and name or nil,
            icon = icon,
            qty = qty
        }
    end
end
