if isServer() then
    return
end

local Core = PhunSprinters
local getClimateManager = getClimateManager
local PL = PhunLib

local function formatNumber(number, decimals)
    number = number or 0
    -- Round the number to remove the decimal part
    local roundedNumber = math.floor(number + (decimals and 0.005 or 0.5))
    -- Convert to string and format with commas
    local formattedNumber = tostring(roundedNumber):reverse():gsub("(%d%d%d)", "%1,")
    formattedNumber = formattedNumber:reverse():gsub("^,", "")
    return formattedNumber
end

-- Calculate per-player sprinter risk based on hours, zone, moon phase, etc.
function Core.CalcPlayersSprinterPercentage()
    local players = PL.onlinePlayers()
    if Core.moonPhase == nil or Core.moon == nil then
        Core.CalcMoon()
    end
    local moonPhase = Core.moonPhase
    local moon = Core.moon

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local modData = player:getModData()

        modData.PhunSprinters = modData.PhunSprinters or {}
        modData.PhunZones = modData.PhunZones or {}

        local lastRisk = formatNumber(modData.PhunSprinters.risk or 0)

        local totalHours = (modData.PhunSprinters.totalHours or 0) + player:getHoursSurvived()
        local discount = Core.getOption("HoursDiscount", 0)
        local defaultRisk = Core.getOption("DefaultRisk", 0)
        local hoursAdj = (discount > 0 and discount > totalHours) and (totalHours / discount) or 1
        local minRisk = tonumber(modData.PhunZones.minSprinterRisk or defaultRisk or 0)
        local baseRisk = minRisk
        local risk = baseRisk * moon * hoursAdj
        local maxRisk = tonumber(modData.PhunZones.maxSprinterRisk or 0)

        if minRisk == nil then
            print("PhunSprinters: missing Sprinter Risk value in zone " .. tostring(modData.PhunZones.region) .. ":" ..
                      tostring(modData.PhunZones.zone) .. " for player " .. tostring(player:getDisplayName()) ..
                      ". Defaulting to 0 risk")
        end

        if maxRisk > 0 and risk > maxRisk then
            risk = maxRisk
        end

        risk = math.max(0, math.min(risk, 100))

        modData.PhunSprinters.risk = risk
        modData.PhunSprinters.base = baseRisk
        modData.PhunSprinters.moon = moon
        modData.PhunSprinters.moonPhase = moonPhase
        modData.PhunSprinters.hoursAdj = hoursAdj
        modData.PhunSprinters.hours = totalHours

        if risk < 1 then
            modData.PhunSprinters.riskLevel = "None"
        elseif risk < 10 then
            modData.PhunSprinters.riskLevel = "Low"
        elseif risk < 25 then
            modData.PhunSprinters.riskLevel = "Medium"
        elseif risk < 50 then
            modData.PhunSprinters.riskLevel = "High"
        else
            modData.PhunSprinters.riskLevel = "VeryHigh"
        end
        if Core.settings.Debug and lastRisk ~= formatNumber(risk) then
            print("PhunSprinters: risk=" .. tostring(formatNumber(risk)) .. " (was " .. tostring(lastRisk) .. ")")
        end

    end
end
