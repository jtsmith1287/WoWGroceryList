-- List rows: icons, tooltips, drag-to-reorder and click handling.
local _, ns = ...

------------------------------------------------------------
-- UI
------------------------------------------------------------
function ns.SetIcon(tex, icon)
    if ns.IsStr(icon) and C_Texture and C_Texture.GetAtlasInfo and ns.Try(C_Texture.GetAtlasInfo, icon) then
        if pcall(tex.SetAtlas, tex, icon) then
            return
        end
    end
    if not ns.IsNum(icon) and not ns.IsStr(icon) then
        icon = ns.QUESTION_MARK
    end
    if not pcall(tex.SetTexture, tex, icon) then
        pcall(tex.SetTexture, tex, ns.QUESTION_MARK)
    end
end

local function ShowReagentTooltip(self, d)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. d.id)
    GameTooltip:AddLine(" ")
    if ns.db.includeBank then
        local inBags = ns.GetOwned(d.id, false)
        GameTooltip:AddLine(string.format("Owned: %d (Bags: %d, Bank: %d)", math.floor(d.have), math.floor(inBags),
            math.floor(d.have - inBags)), 1, 1, 1)
    end
    GameTooltip:AddLine("Needed for:", 1, 0.82, 0)
    for _, u in ipairs(d.uses) do
        GameTooltip:AddLine("  " .. u.name .. " x" .. u.count .. " (" .. u.per .. " each)", 1, 1, 1)
    end
    GameTooltip:AddLine("Click: open or add as recipe", 0.6, 0.6, 0.6)
    if not ns.IsAllView() then
        GameTooltip:AddLine(ns.ModifierLabel() .. "+Right-click: remove reagent from list", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function ShowRecipeTooltip(self, d)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.name, 1, 1, 1)
    GameTooltip:AddLine("Queued: x" .. d.count, 1, 0.82, 0)
    if d.owner then
        GameTooltip:AddLine("On " .. d.owner .. "'s list", 0.6, 0.6, 0.6)
    end
    if d.done then
        GameTooltip:AddLine("Craftable now: " .. d.craftable .. " of " .. d.count, 0.3, 1, 0.3)
    elseif d.craftable > 0 then
        GameTooltip:AddLine("Craftable now: " .. d.craftable .. " of " .. d.count, 1, 0.82, 0)
    else
        GameTooltip:AddLine("Craftable now: 0 of " .. d.count, 1, 0.3, 0.3)
    end
    GameTooltip:AddLine("(after materials set aside for recipes above)", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Reagents:", 1, 0.82, 0)

    local needs = {}
    for id, reg in pairs(d.recipe.reagents) do
        local name = ns.ItemNameIcon(id)
        needs[#needs + 1] = {
            name = name or reg.name or ("Item " .. id),
            per = reg.qty
        }
    end
    table.sort(needs, function(a, b)
        return a.name < b.name
    end)
    for _, n in ipairs(needs) do
        GameTooltip:AddLine("  " .. n.per .. " x " .. n.name .. "  (" .. (n.per * d.count) .. " total)", 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    if ns.IsOwnView() then
        GameTooltip:AddLine("Click: open in profession window", 0.6, 0.6, 0.6)
    end
    if not ns.IsAllView() then
        GameTooltip:AddLine("Drag: change the crafting order", 0.6, 0.6, 0.6)
        GameTooltip:AddLine(ns.ModifierLabel() .. "+Right-click: remove recipe from list", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- Drag and drop reordering of recipe rows
ns.dragKey = nil
local lastDragStop = 0

-- Which visible recipe row is under the cursor, and is the cursor in its lower half?
local function FindDropTarget()
    local cx, cy = GetCursorPosition()
    for i = 1, #ns.rows do
        local row = ns.rows[i]
        if row:IsShown() and row.data and row.data.kind == "recipe" then
            local scale = row:GetEffectiveScale()
            local left, bottom, width, height = row:GetRect()
            if scale and scale > 0 and left then
                local x, y = cx / scale, cy / scale
                if x >= left and x <= left + width and y >= bottom and y <= bottom + height then
                    return row, y < bottom + height / 2
                end
            end
        end
    end
end

local function HideDropLine()
    if ns.frame and ns.frame.dropLine then
        ns.frame.dropLine:Hide()
    end
end

local function CancelDrag()
    ns.dragKey = nil
    if ns.frame then
        ns.frame:SetScript("OnUpdate", nil)
    end
    HideDropLine()
    ns.Refresh()
end

local function UpdateDropLine()
    local row, after = FindDropTarget()
    local line = ns.frame.dropLine
    if not line then
        return
    end
    if row and row.data.key ~= ns.dragKey then
        line:ClearAllPoints()
        if after then
            line:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
            line:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
        else
            line:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 0)
        end
        line:Show()
    else
        line:Hide()
    end
end

local function DragOnUpdate()
    local ok, err = pcall(UpdateDropLine)
    if not ok then
        ns.LogError("drag", err)
        CancelDrag()
    end
end

local function StartDrag(row)
    local d = row.data
    if not ns.frame or not d or d.kind ~= "recipe" or ns.IsAllView() then
        return
    end
    GameTooltip:Hide()
    ns.dragKey = d.key
    ns.frame:SetScript("OnUpdate", DragOnUpdate)
    ns.Refresh() -- dims the row being dragged
end

local function FinishDrag()
    lastDragStop = GetTime()
    if not ns.dragKey or not ns.frame then
        return
    end

    local key = ns.dragKey
    local row, after = FindDropTarget()
    ns.dragKey = nil
    ns.frame:SetScript("OnUpdate", nil)
    HideDropLine()

    if row and row.data and row.data.key then
        ns.MoveRecipe(key, row.data.key, after)
    else
        ns.Refresh()
    end
end

function ns.GetRow(i)
    local row = ns.rows[i]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, ns.frame)
    row:SetHeight(ns.ROW_HEIGHT)
    row:SetPoint("TOPLEFT", ns.frame, "TOPLEFT", 10, -(ns.ROW_TOP + (i - 1) * ns.ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", ns.frame, "TOPRIGHT", -10, -(ns.ROW_TOP + (i - 1) * ns.ROW_HEIGHT))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")

    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(14, 14)
    row.check:SetPoint("LEFT", 0, 0)
    row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 17, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", 0, 0)
    row.count:SetJustifyH("RIGHT")

    -- standard +/- buttons (recipe rows only)
    local function MakeStepButton(kind, delta)
        local b = CreateFrame("Button", nil, row)
        b:SetSize(16, 16)
        b:SetNormalTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        b:SetScript("OnClick", ns.Guard("recipe count button", function()
            local d = row.data
            if d and d.kind == "recipe" then
                ns.AdjustCount(d.key, delta)
            end
        end))
        return b
    end
    row.plus = MakeStepButton("Plus", 1)
    row.plus:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.minus = MakeStepButton("Minus", -1)
    row.minus:SetPoint("RIGHT", row.plus, "LEFT", 0, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    -- underline used by section headers (the divider)
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", 0, 0)
    row.line:SetPoint("BOTTOMRIGHT", 0, 0)
    row.line:SetColorTexture(1, 0.82, 0, 0.5)

    row:SetScript("OnClick", ns.Guard("list click", function(self, button)
        local d = self.data
        if not d then
            return
        end
        if button == "LeftButton" then
            -- a click that merely ends a drag shouldn't open the recipe
            if d.kind == "recipe" and ns.IsOwnView() and not ns.ModifierDown() and GetTime() - lastDragStop > 0.25 then
                ns.OpenRecipe(d.recipe)
            elseif d.kind == "reagent" and not ns.ModifierDown() and ns.ShowReagentMenu then
                GameTooltip:Hide()
                ns.ShowReagentMenu(self, d)
            end
            return
        end
        if button ~= "RightButton" or not ns.ModifierDown() then
            return
        end
        if ns.IsAllView() then
            ns.Print("Pick a single character in the list selector to remove things.")
            return
        end
        if d.kind == "recipe" then
            ns.RemoveTracked(d.key, d.name, ns.ViewRecipes())
        elseif d.kind == "reagent" then
            ns.Print("Removed " .. d.name)
            ns.RemoveReagent(d.id)
        end
    end))

    row:SetScript("OnEnter", ns.Guard("tooltip", function(self)
        local d = self.data
        if not d or d.kind == "header" then
            return
        end
        if d.kind == "reagent" then
            ShowReagentTooltip(self, d)
        else
            ShowRecipeTooltip(self, d)
        end
    end))
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnDragStart", ns.Guard("drag start", StartDrag))
    row:SetScript("OnDragStop", ns.Guard("drag stop", FinishDrag))

    ns.rows[i] = row
    return row
end
