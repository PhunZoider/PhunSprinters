if isServer() then
    return
end

local Core = PhunSprinters

-- ============================================================
-- Client options (Options > Mods)
-- ============================================================

-- Per player volume, on top of the sandbox volumes rather than instead of them. The
-- server's percentage is still the base, and 0 there still disables the sound for
-- everyone; each player then scales what they hear, 0 to mute it for themselves.

local options = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:create("PhunSprinters", getText("IGUI_PhunSprinters_Options"))

if options then
    options:addSlider("ScreechVolume", getText("IGUI_PhunSprinters_Options_ScreechVolume"), 0, 200, 5, 100,
        getText("IGUI_PhunSprinters_Options_ScreechVolume_Tooltip"))
    options:addSlider("ChangeVolume", getText("IGUI_PhunSprinters_Options_ChangeVolume"), 0, 200, 5, 100,
        getText("IGUI_PhunSprinters_Options_ChangeVolume_Tooltip"))
end

-- The player's multiplier for one of the sliders above, 1 being unchanged.
function Core.clientVolume(id)
    local option = options and options:getOption(id)
    local value = option and option:getValue()
    return (tonumber(value) or 100) * .01
end
