if isServer() then
    return
end

-- === Shortcuts & Module Setup ===
local Core = PhunSprinters
local getWorld = getWorld
local ZombRand = ZombRand
local getTimestampMs = getTimestampMs

-- ============================================================
-- Speed
-- ============================================================

-- B42 sets speed per zombie. speedType: 1 sprinter, 2 fast shambler, 3 shambler.
-- None of these four read ZombieLore.Speed, so they never fight the sandbox (which
-- Core.neuterVanillaSprinters in core.lua adjusts separately).
-- doZombieSpeed() is deliberately not used: it consults the sandbox and has a
-- 2-in-3 chance of landing in doFakeShambler instead.
local applySpeedType = {
    [1] = function(zed)
        zed:doSprinter()
    end,
    [2] = function(zed)
        zed:doFastShambler()
    end,
    [3] = function(zed)
        zed:doShambler()
    end
}

local function applySpeed(zed, zData, target)
    zData.appliedSpeed = target
    -- makeInactive(true) pins speedType to 3 and re-activation re-rolls it, so a
    -- write to an inactive zed is wasted. The re-assert in updateZed catches it.
    if zed.inactive or Core.speedTypeOf(zed) == target then
        return false
    end
    local fn = applySpeedType[target]
    if not fn then
        return false
    end
    fn(zed)
    return true
end

-- A directly-set speed does not stay set: cycling inactive -> active sets speedType
-- to -1 and re-rolls it from the sandbox. Re-assert whatever we last applied.
-- zed.speedType is a plain field read, so this costs nothing when nothing drifted.
function Core.reassertSpeed(zed, zData)
    if zData.appliedSpeed then
        applySpeed(zed, zData, zData.appliedSpeed)
    end
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

    if zData.sprinting and not zData.screamed then
        local target = zed:getTarget()
        if target and instanceof(target, "IsoPlayer") then
            Core.scream(zed, zData)
        end
    end

    Core.reassertSpeed(zed, zData)

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
    end
    if SIMBA_TheySEEyouTest then
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

        -- Only undo what we did. A zed we never touched keeps whatever speed it has.
        if d.appliedSpeed then
            Core.makeNormal(zed, d)
        end

        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        -- baseSpeedType is recorded by makeSprint, at the moment before we override
        -- the zed's own speed.
        d = {
            exp = (Core.delta or 0) + (Core.settings.Exp or 300),
            id = id
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

-- Put the zed back at its own speed. Covers both "light or mode says not right now"
-- and "this zed is not one of ours": with vanilla sprinters disabled at startup a
-- zed's own speed is never sprinter, so both cases have the same answer.
function Core.makeNormal(zed, zData)
    zData.sprinting = false
    applySpeed(zed, zData, zData.baseSpeedType or Core.neuteredSpeedType())
end

-- Force zed to sprint
function Core.makeSprint(zed, zData)
    if not zData.sprinting then
        -- Remember what to come back to, in the moment before we overwrite it.
        Core.captureBaseSpeed(zed, zData)
        zData.sprinting = true
    end
    applySpeed(zed, zData, 1)
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
