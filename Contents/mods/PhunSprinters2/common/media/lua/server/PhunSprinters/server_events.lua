if isClient() then
    return
end
local getTimestamp = getTimestamp
require "PhunSprinters/core"
local Commands = require "PhunSprinters/server_commands"
local Core = PhunSprinters
local PZ = PhunZones
local emptyServerCalculate = false
local emptyServerTickCount = 0

Events.OnServerStarted.Add(function()
    Core:ini()
    ModData.add(Core.name, {})
    Core.sprinterIds = ModData.get(Core.name)
    Core:testNight()

end)

Events.EveryOneMinute.Add(function()
    Core:testNight()
end)

if not Core.isLocal then

    Events[Core.events.OnEmptyServer].Add(function()
        Core.debugLn("Empty server, clearing sprinter IDs")
        Core.sprinterIds = {}
    end)

    Events.EveryTenMinutes.Add(function()
        if Core.tools.onlinePlayers():size() > 0 then
            emptyServerCalculate = true
        end
    end)

    Events.OnTickEvenPaused.Add(function()

        if emptyServerCalculate and emptyServerTickCount > 100 then
            local players = Core.tools.onlinePlayers()
            if players:size() == 0 then
                emptyServerCalculate = false
                triggerEvent(Core.events.OnEmptyServer, {})
            end
        elseif emptyServerTickCount > 100 then
            emptyServerTickCount = 0
        else
            emptyServerTickCount = emptyServerTickCount + 1
        end
    end)

    local nextCheck = getTimestamp()
    Events.OnTick.Add(function()

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
                sendServerCommand(Core.name, Core.commands.isSprinter, vars)
                Core.toSend = {}
            end
        end
    end)
end

Events.OnClientCommand.Add(function(module, command, playerObj, arguments)
    if module == Core.name and Commands[command] then
        Commands[command](playerObj, arguments)
    end
end)

Events.OnZombieDead.Add(function(zed)

    if zed then
        local id = Core.getId(zed)
        if id and Core.sprinterIds[id] then
            -- it's a sprinter
            Core.addToSend(id, nil)
        else
            return
        end
    end

end);

if PZ and PZ.events and PZ.events.OnZombieRemoved then
    Events[PZ.events.OnZombieRemoved].Add(function(id)
        local ids = {}
        if type(id) == "number" or type(id) == "string" then
            table.insert(ids, tostring(id))
        elseif type(id) == "table" then
            ids = id
        end
        for _, i in ipairs(ids) do
            if Core.sprinterIds[i] then
                Core.debugLn("Zombie removed from PhunZones, clearing sprinter ID for zombie " .. tostring(i))
                Core.addToSend(i, nil)
            end
        end
    end)
end

