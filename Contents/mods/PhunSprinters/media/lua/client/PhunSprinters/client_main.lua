if isServer() then
    return
end

-- === Shortcuts & Module Setup ===
local Core = PhunSprinters
local PL = PhunLib
local PZ = PhunZones
local sandboxOptions = getSandboxOptions()
local getWorld = getWorld
local ZombRand = ZombRand

-- ============================================================
-- Risk & Environment Evaluation
-- ============================================================

function Core:updateZed(zed)

    local zData = self:getZedData(zed) or {}
    local id = zData.id
    local isSprinter = self.sprinterIds[tostring(id)]

    -- if zData.sprinter == nil then
    if isSprinter == nil then
        -- Locally testing sprinter
        zData.modified = getTimestampMs()
        isSprinter = self:shouldSprint(zed, zData, getPlayer():getModData().PhunSprinters or {})
        zData.sprinter = isSprinter
        if not zData.sprinter then
            self:applyZedVisualState(zed, zData)
            if self.settings.Debug then
                print("PhunSprinters: " .. tostring(zData.id) .. " is not a sprinter")
            end
            self.makeNormal(zed, zData)
            return
        else
            self:applyZedVisualState(zed, zData)
            triggerEvent(self.events.onSprinterAdded, zed)
        end
    end

    if zData.sprinter ~= isSprinter then
        if isSprinter ~= true then
            self.makeNormal(zed, zData)
            zData.sprinter = false
        elseif isSprinter == true then
            zData.sprinter = true
        end
        zData.modified = getTimestampMs()
        self:applyZedVisualState(zed, zData)
    end

    -- if self.pendingIds[id] then
    --     zData.modified = getTimestampMs()
    --     zData.sprinter = isSprinter
    --     self.pendingIds[id] = nil
    --     self:applyZedVisualState(zed, zData)

    -- end

    if self.sprint and isSprinter then

        if self.settings.Mode == 4 or self.settings.SlowInLight then
            -- adjust for light

            self:adjustForLight(zed, zData, zed:getTarget())

        elseif not zData.sprinting then
            -- make sprint
            self.makeSprint(zed, zData)

        end

    elseif zData.sprinting then
        -- zed is sprinting, make normal
        self.makeNormal(zed, zData)

    end

end

function Core:enableSprinting(value)

    if self.sprint == value then
        return
    end
    Core.sprint = value
    Core.lastRecalc = getTimestampMs()
    local now = getTimestamp()
    if not self.lastChangeSound then
        self.lastChangeSound = now
    elseif now - (Core.lastChangeSound or 0) > 5 then
        Core.lastChangeSound = now
        local vol = Core.getOption("SprintingChangeNotificationVolume", 15) * .01
        if vol > 0 then
            getSoundManager():PlaySound(value and "PhunSprinters_Start" or "PhunSprinters_End", false, 0):setVolume(vol);
        end
    end
    if self.settings.Debug then
        print("PhunSprinters: Environment changed - " .. (value and "sprinting" or "normal"))
    end

end

-- ============================================================
-- Screaming
-- ============================================================
local SIMBA_TheySEEyouTest = nil
function Core:scream(zed, zData)

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

function Core:getZedData(zed)
    if zed:isDead() then
        return
    end
    local data = zed:getModData()

    if data.brain then
        return
    end -- Skip special zeds like bandits

    local id = self:getId(zed)
    local verKey = self.settings.VersionKey

    local d = data[verKey]

    if not d or d.id ~= id or (d.modified and d.modified < self.startTime) or (d.exp or 0) < (self.delta or 0) then

        -- reset
        self.addToSend(id, nil)

        self.makeNormal(zed, data)

        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        data[verKey] = {
            exp = (self.delta or 0) + (self.settings.Exp or 300),
            id = id,
            originalSpeed = self.getZedSpeedType(zed)
        }
        zed:transmitModData()
    end

    return data[verKey]
end

-- Determine if zombie should sprint based on player risk
function Core:shouldSprint(zed, zData, pData)
    local risk = pData.risk or 0
    if risk > 0 then
        local chance = ZombRand(100)
        if self.settings.Debug then
            print("[PhunSprinters]: Testing Zed (" .. tostring(zData.id) .. "). Rolled " .. tostring(chance) ..
                      " against risk " .. tostring(risk) .. " and is " ..
                      (chance <= risk and "now a sprinter" or "not going to be a sprinter "))
        end

        -- self.sprinterIds[tostring(zData.id)] = chance <= risk
        self.addToSend(zData.id, chance <= risk)
        return chance <= risk
    end
    return false
end

-- Handle light-based slowdown/speedup for zeds
function Core:adjustForLight(zed, zData, player)

    local threshold = (self.settings.DarknessLevel or 74)
    -- local light = self.env.adjustedLightIntensity or 1

    -- if dist and dist < 5 then
    -- use distance-based light level for close zeds

    -- if self.env.fogIntensity then
    local sq = zed and zed:getCurrentSquare()
    local light = (sq and sq:getLightLevel((player and player.getPlayerNum and player:getPlayerNum()) or 0) or 0) * 100
    --     light = light - (self.env.fogIntensity / 3)
    --     light = math.max(0, light)
    -- end
    -- end
    -- if self.env and self.env.fogIntensity > 0 and (dist == nil or dist > 5) then
    -- light = self.env.adjustedLightIntensity or 1
    -- end

    if zData.sprinting then
        if light >= threshold then
            Core.makeNormal(zed, zData)
            print("Stopping sprint due to light: " .. tostring(light) .. " >= " .. tostring(threshold))
        end
    else
        if light <= threshold then
            Core.makeSprint(zed, zData)
            print("Starting sprint due to dark: " .. tostring(light) .. " <= " .. tostring(threshold))
        end
    end

    -- if zData.sprinting and light >= threshold then
    --     -- Core.makeNormal(zed, zData, zData)
    -- elseif not zData.sprinting and light <= threshold then
    --     Core.makeSprint(zed, zData)
    -- end
end

-- Handle light-based behavior tests for targeted player
function Core:testPlayers(player, zed, zData, pData)

    local zData = zData or self:getZedData(zed)
    if zData == nil then
        return
    end

    local pData = pData or player:getModData().PhunSprinters or {}

    if zData.sprinter == nil then
        zData.sprinter = self:shouldSprint(zed, zData, pData)
    end

    if zData.sprinter and zed:getTarget() == player then
        if not zData.screamed and zData.sprinting then
            self:scream(zed, zData)
        end
        if self.sprint then
            self:adjustForLight(zed, zData, player)
        elseif zData.sprinting then
            Core.makeNormal(zed, zData)
        end
    end
end

local defaultSpeed = nil

local function getDefaultSpeed()
    if defaultSpeed == nil then
        defaultSpeed = sandboxOptions:getOptionByName("ZombieLore.Speed") and
                           sandboxOptions:getOptionByName("ZombieLore.Speed"):getValue() or 2
    end
    return defaultSpeed
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

local defaultSpeed = nil
-- Force zed to sprint
function Core.makeSprint(zed, zData)

    if defaultSpeed == nil then
        defaultSpeed = getDefaultSpeed()
    end

    zed:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 1)
    zData.sprinting = true
    zed:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", defaultSpeed)
end
