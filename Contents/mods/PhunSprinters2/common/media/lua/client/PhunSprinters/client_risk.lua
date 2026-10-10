if isServer() then
    return
end

local Core = PhunSprinters
local getClimateManager = getClimateManager

-- Byte-identical to Core.tools.formatNumber; use the one implementation.
local formatNumber = Core.tools.formatNumber

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
        local discount = Core.settings.HoursDiscount or 0
        local defaultRisk = Core.settings.DefaultRisk or 0
        local hoursAdj = (discount > 0 and discount > totalHours) and (totalHours / discount) or 1
        local minRisk = tonumber(pzdata.minSprinterRisk) or tonumber(defaultRisk) or 0
        local baseRisk = minRisk
        local risk = baseRisk * moon * hoursAdj
        local maxRisk = tonumber(pzdata.maxSprinterRisk) or 100

        -- No 'maxRisk > 0' guard here. A zone that sets maxSprinterRisk = 0 means a safe
        -- haven, and the guard made exactly that case a no-op -- the one value an admin
        -- is most likely to set deliberately. "Unspecified" is already handled by the
        -- 'or 100' above, so there is nothing for the guard to protect against.
        if risk > maxRisk then
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
        if Core.isDebugExtended() and lastRisk ~= formatNumber(risk) then
            Core.debugLn("risk=" .. tostring(formatNumber(risk)) .. " (was " .. tostring(lastRisk) .. ")")
        end

    end
end
