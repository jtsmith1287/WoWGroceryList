-- The Blizzard Settings panel.
local _, ns = ...

------------------------------------------------------------
-- Blizzard Settings Panel
------------------------------------------------------------
function ns.RegisterSettings()
    if not Settings then
        return
    end

    local category = Settings.RegisterVerticalLayoutCategory("Grocery List")

    --------------------------------------------------------
    -- Include Bank Items
    --------------------------------------------------------
    local bankSetting = Settings.RegisterAddOnSetting(category, "GroceryList_IncludeBank", "includeBank", ns.db, "boolean",
        "Include Bank Items", true)

    bankSetting:SetValueChangedCallback(function()
        ns.Refresh()
    end)

    Settings.CreateCheckbox(category, bankSetting, "Count items stored in your bank toward owned materials.")

    --------------------------------------------------------
    -- Maximum Visible Rows
    --------------------------------------------------------
    local rowsSetting = Settings.RegisterAddOnSetting(category, "GroceryList_MaxRows", "maxRows", ns.db, "number",
        "Visible Rows", 24)

    rowsSetting:SetValueChangedCallback(function()
        ns.offset = 0
        ns.Refresh()
    end)

    local rowsOptions = Settings.CreateSliderOptions(8, 40, 1)

    Settings.CreateSlider(category, rowsSetting, rowsOptions, "Number of rows displayed before the list scrolls.")

    --------------------------------------------------------
    -- Modifier Key
    --------------------------------------------------------
    local modifierSetting = Settings.RegisterAddOnSetting(category, "GroceryList_Modifier", "modifier", ns.db, "string",
        "Modifier Key", "alt")

    modifierSetting:SetValueChangedCallback(function()
        ns.Refresh()
    end)

    local function GetModifierOptions()
        local container = Settings.CreateControlTextContainer()

        container:Add("alt", "Alt")
        container:Add("ctrl", "Ctrl")
        container:Add("shift", "Shift")

        return container:GetData()
    end

    Settings.CreateDropdown(category, modifierSetting, GetModifierOptions,
        "Choose which modifier key is used to add and remove recipes.")

    --------------------------------------------------------
    -- Register Category
    --------------------------------------------------------
    Settings.RegisterAddOnCategory(category)
end
