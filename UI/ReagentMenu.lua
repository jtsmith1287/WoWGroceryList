-- Reagent click menu: add the remaining quantity as a recipe.
local _, ns = ...

------------------------------------------------------------
-- Reagent click menu: add the remaining quantity as a recipe
------------------------------------------------------------
ns.reagentMenu = nil
local reagentCatcher

-- reason == nil: the item works. Otherwise it is dimmed and clicking it prints the reason.
local function SetMenuItem(item, reason)
    item.reason = reason
    if reason then
        item.text:SetTextColor(0.5, 0.5, 0.5)
    else
        item.text:SetTextColor(1, 1, 1)
    end
end

local function CreateReagentMenu()
    local m = CreateFrame("Frame", "GroceryListReagentMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetClampedToScreen(true)
    m:EnableMouse(true)
    m:SetSize(180, 42)
    ns.ApplySkin(m, 0.97)
    m:Hide()

    local function MakeItem(text, y, onClick)
        local b = CreateFrame("Button", nil, m)
        b:SetHeight(ns.MENU_ROW_HEIGHT)
        b:SetPoint("TOPLEFT", m, "TOPLEFT", 6, y)
        b:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, y)
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", 8, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetText(text)
        b:RegisterForClicks("LeftButtonUp")
        b:SetFrameLevel(m:GetFrameLevel() + 2)
        b:SetScript("OnClick", ns.Guard("reagent menu", function(self)
            local item = m.item
            m:Hide()
            if not item then
                return
            end
            if self.reason then
                ns.Print(self.reason)
            else
                onClick(item)
            end
        end))
        return b
    end
    m.add = MakeItem("Add remaining as recipe", -9, function(item)
        ns.AddReagentAsRecipe(item.id, item.name, item.need)
    end)

    -- invisible full-screen button behind the menu: clicking anywhere else closes it
    reagentCatcher = CreateFrame("Button", nil, UIParent)
    reagentCatcher:SetAllPoints(UIParent)
    reagentCatcher:SetFrameStrata("FULLSCREEN")
    reagentCatcher:RegisterForClicks("AnyUp")
    reagentCatcher:Hide()
    reagentCatcher:SetScript("OnClick", function()
        m:Hide()
    end)
    m:SetScript("OnShow", function()
        reagentCatcher:Show()
    end)
    m:SetScript("OnHide", function()
        reagentCatcher:Hide()
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "GroceryListReagentMenu") -- Escape closes it
    end
    ns.reagentMenu = m
end

ns.ShowReagentMenu = function(anchor, d)
    if not ns.reagentMenu then
        CreateReagentMenu()
    end
    local m = ns.reagentMenu
    m:Hide()

    local ownRecipe = ns.FindRecipeID(d.id, nil, true)
    if not ownRecipe then
        pcall(ns.IndexProfession, true) -- a profession window that is open right now may know it
        ownRecipe = ns.FindRecipeID(d.id, nil, true)
    end
    local viewData = (not ns.IsAllView()) and ns.db.chars[ns.viewKey or ns.charKey] or nil
    local anyRecipe = ownRecipe or ns.FindRecipeID(d.id, viewData)

    m.item = {
        id = d.id,
        name = d.name,
        need = d.need
    }

    local addReason
    if not anyRecipe then
        addReason = "No recipe known for " .. d.name .. " yet. Open the profession window that makes it, wait a moment, and try again."
    elseif ns.IsAllView() then
        addReason = "Pick a single character in the list selector first."
    end
    SetMenuItem(m.add, addReason)

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 8, y / scale + 8)
    m:Show()
end
