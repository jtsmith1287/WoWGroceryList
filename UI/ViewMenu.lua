-- Character selector drop-down next to the title.
local _, ns = ...

------------------------------------------------------------
-- Character selector (drop-down next to the title)
-- Hand-built rather than using Blizzard's drop-down templates, so it works
-- the same on every client version.
------------------------------------------------------------
ns.MENU_ROW_HEIGHT = 18
ns.menu = nil
local menuCatcher = nil
local menuRows = {}

local function SetView(key)
    ns.viewKey = (key ~= ns.charKey) and key or nil
    ns.offset = 0
    if ns.menu then
        ns.menu:Hide()
    end
    ns.Refresh()
end

local function GetMenuRow(i)
    local row = menuRows[i]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, ns.menu)
    row:SetHeight(ns.MENU_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", ns.menu, "TOPLEFT", 6, -(6 + (i - 1) * ns.MENU_ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", ns.menu, "TOPRIGHT", -6, -(6 + (i - 1) * ns.MENU_ROW_HEIGHT))
    row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(14, 14)
    row.check:SetPoint("LEFT", 0, 0)
    row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 18, 0)
    row.text:SetPoint("RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", ns.Guard("view menu click", function(self)
        if self.viewKey then
            SetView(self.viewKey)
        end
    end))

    menuRows[i] = row
    return row
end

local function CreateViewMenu()
    ns.menu = CreateFrame("Frame", "GroceryListViewMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    ns.menu:SetFrameStrata("FULLSCREEN_DIALOG")
    ns.menu:SetClampedToScreen(true)
    ns.menu:EnableMouse(true)
    ns.ApplySkin(ns.menu, 0.97)
    ns.menu:Hide()

    -- invisible full-screen button behind the menu: clicking anywhere else closes it
    menuCatcher = CreateFrame("Button", nil, UIParent)
    menuCatcher:SetAllPoints(UIParent)
    menuCatcher:SetFrameStrata("FULLSCREEN")
    menuCatcher:RegisterForClicks("AnyUp")
    menuCatcher:Hide()
    menuCatcher:SetScript("OnClick", function()
        ns.menu:Hide()
    end)
    ns.menu:SetScript("OnShow", function()
        menuCatcher:Show()
    end)
    ns.menu:SetScript("OnHide", function()
        menuCatcher:Hide()
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "GroceryListViewMenu") -- Escape closes it
    end
end

function ns.ToggleViewMenu(anchor)
    if not ns.menu then
        CreateViewMenu()
    end
    if ns.menu:IsShown() then
        ns.menu:Hide()
        return
    end

    local n = 0
    for _, key in ipairs(ns.CharacterKeys()) do
        n = n + 1
        local row = GetMenuRow(n)
        local count = ns.CountRecipes(ns.db.chars[key])
        row.viewKey = key
        row.check:SetShown((ns.viewKey or ns.charKey) == key)
        row.text:SetText(ns.ColoredName(key) .. (count > 0 and ("  |cff9d9d9d(" .. count .. ")|r") or ""))
        row:Show()
    end

    n = n + 1
    local all = GetMenuRow(n)
    all.viewKey = "ALL"
    all.check:SetShown(ns.viewKey == "ALL")
    all.text:SetText("|cffffd100All characters|r")
    all:Show()

    for i = n + 1, #menuRows do
        menuRows[i]:Hide()
    end

    ns.menu:SetSize(170, 12 + n * ns.MENU_ROW_HEIGHT)
    ns.menu:ClearAllPoints()
    ns.menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    ns.menu:Show()
end

ns.UpdateViewButton = function()
    if not ns.frame or not ns.frame.viewButton then
        return
    end
    ns.frame.viewButton.text:SetText(ns.IsAllView() and "|cffffd100All characters|r" or ns.ColoredName(ns.viewKey or ns.charKey))
    if ns.frame.clearButton then
        if ns.IsAllView() then
            ns.frame.clearButton:Disable() -- "All" is a read-only view
        else
            ns.frame.clearButton:Enable()
        end
    end
end
