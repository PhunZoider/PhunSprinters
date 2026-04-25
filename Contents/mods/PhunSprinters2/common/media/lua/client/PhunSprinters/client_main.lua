if isServer() then
    return
end

-- === Shortcuts & Module Setup ===
local Core = PhunSprinters
local sandboxOptions = getSandboxOptions()
local getWorld = getWorld
local ZombRand = ZombRand
local getTimestampMs = getTimestampMs
-- ============================================================
-- Risk & Environment Evaluation
-- ============================================================

local _defaultSpeed = nil

local function getDefaultSpeed()
    if _defaultSpeed == nil then
        _defaultSpeed = sandboxOptions:getOptionByName("ZombieLore.Speed") and
                            sandboxOptions:getOptionByName("ZombieLore.Speed"):getValue() or 2
    end
    return _defaultSpeed
end

function Core.updateZed(zed)

    local c = Core
    local sprinters = c.sprinterIds
    local zzz = zed:getModData()

    local zData = Core.getZedData(zed) or {}
    local id = zData.id

    if not id then
        return
    end

    local isSprinter = c.sprinterIds[id]

    if isSprinter == nil then
        -- Locally testing sprinter
        zData.modified = getTimestampMs()
        isSprinter = Core.shouldSprint(zed, zData, getPlayer():getModData().PhunSprinters or {})
        zData.sprinter = isSprinter
        Core.sprinterIds[id] = isSprinter
        if not zData.sprinter then
            Core.applyZedVisualState(zed, zData)
            Core.debugLn("PhunSprinters: " .. tostring(zData.id) .. " is not a sprinter")
            Core.makeNormal(zed, zData)
            return
        else
            Core.applyZedVisualState(zed, zData)
            triggerEvent(Core.events.OnSprinterAdded, zed)
        end
    end

    if zData.sprinter ~= isSprinter then
        if isSprinter ~= true then
            Core.makeNormal(zed, zData)
            zData.sprinter = false
        else
            zData.sprinter = true
        end
        zData.modified = getTimestampMs()
        Core.applyZedVisualState(zed, zData)
    end

    if Core.sprint and isSprinter then

        if Core.settings.Mode == 4 or Core.settings.SlowInLight then
            -- adjust for light

            Core.adjustForLight(zed, zData, zed:getTarget())

        elseif not zData.sprinting then
            -- make sprint
            Core.makeSprint(zed, zData)

        end

    elseif zData.sprinting then
        -- zed is sprinting, make normal
        Core.makeNormal(zed, zData)

    end

end

function Core.enableSprinting(value)

    if Core.sprint == value then
        return
    end
    Core.sprint = value
    Core.lastRecalc = getTimestampMs()
    local now = getTimestamp()
    if not Core.lastChangeSound then
        Core.lastChangeSound = now
    elseif now - (Core.lastChangeSound or 0) > 5 then
        Core.lastChangeSound = now
        local vol = Core.getOption("SprintingChangeNotificationVolume", 15) * .01
        if vol > 0 then
            getSoundManager():PlaySound(value and "PhunSprinters_Start" or "PhunSprinters_End", false, 0):setVolume(vol);
        end
    end
    if Core.settings.Debug then
        print("PhunSprinters: Environment changed - " .. (value and "sprinting" or "normal"))
    end

end

-- ============================================================
-- Screaming
-- ============================================================
local SIMBA_TheySEEyouTest = nil
function Core.scream(zed, zData)

    -- Check for TheySEEyou mod to avoid conflicts
    if SIMBA_TheySEEyouTest == nil then
        SIMBA_TheySEEyouTest = getActivatedMods():contains("SIMBA_TheySEEyou")
    elseif SIMBA_TheySEEyouTest then
        -- TheySEEyou is active, skip screaming
        return
    end

    zData.screamed = true
    local soundName = "PhunSprinters_" .. (ZombRand(5) + 1)

    if not zed:getEmitter():isPlaying(soundName) then
        local vol = Core.getOption("SprintingChangeNotificationVolume", 15) * .01
        if vol <= 0 then
            return
        end
        local soundEmitter = getWorld():getFreeEmitter()
        local hnd = soundEmitter:playSound(soundName, zed:getX(), zed:getY(), zed:getZ())
        soundEmitter:setVolume(hnd, vol)
    end
end

-- ============================================================
-- Utility Functions
-- ============================================================

function Core.getZedData(zed)
    if zed:isDead() then
        return
    end
    local md = zed:getModData()

    if md.brain then
        return
    end -- Skip special zeds like bandits

    local id = Core.getId(zed)

    if not md.PhunSprinters then
        md.PhunSprinters = {}
    end

    local d = md.PhunSprinters

    if not d or d.id ~= id or (d.modified and d.modified < Core.startTime) then

        -- reset
        Core.addToSend(id, nil)

        Core.makeNormal(zed, d)

        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        d = {
            exp = (Core.delta or 0) + (Core.settings.Exp or 300),
            id = id,
            originalSpeed = getDefaultSpeed()
        }
        md.PhunSprinters = d
        if Core.tools.isLocal then
            zed:transmitModData()
        end
    end

    return d
