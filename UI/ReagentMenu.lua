-- Reagent click menu: Open / Add as recipe.
local _, ns = ...

------------------------------------------------------------
-- Reagent click menu: Open / Add as recipe
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
    m:SetSize(180, 70)
    ns.ApplySkin(m, 0.97)
    m:Hide()

    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.title:SetPoint("TOPLEFT", 10, -9)
    m.title:SetPoint("TOPRIGHT", -10, -9)
    m.title:SetJustifyH("LEFT")
    m.title:SetWordWrap(false)

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
    m.open = MakeItem("Open", -26, function(item)
        ns.OpenReagentRecipe(item.id, item.name)
    end)
    m.add = MakeItem("Add as recipe", -26 - ns.MENU_ROW_HEIGHT, function(item)
        ns.AddReagentAsRecipe(item.id, item.name, item.need)
    end)

    m.note = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    m.note:SetPoint("TOPLEFT", 10, -(26 + 2 * ns.MENU_ROW_HEIGHT + 4))
    m.note:SetPoint("TOPRIGHT", -10, -(26 + 2 * ns.MENU_ROW_HEIGHT + 4))
    m.note:SetJustifyH("LEFT")
    m.note:SetJustifyV("TOP")
    m.note:SetHeight(30)

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
    m.title:SetText(d.name)

    local openReason, addReason, note
    if not anyRecipe then
        openReason = "No recipe known for " .. d.name .. " yet. Open the profession window that makes it, wait a moment, and try again."
        addReason = openReason
        note = "No recipe known yet. Open its profession window once to learn it."
    else
        if not ownRecipe then
            openReason = "Only another character knows how to make " .. d.name .. "."
            note = "Only another character knows this recipe."
        end
        if ns.IsAllView() then
            addReason = "Pick a single character in the list selector first."
            note = "Pick one character to add recipes."
        end
    end
    SetMenuItem(m.open, openReason)
    SetMenuItem(m.add, addReason)
    m.note:SetText(note or "")
    m:SetHeight(note and 100 or 70)

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 8, y / scale + 8)
    m:Show()
end
