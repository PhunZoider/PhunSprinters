if isServer() then
    return
end
require "MF_ISMoodle"
local mf = MF
local Core = PhunSprinters
if mf and mf.createMoodle then
    mf.createMoodle("PhunSprinters")
end

Core.moodles = {}
local inied = {}

local chevrons = {
    [50] = 3,
    [35] = 2,
    [20] = 1,
    [10] = 0,
    [5] = 3,
    [3] = 2,
    [1] = 1,
    [0] = 0

}

local function formatNumber(number, decimals)
    number = number or 0
    -- Round the number to remove the decimal part
    local roundedNumber = math.floor(number + (decimals and 0.005 or 0.5))
    -- Convert to string and format with commas
    local formattedNumber = tostring(roundedNumber):reverse():gsub("(%d%d%d)", "%1,")
    formattedNumber = formattedNumber:reverse():gsub("^,", "")
    return formattedNumber
end

local function getDescription(player)
    local md = player:getModData()
    local pd = md.PhunSprinters or {}
    local texts = {}

    table.insert(texts, getText("IGUI_PhunSprinters_Risk_Percentage", formatNumber(pd.risk, true)))
    table.insert(texts,
        getText("IGUI_PhunSprinters_Risk_Area_Percentage", getText("IGUI_PhunSprinters_Risk" .. pd.riskLevel),
            formatNumber(pd.base)))

    local moon = pd.moon
    if moon > 0 then
        table.insert(texts,
            getText("IGUI_PhunSprinters_Risk_Moon_Percentage", getText("IGUI_PhunSprinters_MoonPhase" .. pd.moonPhase),
                formatNumber(moon * 100)))
    end
    if pd.hoursAdj and pd.hoursAdj ~= 1 then
        local hours = (pd.totalHours or 0) + player:getHoursSurvived()
        table.insert(texts, getText("IGUI_PhunSprinters_Risk_Hours_Discounted", formatNumber(hours),
            formatNumber((1 - pd.hoursAdj) * 100)))
    end

    if Core.env.adjustedLightIntensity <= Core.settings.DarknessLevel then
        table.insert(texts, "Dark: " .. tostring(formatNumber(100 - Core.env.adjustedLightIntensity)) .. "%")
        if Core.env.fogIntensity > 0 then
            table.insert(texts, " - Light level: " .. formatNumber(Core.env.lightIntensity) .. "%")
            table.insert(texts, " - Fog density: " .. tostring(Core.env.fogIntensity) .. "%")
        end
    end

    if isAdmin() or isDebugEnabled() then
        table.insert(texts, "Env")
        table.insert(texts, " - Base risk: " .. tostring(md.PhunZones.minSprinterRisk) .. "%")
        table.insert(texts, " - Max Risk: " .. formatNumber(md.PhunZones.maxSprinterRisk) .. "%")
        table.insert(texts, " - Moon Phase: " .. tostring(md.PhunSprinters.moonPhase))
        table.insert(texts, " - Moon Multiplier: " .. tostring(md.PhunSprinters.moon * 100) .. "%")
        table.insert(texts, " - Light: " .. tostring(Core.env.lightIntensity) .. "%")
        table.insert(texts, " - Fog: " .. tostring(Core.env.fogIntensity) .. "%")
        table.insert(texts, " - Adjusted: " .. formatNumber(Core.env.adjustedLightIntensity) .. "%")
        table.insert(texts, "-----")
        table.insert(texts, "Spawning mode")
        table.insert(texts, " - sprinting: " .. tostring(Core.sprint))
        table.insert(texts, "Settings")
        table.insert(texts, " - Darkness Level: " .. tostring(Core.settings.DarknessLevel))

    end

    if Core.sprint then
        table.insert(texts, getText("IGUI_PhunSprinters_ZedsAreRestless"))
    else
        table.insert(texts, getText("IGUI_PhunSprinters_ZedsAreSettling"))
    end

    return #texts > 0 and table.concat(texts, "\n") or ""
end

function Core.moodles:get(player)
    if not mf or not mf.getMoodle then
        return
    end
    local moodle = mf.getMoodle(Core.name, player and player:getPlayerNum())

    if inied[tostring(player)] == nil then
        -- only show bad moodles
        moodle:setThresholds(0.6, 0.7, 0.8, 0.9999, 1.941, 1.97, 1.99, 2)
        local oldMoodleMouseover = moodle.mouseOverMoodle
        moodle.mouseOverMoodle = function(self, goodBadNeutral, moodleLevel, width)
            if self:isMouseOver() or self:isMouseOverMoodle() then
                self:setDescription(goodBadNeutral, moodleLevel, getDescription(player, goodBadNeutral, moodleLevel))
            end
            oldMoodleMouseover(self, goodBadNeutral, moodleLevel, width)
        end
        inied[tostring(player)] = 0
    end

    return moodle
end

function Core.moodles:update(player, data)
end

function Core.moodles:oldupdate(player, data)

    if not data or not Core.data then
        return
    end

    local moodle = self:get(player)

    if not moodle then
        return
    end

    local c = Core

    if c.settings.ShowMoodle == false or (Core.settings.ShowMoodleOnlyWhenRunning == true and not Core.sprint) then
        if moodle then
            moodle:setValue(1)
        end
        return
        -- if not isAdmin() and not isDebugEnabled() then
        --     return
        -- end
    end

    local modData = player:getModData()
    local pd = data or modData.PhunSprinters or {}

    -- if not Core.sprint and not Core.settings.ShowMoodleOnlyWhenRunning then
    --     moodle:setValue(2)
    --     -- if not isAdmin() and not isDebugEnabled() then
    --     --     return
    --     -- else
    --     --     moodle:setValue(2)
    --     -- end
    -- end

    local value = 1
    if data.risk < 4 then
        value = 2 - data.risk
    else
        value = 1 - (data.risk * .01)
    end

    moodle:setValue(value)

    local chevys = 0
    for k, v in pairs(chevrons) do
        if pd.risk >= k then
            chevys = v
            break
        end
    end

    moodle:setChevronCount(chevys)

    local now = getGameTime():getWorldAgeHours()
    if now - (pd.riskChanged or 0) < 0.15 then
        for k, v in pairs(chevrons) do
            if pd.risk >= k then
                moodle:setChevronCount(v)
                break
            end
        end

        moodle:setChevronIsUp(pd.oldRisk and (pd.oldRisk < pd.risk))
    else
        moodle:setChevronCount(0)
    end

    inied[tostring(player)] = chevys

    if modData.PhunZones.subtitle then
        moodle:setTitle(moodle:getGoodBadNeutral(), moodle:getLevel(),
            modData.PhunZones.title .. " - " .. modData.PhunZones.subtitle)
    else
        moodle:setTitle(moodle:getGoodBadNeutral(), moodle:getLevel(), modData.PhunZones.title)
    end

end

