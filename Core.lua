-- Core: addon-wide constants, shared state, and small helpers (printing, error logging,
-- safe calls, and the modifier key used for add/remove clicks).
local _, ns = ...

------------------------------------------------------------
-- Internal Settings
------------------------------------------------------------
ns.ROW_HEIGHT = 18
ns.ROW_TOP = 58
ns.MAX_COUNT = 9999
ns.QUESTION_MARK = 134400

------------------------------------------------------------
-- State shared between files (always read and written as ns.<name>)
------------------------------------------------------------
-- ns.db                 GroceryListDB (the saved variables); set in Database.lua
-- ns.cdb                per-character data (recipe list, window shown/hidden)
-- ns.charKey            "Name-Realm" of the logged-in character
-- ns.viewKey            whose list the window shows: nil = this character, "ALL" = everyone, or another character's key
-- ns.UpdateViewButton   set in UI/ViewMenu.lua
-- ns.ShowReagentMenu    the click menu for reagent rows; set in UI/ReagentMenu.lua
-- ns.Refresh            redraws the window; set in UI/MainFrame.lua
ns.frame, ns.rows, ns.offset = nil, {}, 0
ns.trace = false

function ns.Print(msg)
    print("|cff33ff99GroceryList:|r " .. tostring(msg))
end

------------------------------------------------------------
-- Safety utilities
------------------------------------------------------------
-- Retail-based clients can return "secret values" that error on arithmetic,
-- comparison or concatenation. Treat them as unusable.
local issecret = _G.issecretvalue or function()
    return false
end

function ns.IsNum(v)
    return type(v) == "number" and not issecret(v) and v == v and v > -math.huge and v < math.huge
end

function ns.IsStr(v)
    return type(v) == "string" and not issecret(v)
end

-- Errors are caught, kept in a short log (/gl errors) and reported at most
-- once every 30 seconds so a repeating problem can't flood the chat window.
ns.errorLog = {}
local lastNotice = 0

function ns.LogError(where, err)
    ns.errorLog[#ns.errorLog + 1] = string.format("[%s] %s: %s", date("%H:%M:%S"), where, tostring(err))
    if #ns.errorLog > 10 then
        table.remove(ns.errorLog, 1)
    end

    local now = GetTime()
    if now - lastNotice > 30 then
        lastNotice = now
        ns.Print("Something went wrong (" .. where .. "). Type /gl errors for details.")
    end
end

-- Wrap a handler so an error inside it is logged instead of propagating.
function ns.Guard(where, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            ns.LogError(where, err)
        end
    end
end

-- Call an API function; returns nothing if it errors.
function ns.Try(fn, ...)
    if type(fn) ~= "function" then
        return
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then
        return a, b, c, d
    end
end

------------------------------------------------------------
-- Modifier key used for add/remove clicks (/gl modifier alt|ctrl|shift)
------------------------------------------------------------
ns.MODIFIERS = {
    alt = function()
        return IsAltKeyDown()
    end,
    ctrl = function()
        return IsControlKeyDown()
    end,
    shift = function()
        return IsShiftKeyDown()
    end
}

function ns.CurrentModifier()
    local m = ns.db and ns.db.modifier
    if ns.IsStr(m) and ns.MODIFIERS[m] then
        return m
    end
    return "alt"
end

function ns.ModifierDown()
    return ns.MODIFIERS[ns.CurrentModifier()]() and true or false
end

function ns.ModifierLabel()
    local m = ns.CurrentModifier()
    return m:sub(1, 1):upper() .. m:sub(2)
end
