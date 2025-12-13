-- === Only run on client ===
if isServer() then
    return
end

-- === Module Shortcuts ===
local Core = PhunSprinters
local PZ = PhunZones
local PL = PhunLib
local Commands = require("PhunSprinters/client_commands")

-- === Timestamp Shortcuts ===
local getTimestamp = getTimestamp
local getTimestampMs = getTimestampMs

-- === Initialization ===
local function setup()
    Events.OnTick.Remove(setup)

    Core:ini()
    sendClientCommand(Core.name, Core.commands.playerSetup, {})
    Core:recalcOutfits()
    local nextCheck = getTimestamp()

    -- === Main OnTick Handler ===
    Events.OnTick.Add(function()
        Core:processQueue()
        if getTimestamp() >= nextCheck then
            nextCheck = getTimestamp() + 1
            Core:testEnvironment()
        end
    end)
end

Events.OnTick.Add(setup)

-- === Player Zone Changed ===
Events[PZ.events.OnPhunZonesPlayerLocationChanged].Add(function(player, zone)
    Core.lastRecalc = getTimestampMs()
    Core.CalcPlayersSprinterPercentage()
end)

-- === Recalculate Sprinter Percent Every Minute ===
Events.EveryOneMinute.Add(function()
    Core.CalcPlayersSprinterPercentage()
end)

Events[PL.events.OnDawn].Add(function()
    Core.CalcMoon()
end)

-- === Track Player Death (Save Sprinter Hours) ===
Events.OnPlayerDeath.Add(function(player)
    if not player or not player:isLocalPlayer() then
        return
    end

    local modData = player:getModData()
    modData.PhunSprinters = modData.PhunSprinters or {}

    local hours = player:getHoursSurvived()
    modData.PhunSprinters.totalHours = (modData.PhunSprinters.totalHours or 0) + hours
end)

-- === Update Zombie State on Every Zombie Tick ===
Events.OnZombieUpdate.Add(function(zed)
    -- Core:updateZed(zed)
    Core:enqueueUpdate(zed)

    -- if Core.settings.SlowInLight then

    --     local player = zed:getTarget()
    --     if player and instanceof(player, "IsoPlayer") then

    --         local data = Core:getZedData(zed)
    --         if data.sprinter then
    --             if getTimestamp() > (data.next or 9999999999) then
    --                 return
    --             end

    --             data.next = getTimestamp() + 1
    --             Core:testPlayers(player, zed, data)
    --             -- Core:adjustForLight(zed, data, player)
    --         end
    --     end
    -- end
end)

-- === Handle Day/Night Sprint Toggles ===
Events[PL.events.OnDawn].Add(function()
    if getSandboxOptions():getOptionByName("PhunSprinters.NightOnly"):getValue() then
        Core:enableSprinting(false)
    end
    Core.lastRecalc = getTimestampMs()
    Core:recalcOutfits()
end)

Events[PL.events.OnDusk].Add(function()
    if getSandboxOptions():getOptionByName("PhunSprinters.NightOnly"):getValue() then
        Core:enableSprinting(true)
    end
    Core.lastRecalc = getTimestampMs()
end)
