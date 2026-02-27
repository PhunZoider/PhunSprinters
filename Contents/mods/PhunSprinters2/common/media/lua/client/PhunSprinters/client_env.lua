if isServer() then
    return
end

local Core = PhunSprinters
local getClimateManager = getClimateManager
local getClimateMoon = getClimateMoon

local moonMappings = {"MoonPhaseMultiplierNew", "MoonPhaseMultiplierCrescent", "MoonPhaseMultiplierQuarter",
                      "MoonPhaseMultiplierGibbous", "MoonPhaseMultiplierFull", "MoonPhaseMultiplierGibbous",
                      "MoonPhaseMultiplierQuarter", "MoonPhaseMultiplierCrescent"}

function Core.CalcMoon()
    Core.moonPhase = getClimateMoon():getCurrentMoonPhase()
    Core.moon = (Core.settings[moonMappings[Core.moonPhase + 1]] or 100) * 0.01
end

-- Reassess environment light/fog to determine sprint toggle
function Core:testEnvironment()

    local daylight = math.floor((getClimateManager():getDayLightStrength() or 0) * 100 + 0.5)
    local fog = math.floor((getClimateManager():getFogIntensity() or 0) * 100 + 0.5)
    local adjustedLight = daylight - (fog / 3)
    adjustedLight = math.max(0, adjustedLight)

    self.env = {
        lightIntensity = daylight,
        fogIntensity = fog,
        adjustedLightIntensity = adjustedLight,
        night = Core.isNight
    }

    if self.settings.Mode == 1 then
        -- Only sprint at night
        if Core.isNight and not Core.sprint then
            Core.enableSprinting(true)
        elseif not Core.isNight and Core.sprint then
            Core.enableSprinting(false)
        end
    elseif self.settings.Mode == 2 then
        -- Always sprint
        if not Core.sprint then
            Core.enableSprinting(true)
        end
    elseif self.settings.Mode == 3 then
        -- Adjust based on global light levels
        local threshold = self.settings.DarknessLevel or 74
        local shouldSprint = adjustedLight < threshold
        if shouldSprint ~= Core.sprint then
            Core.enableSprinting(shouldSprint)
        end
    elseif self.settings.Mode == 4 then
        -- Always sprint except in light
        Core.enableSprinting(true)
    end

end
