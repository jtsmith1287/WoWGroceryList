-- Refreshing the window, the clear-list confirmation, and the main window itself.
local _, ns = ...

local clearTarget -- character whose list the Clear confirmation will empty

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
local function RefreshImpl()
    if not ns.db or not ns.cdb or not ns.frame or not ns.frame:IsShown() then
        return
    end

    local list, top = ns.BuildDisplay()
    ns.UpdateViewButton()
    if not ns.IsOwnView() then
        top = nil -- the craft button only makes sense for this character's own recipes
    end
    ns.UpdateCraftBar(top)
    local total = #list
    ns.offset = math.max(0, math.min(ns.offset, total - ns.db.maxRows))
    local shown = math.min(total, ns.db.maxRows)

    for i = 1, shown do
        local row, d = ns.GetRow(i), list[i + ns.offset]
        row.data = d
        row:SetAlpha((d.key and d.key == ns.dragKey) and 0.4 or 1)
        row.text:ClearAllPoints()

        if d.kind == "header" then
            row.check:Hide()
            row.icon:Hide()
            row.count:Hide()
            row.plus:Hide()
            row.minus:Hide()
            row.line:Show()
            row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.text:SetText(d.text)
            row.text:SetTextColor(1, 0.82, 0)
        else
            row.line:Hide()
            row.icon:Show()
            row.count:Show()
            ns.SetIcon(row.icon, d.icon)
            row.count:ClearAllPoints()
            if d.kind == "recipe" and not ns.IsAllView() then
                row.plus:Show()
                row.minus:Show()
                row.count:SetPoint("RIGHT", row.minus, "LEFT", -2, 0)
            else
                row.plus:Hide()
                row.minus:Hide()
                row.count:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            end
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            row.text:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
            row.text:SetText(d.owner and (d.name .. " |cff9d9d9d(" .. d.owner .. ")|r") or d.name)

            if d.kind == "recipe" then
                row.check:SetShown(d.done)
                row.count:SetText("x" .. d.count)
                row.text:SetTextColor(1, 1, 1)
                row.count:SetTextColor(1, 1, 1)
            else
                row.count:SetText(math.floor(d.have) .. "/" .. math.floor(d.need))
                row.check:SetShown(d.done)
                if d.done then
                    if d.needsBank then
                        row.text:SetTextColor(1, 0.82, 0) -- Yellow (needs bank trip)
                        row.count:SetTextColor(1, 0.82, 0)
                    else
                        row.text:SetTextColor(0.3, 1, 0.3) -- Green (ready in bags)
                        row.count:SetTextColor(0.3, 1, 0.3)
                    end
                else
                    row.text:SetTextColor(1, 1, 1)
                    row.count:SetTextColor(1, 1, 1)
                end
            end
        end
        row:Show()
    end
    for i = shown + 1, #ns.rows do
        ns.rows[i].data = nil
        ns.rows[i]:Hide()
    end

    if ns.IsAllView() then
        ns.frame.empty:SetText("No recipes on any character's list.")
    elseif ns.IsOwnView() then
        ns.frame.empty:SetText(ns.ModifierLabel() .. "+Left-click a recipe in a profession window to add its reagents.")
    else
        ns.frame.empty:SetText(ns.CharName(ns.viewKey) .. " has no recipes on their list.")
    end
    ns.frame.empty:SetShown(total == 0)

    if ns.frame.viewNote then
        if total > 0 and not ns.IsOwnView() then
            ns.frame.viewNote:SetText((ns.IsAllView() and "All characters" or (ns.CharName(ns.viewKey) .. "'s list")) ..
                                       " (counts: your current bags)")
            ns.frame.viewNote:Show()
        else
            ns.frame.viewNote:Hide()
        end
    end
    ns.frame:SetHeight(total == 0 and 90 or (ns.ROW_TOP + shown * ns.ROW_HEIGHT + 10))
end

ns.Refresh = ns.Guard("refresh", RefreshImpl)

------------------------------------------------------------
-- Main window
------------------------------------------------------------
StaticPopupDialogs["GROCERYLIST_CLEAR"] = {
    text = "Clear the whole grocery list for %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = ns.Guard("clear list", function()
        local data = ns.db and clearTarget and ns.db.chars[clearTarget]
        if data and type(data.recipes) == "table" then
            wipe(data.recipes)
        end
        ns.Refresh()
    end),
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}

