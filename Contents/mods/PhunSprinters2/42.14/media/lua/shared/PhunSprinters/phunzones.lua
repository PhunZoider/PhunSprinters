require "PhunSprinters/core"
local Core = PhunSprinters

local activeMods = getActivatedMods()
if activeMods:contains("\\phunzones2") or activeMods:contains("\\phunzones2test") then

    require "PhunZones/core"
    local PZ = PhunZones

    print("[PhunSprinters2]: PhunZones2 detected, adding zone fields for PhunSprinters")
    if PZ and PZ.fields then
        PZ.fields.minSprinterRisk = {
            label = "IGUI_PhunSprinters_minRisk",
            type = "string",
            tooltip = "IGUI_PhunSprinters_minRisk_Tooltip",
            default = "",
            group = "mods",
            order = 100
        }

        PZ.fields.maxSprinterRisk = {
            label = "IGUI_PhunSprinters_maxRisk",
            type = "string",
            tooltip = "IGUI_PhunSprinters_maxRisk_Tooltip",
            default = "",
            group = "mods",
            order = 101
        }

        PZ.fields.minSprinterSpeed = {
            label = "IGUI_PhunSprinters_minSpeed",
            type = "string",
            tooltip = "IGUI_PhunSprinters_minSpeed_Tooltip",
            default = "",
            group = "mods",
            order = 102
        }

        PZ.fields.maxSprinterSpeed = {
            label = "IGUI_PhunSprinters_maxSpeed",
            type = "string",
            tooltip = "IGUI_PhunSprinters_maxSpeed_Tooltip",
            default = "",
            group = "mods",
            order = 103
        }
    end

else
    print("[PhunSprinters2]: PhunZones2 not detected, using default zone data for PhunSprinters")
end

