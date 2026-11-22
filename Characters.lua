-- Which character is playing and which character's list the window shows:
-- selection at login, merging duplicate records, and the view helpers.
local _, ns = ...

------------------------------------------------------------
-- Viewing other characters' lists
------------------------------------------------------------
function ns.IsOwnView()
    return ns.viewKey == nil or ns.viewKey == ns.charKey
end

function ns.IsAllView()
    return ns.viewKey == "ALL"
end

-- keys look like "Name-Realm"; character names never contain a hyphen, realm names can
local function ShortName(key)
    return tostring(key):match("^([^-]+)") or tostring(key)
end

local function RealmOf(key)
    return tostring(key):match("^[^-]+%-(.+)$")
end

-- plain display name; the realm is only added for characters on another realm
function ns.CharName(key)
    local name = ShortName(key)
    local realm, myRealm = RealmOf(key), RealmOf(ns.charKey)
    if realm and myRealm and realm ~= myRealm then
        name = name .. " (" .. realm .. ")"
    end
    return name
end

function ns.ColoredName(key)
    local name = ns.CharName(key)
    local data = ns.db.chars[key]
    local class = type(data) == "table" and data.class
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c and ns.IsNum(c.r) and ns.IsNum(c.g) and ns.IsNum(c.b) then
        return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5),
            math.floor(c.b * 255 + 0.5), name)
    end
    return name
end

-- every known character: this one first, then the others A-Z
function ns.CharacterKeys()
    local keys = {}
    for key, data in pairs(ns.db.chars) do
        if key ~= ns.charKey and ns.IsStr(key) and type(data) == "table" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        return ns.CharName(a):lower() < ns.CharName(b):lower()
    end)
    table.insert(keys, 1, ns.charKey)
    return keys
end

function ns.CountRecipes(data)
    local n = 0
    if type(data) == "table" and type(data.recipes) == "table" then
        for _ in pairs(data.recipes) do
            n = n + 1
        end
    end
    return n
end

-- Moves every recipe of `source` into `target`. A recipe that is in both keeps the larger count.
function ns.MergeInto(target, source)
    if type(source.recipes) ~= "table" then
        return
    end
    if type(target.recipes) ~= "table" then
        target.recipes = {}
    end

    local seq = 0
    for _, r in pairs(target.recipes) do
        if type(r) == "table" and ns.IsNum(r.seq) and r.seq > seq then
            seq = r.seq
        end
    end

    local list = {}
    for key, r in pairs(source.recipes) do
        if ns.IsStr(key) and type(r) == "table" then
            list[#list + 1] = {
                key = key,
                r = r
            }
        end
    end
    table.sort(list, function(a, b)
        local sa = ns.IsNum(a.r.seq) and a.r.seq or math.huge
        local sb = ns.IsNum(b.r.seq) and b.r.seq or math.huge
        if sa ~= sb then
            return sa < sb
        end
        return a.key < b.key
    end)

    for _, item in ipairs(list) do
        local existing = target.recipes[item.key]
        if type(existing) == "table" then
            if ns.IsNum(item.r.count) and ns.IsNum(existing.count) and item.r.count > existing.count then
                existing.count = item.r.count
            end
        else
            seq = seq + 1
            item.r.seq = seq
            target.recipes[item.key] = item.r
        end
    end

    if target.shown == nil then
        target.shown = source.shown
    end
    if target.class == nil then
        target.class = source.class
    end
end

-- true when a name or realm is real text (the game can hand out "Unknown" or nothing very early in login)
local function UsableName(text)
    return ns.IsStr(text) and text ~= "" and text ~= "Unknown" and text ~= UNKNOWNOBJECT
end

-- realm names are compared without spaces, hyphens, apostrophes or capitals
local function NormalRealm(text)
    return (tostring(text or ""):lower():gsub("[%s%-']", ""))
end

