if isServer() then
    return
end

-- === Shortcuts & Module Setup ===
local Core = PhunSprinters
local PZ = PhunZones
local sandboxOptions = getSandboxOptions()
local getWorld = getWorld
local ZombRand = ZombRand
local getTimestampMs = getTimestampMs
-- ============================================================
-- Risk & Environment Evaluation
-- ============================================================

function Core.updateZed(zed)

    local zData = Core.getZedData(zed) or {}
    local id = zData.id
    local isSprinter = Core.sprinterIds[tostring(id)]

    if isSprinter == nil then
        -- Locally testing sprinter
        zData.modified = getTimestampMs()
        isSprinter = Core:shouldSprint(zed, zData, getPlayer():getModData().PhunSprinters or {})
        zData.sprinter = isSprinter
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
    local data = zed:getModData()

    if data.brain then
        return
    end -- Skip special zeds like bandits

    local id = Core.getId(zed)
    local verKey = Core.settings.VersionKey

    local d = data[verKey]

    if not d or d.id ~= id or (d.modified and d.modified < Core.startTime) or (d.exp or 0) < (Core.delta or 0) then

        -- reset
        Core.addToSend(id, nil)

        Core.makeNormal(zed, data)

        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        data[verKey] = {
            exp = (Core.delta or 0) + (Core.settings.Exp or 300),
            id = id,
            originalSpeed = Core.getZedSpeedType(zed)
        }
        zed:transmitModData()
    end

    return data[verKey]
end

-- Determine if zombie should sprint based on player risk
function Core.shouldSprint(zed, zData, pData)
    local risk = pData.risk or 0
    if risk > 0 then
        local chance = ZombRand(100)
        Core.debugLn("[PhunSprinters]: Testing Zed (" .. tostring(zData.id) .. "). Rolled " .. tostring(chance) ..
                         " against risk " .. tostring(risk) .. " and is " ..
                         (chance <= risk and "now a sprinter" or "not going to be a sprinter "))

        Core.addToSend(zData.id, chance <= risk)
        return chance <= risk
    end
    return false
end

-- Handle light-based slowdown/speedup for zeds
function Core.adjustForLight(zed, zData, player)

    local threshold = (Core.settings.DarknessLevel or 74)

    -- if Core.env.fogIntensity then
    local sq = zed and zed:getCurrentSquare()
    local light = (sq and sq:getLightLevel((player and player.getPlayerNum and player:getPlayerNum()) or 0) or 0) * 100

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

local _defaultSpeed = nil

local function getDefaultSpeed()
    if _defaultSpeed == nil then
        _defaultSpeed = sandboxOptions:getOptionByName("ZombieLore.Speed") and
                            sandboxOptions:getOptionByName("ZombieLore.Speed"):getValue() or 2
    end
    return _defaultSpeed
end

-- Force zed back to normal speed
function Core.makeNormal(zed, zData)
    zed:makeInactive(true)
    local defaultSpeed = getDefaultSpeed()
    sandboxOptions:set("ZombieLore.Speed", zData.originalSpeed or 2)
    zData.sprinting = false
    zed:makeInactive(false)
    if (zData.originalSpeed or 2) ~= defaultSpeed then
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

function Core.validatePlayerSensor(player)

    if not Core.ui.instances then
        Core.ui.instances = {}
    end

    local items = player:getWornItems()
    local found = Core.settings.Elements or false

    for count = 0, items:size() - 1 do
        local clothingItem = items:getItemByIndex(count)
        local clothingItemType = clothingItem:getType()
        if clothingItemType == "WristWatch_Right_MilitaryX" or clothingItemType == "WristWatch_Left_MilitaryX" then
            found = true
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
