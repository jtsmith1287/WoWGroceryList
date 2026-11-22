-- Window style: the Forever (bronze) or classic border.
local _, ns = ...

------------------------------------------------------------
-- Window style
-- "dialog" and "panel" are built from Blizzard's own border pieces (NineSlice
-- layouts), which WoW Forever draws in its bronze art. "classic" is the old
-- plain tooltip look. If a layout isn't available the window falls back to classic.
------------------------------------------------------------
ns.SKIN_LAYOUTS = {
    forever = "Dialog",
}
local DEFAULT_SKIN = "forever"

function ns.CurrentSkin()
    local skin = ns.db and ns.db.skin
    if skin == "classic" or ns.SKIN_LAYOUTS[skin] then
        return skin
    end
    return DEFAULT_SKIN
end

local function ApplyClassicBackdrop(f, alpha)
    if not f.SetBackdrop then
        return
    end
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3
        }
    })
    f:SetBackdropColor(0, 0, 0, alpha)
end

-- Returns true when a Blizzard-style border was applied, false when it fell back to classic.
function ns.ApplySkin(f, alpha)
    if not f then
        return true
    end
    f.skinHosts = f.skinHosts or {}
    for _, host in pairs(f.skinHosts) do
        host:Hide()
    end

    local skin = ns.CurrentSkin()
    local layoutName = ns.SKIN_LAYOUTS[skin]
    local host

    if layoutName and NineSliceUtil and NineSliceUtil.ApplyLayoutByName and NineSliceLayouts and
        NineSliceLayouts[layoutName] then
        host = f.skinHosts[skin]
        if not host then
            host = CreateFrame("Frame", nil, f)
            host:EnableMouse(false)
            host:SetFrameLevel(f:GetFrameLevel()) -- behind everything else in the window
            host:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4) -- border sits just outside the content
            host:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
            host.bg = host:CreateTexture(nil, "BACKGROUND")
            host.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
            host.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
            if pcall(NineSliceUtil.ApplyLayoutByName, host, layoutName) then
                f.skinHosts[skin] = host
            else
                host:Hide()
                host = nil
            end
        end
    end

    if host then
        host.bg:SetColorTexture(0.09, 0.08, 0.07, alpha)
        host:Show()
        if f.SetBackdrop then
            f:SetBackdrop(nil)
        end
        return true
    end

    ApplyClassicBackdrop(f, alpha)
    return skin == "classic"
end

-- re-applies the chosen window style to the list window and the selector menus
function ns.ReskinAll()
    local ok = ns.ApplySkin(ns.frame, 0.92)
    if ns.menu then
        ns.ApplySkin(ns.menu, 0.97)
    end
    if ns.reagentMenu then
        ns.ApplySkin(ns.reagentMenu, 0.97)
    end
    return ok
end