-- Works out which character is playing and points cdb/charKey at that character's list.
-- Runs at PLAYER_LOGIN (not ADDON_LOADED), when name, realm and GUID can be trusted.
-- Returns false if the character can't be identified yet. With force it uses what it has.
function ns.SelectCharacter(force)
    local name, realm, guid = UnitName("player"), GetRealmName(), UnitGUID("player")
    if not force and not (UsableName(name) and UsableName(realm)) then
        return false
    end
    name = tostring(name or "Unknown")
    realm = tostring(realm or "Unknown")
    if not ns.IsStr(guid) then
        guid = nil
    end

    local key = name .. "-" .. realm
    local wantRealm = NormalRealm(realm)

    -- does a saved record belong to this character, even under a different key?
    local function Belongs(k, data)
        if k == key then
            return true
        end
        if guid and ns.IsStr(data.guid) then
            return data.guid == guid -- the GUID settles it
        end
        if ShortName(k) ~= name then
            return false
        end
        local r = RealmOf(k)
        return r == nil or not UsableName(r) or NormalRealm(r) == wantRealm
    end

    local others = {}
    for k, data in pairs(ns.db.chars) do
        if k ~= key and ns.IsStr(k) and type(data) == "table" and Belongs(k, data) then
            others[#others + 1] = k
        end
    end
    table.sort(others)

    if type(ns.db.chars[key]) ~= "table" then
        ns.db.chars[key] = {}
    end
    ns.charKey = key
    ns.cdb = ns.db.chars[key]
    if type(ns.cdb.recipes) ~= "table" then
        ns.cdb.recipes = {}
    end

    -- fold duplicate records of this character (from the key bug) into one
    local recovered = 0
    for _, k in ipairs(others) do
        recovered = recovered + ns.CountRecipes(ns.db.chars[k])
        ns.MergeInto(ns.cdb, ns.db.chars[k])
        ns.db.chars[k] = nil
    end
    if recovered > 0 then
        ns.Print("Combined duplicate lists for " .. name .. " into one.")
    end

    -- one-time migration from older versions, which kept the list either in
    -- GroceryListDB (whole account) or in GroceryListCharDB (shared by every
    -- character if the .toc lists it under ## SavedVariables).
    -- The first character to log in after the update keeps the old list.
    local legacy
    if type(GroceryListCharDB) == "table" and type(GroceryListCharDB.recipes) == "table" and
        next(GroceryListCharDB.recipes) ~= nil then
        legacy = GroceryListCharDB
    elseif type(ns.db.recipes) == "table" and next(ns.db.recipes) ~= nil then
        legacy = ns.db
    end
    if legacy then
        ns.MergeInto(ns.cdb, legacy)
        ns.Print("Moved your existing list to " .. key .. ". Each character now keeps its own list.")
    end
    GroceryListCharDB = nil
    ns.db.recipes = nil
    ns.db.shown = nil

    ns.cdb.name, ns.cdb.realm = name, realm
    if guid then
        ns.cdb.guid = guid
    end
    local _, classFile = UnitClass("player")
    if ns.IsStr(classFile) then
        ns.cdb.class = classFile -- used to colour this character's name in the selector
    end
    ns.SanitizeCharacter(ns.cdb, false)
    return true
end

-- The recipes table the window is showing. "All" is a read-only merge of copies,
-- rebuilt on every call, so the saved lists are never touched by it.
function ns.ViewRecipes()
    if ns.viewKey == "ALL" then
        local merged, seq = {}, 0
        for _, key in ipairs(ns.CharacterKeys()) do
            local data = ns.db.chars[key]
            if type(data.recipes) == "table" then
                for _, item in ipairs(ns.SortedRecipes(data.recipes)) do
                    local r = item.r
                    if ns.IsNum(r.count) and type(r.reagents) == "table" then
                        seq = seq + 1
                        merged[key .. "|" .. item.key] = {
                            name = r.name,
                            spellID = r.spellID,
                            count = r.count,
                            icon = r.icon,
                            reagents = r.reagents,
                            seq = seq,
                            owner = ShortName(key)
                        }
                    end
                end
            end
        end
        return merged
    end

    local data = ns.viewKey and ns.db.chars[ns.viewKey]
    if type(data) == "table" and type(data.recipes) == "table" then
        return data.recipes
    end
    ns.viewKey = nil
    return ns.cdb.recipes
end
