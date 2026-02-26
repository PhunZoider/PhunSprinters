require "PhunZones/core"
require "PhunSprinters/core"
local Core = PhunSprinters
local PZ = PhunZones

local activeMods = getActivatedMods()
if not activeMods:contains("\\phunzones2") then
    if PZ and PZ.fields then
        PZ.fields.minSprinterRisk = {
            label = "IGUI_PhunSprinters_minRisk",
            type = "string",
            tooltip = "IGUI_PhunSprinters_minRisk_Tooltip",
            default = "",
            group = "mods"
        }

        PZ.fields.maxSprinterRisk = {
            label = "IGUI_PhunSprinters_maxRisk",
            type = "string",
            tooltip = "IGUI_PhunSprinters_maxRisk_Tooltip",
            default = "",
            group = "mods"
        }
    end
end

