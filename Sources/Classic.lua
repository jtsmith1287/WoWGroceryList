-- Recipe source 2: Classic-style profession windows (TradeSkillFrame / CraftFrame).
local _, ns = ...

------------------------------------------------------------
-- Source 2: Classic-style profession windows (TradeSkillFrame / CraftFrame)
------------------------------------------------------------
local CLASSIC = {
    trade = {
        prefix = "TradeSkillSkill",
        maxButtons = 40,
        available = function()
            return GetTradeSkillInfo ~= nil
        end,
        info = function(i)
            local name, skillType = GetTradeSkillInfo(i)
            return name, skillType
        end,
        link = function(i)
            return GetTradeSkillRecipeLink(i)
        end,
        numReagents = function(i)
            return GetTradeSkillNumReagents(i)
        end,
        reagentInfo = function(i, j)
            return GetTradeSkillReagentInfo(i, j)
        end,
        reagentLink = function(i, j)
            return GetTradeSkillReagentItemLink(i, j)
        end
    },
    craft = {
        prefix = "Craft",
        maxButtons = 40,
        available = function()
            return GetCraftInfo ~= nil
        end,
        info = function(i)
            local name, _, craftType = GetCraftInfo(i)
            return name, craftType
        end,
        link = function(i)
            return GetCraftRecipeLink(i)
        end,
        numReagents = function(i)
            return GetCraftNumReagents(i)
        end,
        reagentInfo = function(i, j)
            return GetCraftReagentInfo(i, j)
        end,
        reagentLink = function(i, j)
            return GetCraftReagentItemLink(i, j)
        end
    }
}

local function ClassicKey(link, name)
    if ns.IsStr(link) then
        local id = tonumber(link:match("enchant:(%d+)")) or tonumber(link:match("spell:(%d+)"))
        if id then
            return "s" .. id, id
        end
    end
    return "n" .. name, nil
end

local function ClassicRecipe(api, index)
    local name, recipeType = ns.Try(api.info, index)
    if not ns.IsStr(name) or recipeType == "header" or recipeType == "subheader" then
        return nil
    end
    return name
end

local function ClassicAdd(api, index)
    local name = ClassicRecipe(api, index)
    if not name then
        return
    end

    local key, spellID = ClassicKey(ns.Try(api.link, index), name)
    local reagents = {}
    local num = ns.Try(api.numReagents, index)
    for j = 1, (ns.IsNum(num) and num or 0) do
        local rName, icon, qty = ns.Try(api.reagentInfo, index, j)
        local rLink = ns.Try(api.reagentLink, index, j)
        local itemID = ns.IsStr(rLink) and tonumber(rLink:match("item:(%d+)"))
        if itemID then
            ns.AddReagent(reagents, itemID, qty, rName, icon)
        end
    end
    ns.AddTracked(key, spellID, name, reagents)
end

local function ClassicRemove(api, index)
    local name = ClassicRecipe(api, index)
    if not name then
        return
    end
    local key = ClassicKey(ns.Try(api.link, index), name)
    ns.RemoveTracked(key, name)
end

local hooked = {}

local OnClassicClick = ns.Guard("recipe click", function(self, mouseButton)
    if not ns.ModifierDown() then
        return
    end
    local api, index = self.glApi, self:GetID()
    if not api or not ns.IsNum(index) or index == 0 then
        return
    end
    if mouseButton == "LeftButton" then
        ClassicAdd(api, index)
    elseif mouseButton == "RightButton" then
        ClassicRemove(api, index)
    end
end)

function ns.HookClassicButtons()
    for _, api in pairs(CLASSIC) do
        if ns.Try(api.available) then
            for i = 1, api.maxButtons do
                local btn = _G[api.prefix .. i]
                if type(btn) == "table" and type(btn.HookScript) == "function" and not hooked[btn] then
                    local ok, err = pcall(function()
                        btn.glApi = api
                        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        btn:HookScript("OnClick", OnClassicClick)
                    end)
                    if ok then
                        hooked[btn] = true
                    else
                        ns.LogError("hooking " .. api.prefix .. i, err)
                        hooked[btn] = true -- don't retry (and re-log) every event
                    end
                end
            end
        end
    end
end
