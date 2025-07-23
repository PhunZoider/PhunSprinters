require "PhunZones/core"
require "PhunSprinters/core"
local Core = PhunSprinters
local PZ = PhunZones

PZ.fields.minSprinterRisk = {
    label = "IGUI_PhunSprinters_minRisk",
    type = "int",
    tooltip = "IGUI_PhunSprinters_minRisk_Tooltip",
    min = 0,
    max = 100,
    default = ""
}

PZ.fields.maxSprinterRisk = {
    label = "IGUI_PhunSprinters_maxRisk",
    type = "int",
    tooltip = "IGUI_PhunSprinters_maxRisk_Tooltip",
    min = 0,
    max = 100,
    default = ""
}