end

-- Determine if zombie should sprint based on player risk
function Core.shouldSprint(zed, zData, pData)
    local risk = pData.risk or 0
    if risk > 0 then
        local chance = ZombRand(100)
        Core.debugLn("Testing Zed (" .. tostring(zData.id) .. "). Rolled " .. tostring(chance) .. " against risk " ..
                         tostring(risk) .. " and is " ..
                         (chance <= risk and "now a sprinter" or "not going to be a sprinter "))

        Core.addToSend(zData.id, chance <= risk)
        return chance <= risk
    else
        Core.addToSend(zData.id, nil)
        return false
    end

end

-- Handle light-based slowdown/speedup for zeds
function Core.adjustForLight(zed, zData, player)
    if not zData then
        return
    end

    local threshold = (Core.settings.DarknessLevel or 74)

    local sq = zed and zed:getCurrentSquare()
    local playerNum = (player and player.getPlayerNum and player:getPlayerNum()) or 0
    local rawLight = (sq and sq:getLightLevel(playerNum) or 0) * 100

    local light
    local isOutdoor = sq and not sq:getRoom()
    if isOutdoor and not Core.isNight then
        -- Daytime outdoor: getLightLevel() is always ~1.0 and does not reflect fog.
        -- Use the fog-adjusted global value, which is the actual perceived outdoor brightness.
        light = (Core.env and Core.env.adjustedLightIntensity) or 100
    else
        -- Indoor: raw local light (fog does not affect indoor squares).
        -- Outdoor nighttime: raw local light correctly reflects flashlight contribution.
        light = rawLight
    end

    if zData.sprinting then
        if light >= threshold then
            Core.makeNormal(zed, zData)
            Core.debugLn("Stopping sprint due to light: " .. tostring(light) .. " >= " .. tostring(threshold))
        end
    else
        if light <= threshold then
            Core.makeSprint(zed, zData)
            Core.debugLn("Starting sprint due to dark: " .. tostring(light) .. " <= " .. tostring(threshold))
        end
    end

end

-- Handle light-based behavior tests for targeted player
function Core.testPlayers(player, zed, zData, pData)

    zData = zData or Core.getZedData(zed)
    if zData == nil then
        return
    end

    pData = pData or player:getModData().PhunSprinters or {}

    if zData.sprinter == nil then
        zData.sprinter = Core.shouldSprint(zed, zData, pData)
    end

    if zData.sprinter and zed:getTarget() == player then
        if not zData.screamed and zData.sprinting then
            Core.scream(zed, zData)
        end
        if Core.sprint then
            Core.adjustForLight(zed, zData, player)
        elseif zData.sprinting then
            Core.makeNormal(zed, zData)
        end
    end
end

-- Force zed back to normal speed
function Core.makeNormal(zed, zData)
    zed:makeInactive(true)
    local defaultSpeed = getDefaultSpeed()
    local restoreSpeed = zData.originalSpeed or defaultSpeed
    sandboxOptions:set("ZombieLore.Speed", restoreSpeed)
    zData.sprinting = false
    zed:makeInactive(false)
    if restoreSpeed ~= defaultSpeed then
        sandboxOptions:set("ZombieLore.Speed", defaultSpeed)
    end
end

-- Force zed to sprint
function Core.makeSprint(zed, zData)

    local defaultSpeed = getDefaultSpeed()

    zed:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 1)
    zData.sprinting = true
    zed:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", defaultSpeed)
end

local sensorList = {"WristWatch_Right_MilitaryX", "WristWatch_Left_MilitaryX", "Military_Sensor_Left",
                    "Military_Sensor_Right"}

function Core.validatePlayerSensor(player)

    if not Core.ui.instances then
        Core.ui.instances = {}
    end

    local items = player:getWornItems()
    local found = Core.settings.Elements or false

    for count = 0, items:size() - 1 do
        local clothingItem = items:getItemByIndex(count)
        local clothingItemType = clothingItem:getType()
        for _, sensorType in ipairs(sensorList) do
            if clothingItemType == sensorType then
                found = true
                break
            end
        end
        if found then
            break
        end
    end

    if not found and Core.ui.instances[player:getPlayerNum()] then

        Core.ui.instances[player:getPlayerNum()]:setVisible(false)

    else
        if Core.ui.instances[player:getPlayerNum()] then
            Core.ui.instances[player:getPlayerNum()]:updateLayout()
        else
            Core.ui.container.open(player)
        end
    end

end
