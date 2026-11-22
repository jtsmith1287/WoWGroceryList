-- GroceryList entry point: registers game events and starts the addon.
-- Everything else lives in the files listed in GroceryList.toc, which share the
-- addon's private namespace table (ns).
local ADDON_NAME, ns = ...

------------------------------------------------------------
-- Events
------------------------------------------------------------
local events = CreateFrame("Frame")
ns.registered = {}

local function Reg(event)
    ns.registered[event] = pcall(events.RegisterEvent, events, event)
end

local itemInfoPending = false

local function ScheduleRefresh()
    if itemInfoPending then
        return
    end
    itemInfoPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            itemInfoPending = false
            ns.Refresh()
        end)
    else
        itemInfoPending = false
        ns.Refresh()
    end
end

-- builds the window once the playing character is known
local function StartWindow()
    local ok, err = pcall(ns.CreateMainFrame)
    if not ok then
        ns.LogError("creating window", err)
        if ns.frame then
            ns.frame:Hide()
        end
        ns.frame = nil
        ns.Print("Couldn't create the list window. Type /gl errors for details.")
    end
    ns.Refresh()
end

events:SetScript("OnEvent", ns.Guard("event", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            ns.SanitizeDB()
            ns.RegisterSettings()
        end
        -- Blizzard_TradeSkillUI / Blizzard_CraftUI load on demand
        if arg1 == ADDON_NAME or (ns.IsStr(arg1) and arg1:find("^Blizzard_")) then
            ns.HookClassicButtons()
        end
    elseif not ns.db then
        return
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- PLAYER_ENTERING_WORLD is only a second chance if the name wasn't ready at PLAYER_LOGIN
        if not ns.cdb and ns.SelectCharacter(event == "PLAYER_ENTERING_WORLD") then
            StartWindow()
        end
    elseif not ns.cdb then
        return
    elseif event == "GLOBAL_MOUSE_DOWN" then
        ns.OnGlobalMouseDown(arg1)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ns.IsStr(arg1) and arg1 == "player" then
            ns.OnCraftSucceeded(arg3)
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" then
        ns.Refresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        ScheduleRefresh()
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        ns.ScheduleIndex()
    else
        -- TRADE_SKILL_SHOW / UPDATE, CRAFT_SHOW / UPDATE
        ns.HookClassicButtons()
        if event == "TRADE_SKILL_SHOW" then
            ns.ScheduleIndex()
        end
    end
end))

Reg("ADDON_LOADED")
Reg("PLAYER_LOGIN")
Reg("PLAYER_ENTERING_WORLD")
Reg("GLOBAL_MOUSE_DOWN")
Reg("BAG_UPDATE_DELAYED")
Reg("PLAYERBANKSLOTS_CHANGED")
Reg("GET_ITEM_INFO_RECEIVED")
Reg("UNIT_SPELLCAST_SUCCEEDED")
Reg("TRADE_SKILL_SHOW")
Reg("TRADE_SKILL_LIST_UPDATE")
Reg("TRADE_SKILL_DATA_SOURCE_CHANGED")
Reg("TRADE_SKILL_UPDATE")
Reg("CRAFT_SHOW")
Reg("CRAFT_UPDATE")
