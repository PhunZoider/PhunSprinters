if isServer() then
    return
end
local Core = PhunSprinters
local PZ = PhunZones
local PL = PhunLib
local Commands = require("PhunSprinters/client_commands")
local getTimestamp = getTimestamp

local function setup()
    Events.OnTick.Remove(setup)
    Core:ini()
    sendClientCommand(Core.name, Core.commands.playerSetup, {})

    Core:recalcOutfits()

    local nextCheck = 0

    Events.OnTick.Add(function()
        if getTimestamp() >= nextCheck then
            nextCheck = getTimestamp() + 1
            local players = PZ:onlinePlayers()
            Core:testEnvironment()
        end
    end)
end

Events.OnTick.Add(setup)

Events[PZ.events.OnPhunZonesPlayerLocationChanged].Add(function(player, zone)
    Core.lastRecalc = getTimestampMs()
    Core.CalcPlayersSprinterPercentage()
end)

Events.EveryOneMinute.Add(function()
    Core.CalcPlayersSprinterPercentage()
end)

Events.OnPlayerDeath.Add(function(player)
    if not player or not player:isLocalPlayer() then
        return
    end
    if not player:getModData().PhunSprinters then
        player:getModData().PhunSprinters = {}
    end
    player:getModData().PhunSprinters.totalHours = (player:getModData().PhunSprinters.totalHours or 0) +
                                                       player:getHoursSurvived()

end)

local throttle = 0

Events.OnZombieUpdate.Add(function(zed)

    Core:updateZed(zed)

end);

Events[PL.events.OnDawn].Add(function()
    Core.sprint = false
    Core.lastRecalc = getTimestampMs()
    Core:recalcOutfits()
end)

Events[PL.events.OnDusk].Add(function()
    Core.sprint = true
    Core.lastRecalc = getTimestampMs()
end)
