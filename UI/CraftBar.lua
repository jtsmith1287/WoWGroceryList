-- The craft bar: Craft [icon name] x N - +
local _, ns = ...

------------------------------------------------------------
-- Craft bar:  Craft [icon name]  x  N  - +
------------------------------------------------------------
local function IsFrameShown(name)
    local f = _G[name]
    return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() and true or false
end

local function ProfessionWindowOpen()
    return IsFrameShown("ProfessionsFrame") or IsFrameShown("TradeSkillFrame") or IsFrameShown("CraftFrame")
end

local craftKey, craftQty -- craftQty is only set once you press +/-; otherwise it follows the queued count

function ns.UpdateCraftBar(top)
    local bar = ns.frame and ns.frame.craft
    if not bar then
        return
    end

    if not top then
        craftKey, craftQty = nil, nil
        bar.top = nil
        bar:Hide()
        return
    end

    if craftKey ~= top.key then
        craftKey, craftQty = top.key, nil
    end
    local qty = math.max(1, math.min(craftQty or top.count, top.count))
    bar.top, bar.qty = top, qty
    ns.SetIcon(bar.button.icon, top.icon)
    bar.button:SetText(top.name)
    bar.qtyText:SetText(qty)
    bar:Show()
end

local function AdjustCraftQty(delta)
    local bar = ns.frame and ns.frame.craft
    if not bar or not bar.top then
        return
    end
    craftQty = math.max(1, math.min((bar.qty or 1) + delta, bar.top.count))
    ns.UpdateCraftBar(bar.top)
end

local function CraftTop()
    local bar = ns.frame and ns.frame.craft
    local top = bar and bar.top
    if not top then
        return
    end

    if InCombatLockdown() then
        ns.Print("You can't craft while in combat.")
        return
    end

    local id = top.recipe.spellID
    if not (ns.IsNum(id) and C_TradeSkillUI and C_TradeSkillUI.CraftRecipe) then
        ns.Print("Crafting from the list isn't supported for " .. top.name .. ".")
        return
    end

    if not ProfessionWindowOpen() then
        ns.OpenRecipe(top.recipe)
        ns.Print("Opened " .. top.name .. ". Click Craft again to start.")
        return
    end
    ns.OpenRecipe(top.recipe)

    local qty = math.max(1, math.min(math.floor(bar.qty or 1), top.count))
    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, id, qty)
    print(err)
    if ok then
        ns.Print("Crafting " .. top.name .. " x" .. qty)
        craftQty = nil -- go back to following the queued count
    else
        ns.Print("Craft failed: " .. tostring(err))
        ns.LogError("craft", err)
    end
end

local function NewStepButton(parent, kind, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b:SetNormalTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    b:SetScript("OnClick", ns.Guard("craft quantity button", onClick))
    return b
end

function ns.CreateCraftBar(parent)
    local craft = CreateFrame("Frame", nil, parent)
    craft:SetPoint("TOPLEFT", 10, -28)
    craft:SetPoint("TOPRIGHT", -10, -28)
    craft:SetHeight(24)
    craft:Hide()

    local craftLabel = craft:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    craftLabel:SetPoint("LEFT", 0, 0)
    craftLabel:SetText("Craft")

    craft.plus = NewStepButton(craft, "Plus", function()
        AdjustCraftQty(1)
    end)
    craft.plus:SetPoint("RIGHT", craft, "RIGHT", 0, 0)
    craft.minus = NewStepButton(craft, "Minus", function()
        AdjustCraftQty(-1)
    end)
    craft.minus:SetPoint("RIGHT", craft.plus, "LEFT", 0, 0)

    craft.qtyText = craft:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    craft.qtyText:SetWidth(26)
    craft.qtyText:SetJustifyH("CENTER")
    craft.qtyText:SetPoint("RIGHT", craft.minus, "LEFT", -2, 0)

    local times = craft:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    times:SetPoint("RIGHT", craft.qtyText, "LEFT", -1, 0)
    times:SetText("x")

    local btn = CreateFrame("Button", nil, craft, "UIPanelButtonTemplate")
    btn:SetHeight(22)
    btn:SetPoint("LEFT", craftLabel, "RIGHT", 4, 0)
    btn:SetPoint("RIGHT", times, "LEFT", -4, 0)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(16, 16)
    btn.icon:SetPoint("LEFT", 5, 0)

    local fs = btn:GetFontString() or btn.Text
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
        fs:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
    end

    btn:SetScript("OnClick", ns.Guard("craft button", CraftTop))
    btn:SetScript("OnEnter", ns.Guard("craft tooltip", function(self)
        local top = craft.top
        if not top then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Craft " .. top.name .. " x" .. (craft.qty or 1), 1, 1, 1)
        GameTooltip:AddLine("Crafts the first recipe in the list.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end))
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    craft.button = btn

    return craft
end
