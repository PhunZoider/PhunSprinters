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

local function clampSpeedPct(v)
    return math.max(25, math.min(100, v))
end

-- This zed's sprint speed as a percentage, 25-100.
--
-- A range from SprinterSpeedMin up to SprinterSpeed, unless the zone the zed is standing
-- in sets minSprinterSpeed or maxSprinterSpeed. A minimum at or above the maximum
-- collapses to the maximum. That is also what keeps existing configs unchanged:
-- SprinterSpeedMin defaults to 100, so a server that only ever set SprinterSpeed still
-- gets exactly that for every sprinter.
--
-- Where in the range a zed lands is not a roll. It comes from the zed's id, so every
-- client works out the same speed for the same zed without any syncing. In MP that has
-- to be getOnlineID: getID is numbered by each process separately (see "MP sync has been
-- dead since 42.17" in Docs/B42-speed-refactor.md). The golden-ratio step spreads
-- consecutive ids evenly across the range.
function Core.sprinterSpeedPct(zed)
    local hi = Core.settings.SprinterSpeed or 100
    local lo = Core.settings.SprinterSpeedMin or hi
    local zone = Core.getZedZoneData(zed) or {}
    hi = clampSpeedPct(tonumber(zone.maxSprinterSpeed) or hi)
    lo = clampSpeedPct(tonumber(zone.minSprinterSpeed) or lo)
    if lo >= hi then
        return hi
    end
    local id = isClient() and zed:getOnlineID() or zed:getID()
    local f = id * 0.6180339887498949
    f = f - math.floor(f)
    return lo + math.floor(f * (hi - lo + 1))
end

-- How fast a sprinter's run plays, from Core.sprinterSpeedPct.
--
-- The sprint and sprint-lunge anim nodes in media/AnimSets/zombie are vanilla copies
-- whose m_SpeedScale names these variables instead of a number. Movement follows the
-- animation, so a slower clip is a slower zed. The 0.80 and 0.90 are the scales those
-- nodes have in vanilla, so 100% is exactly vanilla.
--
-- An unset variable reads as 1.0 (AnimNode.getSpeedScale falls back to
-- getVariableFloat(name, 1.0f)), which is why only zeds we make sprint need it: any
-- other zed reaching those nodes plays them at full speed. Every client derives the same
-- value for the same zed, so no syncing is needed.
--
-- Decided once per zed, when it first becomes ours: changing the options or the zone
-- affects new sprinters, not ones already running, and a sprinter keeps its speed when
-- it crosses into another zone. Like the verdict, it lives in this zed's modData and is
-- gone when getZedData resets the zed.
local function applySpeedScale(zed, zData)
    if zData.speedScalePct then
        return
    end
    local pct = Core.sprinterSpeedPct(zed)
    zData.speedScalePct = pct
    zed:setVariable("PhunSprintersSpeed", 0.80 * pct * 0.01)
    zed:setVariable("PhunSprintersLungeSpeed", 0.90 * pct * 0.01)
end

local function applySpeed(zed, zData, target)
    zData.appliedSpeed = target
    if target == 1 then
        -- Before the early return, which an adopted zed (already speed 1) always takes.
        applySpeedScale(zed, zData)
    end
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

    local zData = Core.getZedData(zed)
    if not zData or not zData.id then
        return
    end

    -- Another controller may have promoted this zed. Its speed is the evidence, and it
    -- arrives by native replication, so check before testing or acting.
    Core.adoptIfSprinting(zed, zData)

    -- The verdict lives here, in this zed's own modData, and nowhere else. It is not
    -- published, not synced and not persisted -- see "Identity is already ephemeral"
    -- in Docs/B42-speed-refactor.md.
    if zData.sprinter == nil then

        -- Risk is per player and computed on a timer. Until it exists there is nothing
        -- to test against, so leave the zed untested and come back next update rather
        -- than recording a "no" we would be stuck with.
        -- The player this zed is actually after, where that is one of ours: risk is per
        -- player, and getPlayer() is only ever player one on splitscreen.
        local target = zed:getTarget()
        local player = (target and instanceof(target, "IsoPlayer") and target:isLocalPlayer()) and target or
                           getPlayer()

        local pData = player:getModData().PhunSprinters
        if not pData or pData.risk == nil then
            return
        end

        zData.sprinter = Core.shouldSprint(zed, zData, pData)
        zData.modified = getTimestampMs()
        Core.applyZedVisualState(zed, zData)

        if zData.sprinter then
            triggerEvent(Core.events.OnSprinterAdded, zed)
        else
            Core.debugLn("PhunSprinters: " .. tostring(zData.id) .. " is not a sprinter")
            return
        end
    end

    if not zData.sprinter then
        return
    end

    Core.applySprintState(zed, zData)

end

-- Should this zed be running right now, and make it so.
--
-- Shared deliberately. Zeds inside MinDistance2 never reach updateZed, so enqueueUpdate
-- has to make the same decision for them -- and when that was a second copy it drifted:
-- the close-range one could only ever call adjustForLight, so under Mode 1 a close zed
-- could not start sprinting, and at dawn it could not stop. reassertSpeed then held it
-- running indefinitely. One decision, one place.
function Core.applySprintState(zed, zData)

    if Core.sprint then

        if Core.settings.Mode == 4 or Core.settings.SlowInLight then
            -- adjust for light
            Core.adjustForLight(zed, zData, zed:getTarget())

        elseif not zData.sprinting then
            -- make sprint
            Core.makeSprint(zed, zData)

        end

    elseif zData.sprinting then
        -- dusk/dawn or mode says stop
        Core.makeNormal(zed, zData)

    end

    if zData.sprinting and not zData.screamed then
        local target = zed:getTarget()
        if target and instanceof(target, "IsoPlayer") then
            Core.scream(zed, zData)
        end
    end

    -- Vanilla re-rolls speedType on every inactive -> active cycle, so hold what we set.
    Core.reassertSpeed(zed, zData)

end

function Core.enableSprinting(value)

    if Core.sprint == value then
        -- Nothing to change, but we have now reconciled at least once. Whatever comes
        -- next is a transition the player actually lives through, and should be heard.
        Core.sprintInitialised = true
        return
    end

    Core.sprint = value
    Core.lastRecalc = getTimestampMs()

    if not Core.sprintInitialised then
        -- First reconciliation after login. This is establishing the baseline, not a
        -- dusk or dawn anyone witnessed, so take the state and stay quiet.
        --
        -- This used to key off lastChangeSound being unset, which is not the same
        -- thing: logging in at night hits the early return above, leaves it unset, and
        -- the first genuine transition of the session was then swallowed instead.
        Core.sprintInitialised = true
    else
        local now = getTimestamp()
        -- Guard against a double chime if something toggles twice in quick succession.
        if now - (Core.lastChangeSound or 0) > 5 then
            Core.lastChangeSound = now
            local vol = (Core.settings.SprintingChangeNotificationVolume or 15) * .01 * Core.clientVolume("ChangeVolume")
            if vol > 0 then
                getSoundManager():PlaySound(value and "PhunSprinters_Start" or "PhunSprinters_End", false, 0)
                    :setVolume(vol)
            end
        end
    end

    if Core.isDebugExtended() then
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
        -- Volume, not SprintingChangeNotificationVolume: this is the zed screech, and
        -- the sandbox option for it ("Percentage Sprinters Volume", 0 to disable) was
        -- never being read. The other option governs the day/night change chime.
        -- Both are then scaled by the player's own slider in Options > Mods.
        local vol = (Core.settings.Volume or 10) * .01 * Core.clientVolume("ScreechVolume")
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

    if Core.isIgnoredMutant(zed) then
        -- Left to The Mutants. It may have classified this zed after we had already
        -- tested it, so drop anything we recorded but do not touch its speed: The
        -- Mutants applies its own when it realises the zed.
        if md.PhunSprinters and md.PhunSprinters.speedScalePct then
            -- Its runs are not ours to slow either.
            zed:clearVariable("PhunSprintersSpeed")
            zed:clearVariable("PhunSprintersLungeSpeed")
        end
        md.PhunSprinters = nil
        return
    end

    local id = Core.getId(zed)

    if not md.PhunSprinters then
        md.PhunSprinters = {}
    end

    local d = md.PhunSprinters

    if not d or d.id ~= id or (d.modified and d.modified < Core.startTime) then

        -- Reset. There is nothing to unpublish: the fresh table below IS the reset,
        -- since the verdict lives only in this zed modData.

        -- Only undo what we did. A zed we never touched keeps whatever speed it has.
        if d.appliedSpeed then
            Core.makeNormal(zed, d)
        end
        if d.speedScalePct then
            zed:clearVariable("PhunSprintersSpeed")
            zed:clearVariable("PhunSprintersLungeSpeed")
        end

        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        -- baseSpeedType is recorded by makeSprint, at the moment before we override
        -- the zed's own speed.
        d = {
            id = id
        }
        md.PhunSprinters = d

        -- No transmitModData. Zed modData is deliberately not replicated: the verdict
        -- lives here and dies with the zed. The old call was inert anyway -- it fired
        -- only when isLocal, i.e. single player, where both GameClient.client and
        -- GameServer.server are false so it did nothing but flagForHotSave.
    end

    return d
end

-- Adopt a zed that some other controller has already promoted.
--
-- Once neuterVanillaSprinters has run, vanilla cannot roll a sprinter at all, so a zed
-- reading speedType 1 was made that way by a mod -- this client earlier, or whichever
-- client owned it before us. Speed replicates natively, so that evidence arrives on its
-- own with no mod networking.
--
-- Without this, a zed promoted by another player and then handed to us stays recorded
-- as "not a sprinter" here: we never suppress it in light, never stop it at dawn, and
-- if the player who promoted it walks away it runs forever with nobody managing it.
-- That is the orphaned-sprinter case.
--
-- Mutants are the exception: The Mutants gives Leapers and Weepers speed 1 itself, so for
-- them a 1 is not evidence of another controller and they roll like anything else.
function Core.adoptIfSprinting(zed, zData)

    if zData.sprinter == true or Core.speedTypeOf(zed) ~= 1 or Core.mutantType(zed) then
        return false
    end

    zData.sprinter = true
    zData.sprinting = true
    zData.appliedSpeed = 1
    zData.modified = getTimestampMs()
    Core.debugLn("Adopting sprinter " .. tostring(zData.id) .. " promoted by another controller")
    Core.applyZedVisualState(zed, zData)
    return true

end

-- Determine if zombie should sprint based on player risk.
--
-- Risk 0 records a plain "no". That used to be dangerous, because the verdict went
-- into a global table and stuck for the life of the save; it is safe now that the
-- verdict dies with the zed.
function Core.shouldSprint(zed, zData, pData)

    local risk = pData.risk or 0
    if risk <= 0 then
        return false
    end

    local chance = ZombRand(100)
    Core.debugLn("Testing Zed (" .. tostring(zData.id) .. "). Rolled " .. tostring(chance) .. " against risk " ..
                     tostring(risk) .. " and is " ..
                     (chance <= risk and "now a sprinter" or "not going to be a sprinter "))
    return chance <= risk

end

-- The light level this zed is judged on, 0-100, directly comparable with the
-- DarknessLevel setting.
--
-- Its own function so the debug overlay can show the number the decision actually used.
-- It used to print the raw local light, which is not the same value outdoors in daylight
-- and made the overlay disagree with the behaviour it was supposed to explain.
function Core.effectiveLight(zed, player)

    local sq = zed and zed:getCurrentSquare()
    local playerNum = (player and player.getPlayerNum and player:getPlayerNum()) or 0

    local isOutdoor = sq and not sq:getRoom()
    if isOutdoor and not Core.isNight then
        -- Daytime outdoor: getLightLevel() is always ~1.0 and does not reflect fog.
        -- Use the fog-adjusted global value, the actual perceived outdoor brightness.
        return (Core.env and Core.env.adjustedLightIntensity) or 100
    end

    -- Indoor: raw local light (fog does not affect indoor squares).
    -- Outdoor nighttime: raw local light correctly reflects flashlight contribution.
    return (sq and sq:getLightLevel(playerNum) or 0) * 100

end

-- Handle light-based slowdown/speedup for zeds
function Core.adjustForLight(zed, zData, player)
    if not zData then
        return
    end

    local threshold = (Core.settings.DarknessLevel or 74)
    local light = Core.effectiveLight(zed, player)

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
