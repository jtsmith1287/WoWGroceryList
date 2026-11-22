-- Recipe source 1: Alt+click in the retail-style profession window.
local _, ns = ...

------------------------------------------------------------
-- Source 1: Retail-style profession window (what Forever appears to use)
-- We detect clicks globally and look at the frame under the mouse,
-- so we don't depend on the window's internal frame names.
------------------------------------------------------------
local function GetFocusFrame()
    if GetMouseFoci then
        local ok, t = pcall(GetMouseFoci)
        if ok and type(t) == "table" then
            return t[1]
        end
    elseif GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        if ok then
            return f
        end
    end
end

local function RecipeInfoUnderMouse()
    local focus = GetFocusFrame()
    for _ = 1, 5 do
        if not focus then
            return nil
        end

        if type(focus.GetElementData) == "function" then
            local ok, node = pcall(focus.GetElementData, focus)
            if ok and node then
                local data = node
                if type(node.GetData) == "function" then
                    local ok2, d = pcall(node.GetData, node)
                    if ok2 then
                        data = d
                    end
                end
                if type(data) == "table" and type(data.recipeInfo) == "table" then
                    return data.recipeInfo
                end
            end
        end

        focus = type(focus.GetParent) == "function" and focus:GetParent() or nil
    end
end

function ns.ReadRetailReagents(recipeID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then
        return nil
    end
    local schematic = ns.Try(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
        return nil
    end

    local basicType = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if type(slot) == "table" then
            local isBasic = slot.reagentType == nil or basicType == nil or slot.reagentType == basicType
            local first = type(slot.reagents) == "table" and slot.reagents[1]
            local itemID = type(first) == "table" and first.itemID
            if isBasic and ns.IsNum(itemID) and ns.IsNum(slot.quantityRequired) then
                local name, icon = ns.ItemNameIcon(itemID)
                ns.AddReagent(reagents, itemID, slot.quantityRequired, name, icon)
            end
        end
    end
    return reagents
end

function ns.OnGlobalMouseDown(button)
    local down = ns.ModifierDown()
    local info = (down or ns.trace) and RecipeInfoUnderMouse() or nil

    if ns.trace then
        local label = "none"
        if info then
            label = tostring(ns.IsStr(info.name) and info.name or info.recipeID)
        end
        ns.Print(string.format("click %s, %s down=%s, recipe=%s", tostring(button), ns.CurrentModifier(), tostring(down),
            label))
    end

    if not down or not info or not ns.IsNum(info.recipeID) then
        return
    end
    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    local id = info.recipeID
    local name = ns.IsStr(info.name) and info.name or ("Recipe " .. id)
    local key = "s" .. id

    if button == "LeftButton" then
        local reagents = ns.ReadRetailReagents(id)
        if not reagents then
            ns.Print("Couldn't read reagents for " .. name .. ". Try /gl debug.")
            return
        end
        ns.AddTracked(key, id, name, reagents)
    else
        ns.RemoveTracked(key, name)
    end
end