function ns.CreateMainFrame()
    ns.frame = CreateFrame("Frame", "GroceryListFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    ns.frame:SetSize(280, 90)
    ns.frame:SetFrameStrata("MEDIUM")
    ns.frame:SetClampedToScreen(true)
    ns.frame:SetMovable(true)
    ns.frame:EnableMouse(true)
    ns.frame:EnableMouseWheel(true)
    ns.frame:RegisterForDrag("LeftButton")

    ns.ApplySkin(ns.frame, 0.92)

    -- restore the saved position; fall back to the default if it can't be applied
    local placed = false
    local pos = ns.db.pos
    if pos then
        placed = pcall(function()
            ns.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        end)
        if not placed then
            ns.frame:ClearAllPoints()
            ns.db.pos = nil
        end
    end
    if not placed then
        ns.frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end

    ns.frame:SetScript("OnDragStart", ns.Guard("drag start", function(self)
        self:StartMoving()
    end))
    ns.frame:SetScript("OnDragStop", ns.Guard("drag stop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if ns.VALID_POINTS[point] and ns.VALID_POINTS[relPoint] and ns.IsNum(x) and ns.IsNum(y) then
            ns.db.pos = {
                point = point,
                relPoint = relPoint,
                x = x,
                y = y
            }
        end
    end))
    ns.frame:SetScript("OnMouseWheel", ns.Guard("scroll", function(_, delta)
        if not ns.IsNum(delta) then
            return
        end
        ns.offset = math.max(0, ns.offset - delta)
        ns.Refresh()
    end))
    ns.frame:SetScript("OnShow", ns.Refresh)
    ns.frame:SetScript("OnHide", function()
        if ns.menu then
            ns.menu:Hide()
        end
    end)

    local title = ns.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Grocery List")

    -- character selector: view this character's list, an alt's list, or everyone's combined
    local viewBtn = CreateFrame("Button", nil, ns.frame)
    viewBtn:SetSize(104, 18)
    viewBtn:SetPoint("LEFT", title, "RIGHT", 8, 0)
    viewBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    viewBtn.bg = viewBtn:CreateTexture(nil, "BACKGROUND")
    viewBtn.bg:SetAllPoints()
    viewBtn.bg:SetColorTexture(1, 1, 1, 0.08)
    viewBtn.arrow = viewBtn:CreateTexture(nil, "ARTWORK")
    viewBtn.arrow:SetSize(18, 18)
    viewBtn.arrow:SetPoint("RIGHT", 2, 0)
    viewBtn.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    viewBtn.text = viewBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    viewBtn.text:SetPoint("LEFT", 4, 0)
    viewBtn.text:SetPoint("RIGHT", viewBtn.arrow, "LEFT", 2, 0)
    viewBtn.text:SetJustifyH("LEFT")
    viewBtn.text:SetWordWrap(false)
    viewBtn:SetScript("OnClick", ns.Guard("view menu", function(self)
        GameTooltip:Hide()
        ns.ToggleViewMenu(self)
    end))
    viewBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Choose whose list to view", 1, 1, 1)
        GameTooltip:Show()
    end)
    viewBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    ns.frame.viewButton = viewBtn

    local close = CreateFrame("Button", nil, ns.frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", ns.Guard("close button", function()
        ns.cdb.shown = false
        ns.frame:Hide()
    end))

    local clear = CreateFrame("Button", nil, ns.frame, "UIPanelButtonTemplate")
    clear:SetSize(46, 18)
    clear:SetPoint("RIGHT", close, "LEFT", 2, 0)
    clear:SetText("Clear")
    ns.frame.clearButton = clear
    clear:SetScript("OnClick", ns.Guard("clear button", function()
        if ns.IsAllView() then
            return
        end
        clearTarget = ns.viewKey or ns.charKey
        StaticPopup_Show("GROCERYLIST_CLEAR", ns.CharName(clearTarget))
    end))

    -- the craft bar is optional: if it can't be built, the rest of the window still works
    local ok, craft = pcall(ns.CreateCraftBar, ns.frame)
    if ok then
        ns.frame.craft = craft
    else
        ns.LogError("creating craft bar", craft)
    end

    ns.frame.dropLine = ns.frame:CreateTexture(nil, "OVERLAY")
    ns.frame.dropLine:SetHeight(2)
    ns.frame.dropLine:SetColorTexture(1, 0.82, 0, 1)
    ns.frame.dropLine:Hide()

    ns.frame.empty = ns.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ns.frame.empty:SetPoint("TOPLEFT", 12, -32)
    ns.frame.empty:SetPoint("TOPRIGHT", -12, -32)
    ns.frame.empty:SetJustifyH("LEFT")

    -- shown in the craft bar's spot while looking at someone else's list (or everyone's)
    ns.frame.viewNote = ns.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ns.frame.viewNote:SetPoint("TOPLEFT", 12, -32)
    ns.frame.viewNote:SetPoint("TOPRIGHT", -12, -32)
    ns.frame.viewNote:SetJustifyH("LEFT")
    ns.frame.viewNote:SetWordWrap(false)
    ns.frame.viewNote:Hide()

    ns.frame:SetShown(ns.cdb.shown ~= false)
end
