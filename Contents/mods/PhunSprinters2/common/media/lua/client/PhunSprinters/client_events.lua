-- === Only run on client ===
if isServer() then
    return
end

-- === Module Shortcuts ===
local Core = PhunSprinters
local Commands = require("PhunSprinters/client_commands")

-- === Timestamp Shortcuts ===
local getTimestamp = getTimestamp
local getTimestampMs = getTimestampMs

-- don't start calcing until we get ok from server
if Core.isLocal then
    Core.pendingCalcs = false
else
    Core.pendingCalcs = true
end

-- === Initialization ===
local function setup()
    Events.OnTick.Remove(setup)

    Core:ini()
    sendClientCommand(Core.name, Core.commands.playerSetup, {})
    Core:recalcOutfits()

    local players = Core.tools.onlinePlayers()
    for i = 0, players:size() - 1 do
        Core.validatePlayerSensor(players:get(i))
    end

    local nextCheck = getTimestamp()

    -- === Main OnTick Handler ===
    Events.OnTick.Add(function()
        Core.processQueue()
        local ts = getTimestamp()
        if ts >= nextCheck then
            nextCheck = ts + 1

            if #Core.toSend > 0 then
                local vars = {}
                for _, v in ipairs(Core.toSend) do
                    if Core.sprinterIds[v] == nil then
                        vars[v] = 0
                    else
                        vars[v] = Core.sprinterIds[v]
                    end
                end
                sendClientCommand(Core.name, Core.commands.isSprinter, vars)
                Core.toSend = {}
            end

            Core:testEnvironment()
        end
    end)

    if Core.getOption("Debug") then
        Events.OnPostRender.Add(function()
            Core.onDebugZedLabels()
        end)

        Events.EveryOneMinute.Add(function()
            -- update settings
            Core:updateSettings()
        end)

    end

end

Events.OnTick.Add(setup)

Events.EveryOneMinute.Add(function()
    Core:testNight()
end)

Events.OnClothingUpdated.Add(function(player)
    if player:isLocalPlayer() then
        Core.validatePlayerSensor(player)
    end
end)

Events.OnCreatePlayer.Add(function(playerIndex, playerObj)
    Core.validatePlayerSensor(playerObj)
end)

Events.OnServerCommand.Add(function(module, command, arguments)
    if module == Core.name then
        if Commands[command] then
            Commands[command](arguments)
        end
    end
end)

Events.OnReceiveGlobalModData.Add(function(tableName, tableData)
    if tableName == Core.name then
        ModData.add(Core.name, tableData)
        Core.sprinterIds = ModData.getOrCreate(Core.name, {})
    end
end)

-- === Player Zone Changed ===
if PhunZones then

    local PZ = PhunZones
    local getPhysicalZone = nil

    Events[PZ.events.OnPhysicalZoneChanged].Add(function(player, zone)
        Core.lastRecalc = getTimestampMs()
        Core.CalcPlayersSprinterPercentage()
    end)

    Events[PZ.events.OnDataBuilt].Add(function()
        if not getPhysicalZone then
            -- PhunZones is built so we can replace the stub
            getPhysicalZone = PZ.getPhysicalZone
            function Core.getPlayerZoneData(player)

                return getPhysicalZone(player)
            end

        end
    end)
end

-- === Recalculate Sprinter Percent Every Minute ===
Events.EveryOneMinute.Add(function()
    Core.CalcPlayersSprinterPercentage()
end)

-- === Track Player Death (Save Sprinter Hours) ===
-- player:getModData() changes may not persist across character death/respawn,
-- so we write the total into ModData as a transfer buffer. On the next character
-- creation, CalcPlayersSprinterPercentage picks it up and migrates it into modData.
Events.OnPlayerDeath.Add(function(player)
    if not player or not player:isLocalPlayer() then
        return
    end

    local modData = player:getModData()
    modData.PhunSprinters = modData.PhunSprinters or {}

    local total = (modData.PhunSprinters.totalHours or 0) + player:getHoursSurvived()

    local localData = ModData.getOrCreate("PhunSprinters_Local")
    localData[player:getPlayerNum()] = {
        hours = total
    }
end)

-- === Update Zombie State on Every Zombie Tick ===
Events.OnZombieUpdate.Add(function(zed)
    if Core.pendingCalcs then
        return
    end
    Core.enqueueUpdate(zed)
end)

Events[Core.events.OnDawn].Add(function()

    if Core.getOption("Mode") == 1 then
        Core.enableSprinting(false)
    end

    Core.lastRecalc = getTimestampMs()
    Core:recalcOutfits()
    Core.CalcMoon()
end)

Events[Core.events.OnDusk].Add(function()

    if Core.getOption("Mode") == 1 then
        Core.enableSprinting(true)
    end
    Core.lastRecalc = getTimestampMs()

end)
