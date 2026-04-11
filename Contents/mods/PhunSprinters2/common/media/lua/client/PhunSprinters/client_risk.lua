if isServer() then
    return
end

local Core = PhunSprinters
local getClimateManager = getClimateManager

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
    local players = Core.tools.onlinePlayers()
    if Core.moonPhase == nil or Core.moon == nil then
        Core.CalcMoon()
    end
    local moonPhase = Core.moonPhase
    local moon = Core.moon

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local modData = player:getModData()

        modData.PhunSprinters = modData.PhunSprinters or {}
        local pzdata = Core.getPlayerZoneData(player)

        local lastRisk = formatNumber(modData.PhunSprinters.risk or 0)

        -- On a fresh character, totalHours will be nil. Check ModData for hours
        -- carried over from a previous death, otherwise default to 0.
        if modData.PhunSprinters.totalHours == nil then
            local localData = ModData.getOrCreate("PhunSprinters_Local")
            local playerNum = player:getPlayerNum()
            if localData[playerNum] then
                modData.PhunSprinters.totalHours = localData[playerNum].hours
                localData[playerNum] = nil
            else
                modData.PhunSprinters.totalHours = 0
            end
        end

        local totalHours = modData.PhunSprinters.totalHours + player:getHoursSurvived()
        local discount = Core.getOption("HoursDiscount", 0)
        local defaultRisk = Core.getOption("DefaultRisk", 0)
        local hoursAdj = (discount > 0 and discount > totalHours) and (totalHours / discount) or 1
        local minRisk = tonumber(pzdata.minSprinterRisk) or tonumber(defaultRisk) or 0
        local baseRisk = minRisk
        local risk = baseRisk * moon * hoursAdj
        local maxRisk = tonumber(pzdata.maxSprinterRisk) or 100

        if minRisk == nil then
            Core.debugLn("missing Sprinter Risk value in zone " .. tostring(pzdata.region) .. ":" ..
                             tostring(pzdata.zone) .. " for player " .. tostring(player:getDisplayName()) ..
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
            Core.debugLn("risk=" .. tostring(formatNumber(risk)) .. " (was " .. tostring(lastRisk) .. ")")
        end

    end
end
