if isClient() then
    return
end
local getTimestamp = getTimestamp
require "PhunSprinters/core"
local Commands = require "PhunSprinters/server_commands"
local Core = PhunSprinters
local PL = PhunLib
local PZ = PhunZones

Events.OnServerStarted.Add(function()
    ModData.add(Core.name, {})
    Core.sprinterIds = ModData.get(Core.name)
end)

local nextCheck = getTimestamp()
Events.OnTick.Add(function()

    if getTimestamp() >= nextCheck then
        nextCheck = getTimestamp() + 1

        if #Core.toSend > 0 then
            local vars = {}
            for _, v in ipairs(Core.toSend) do
                if Core.sprinterIds[tostring(v)] == nil then
                    vars[v] = 0
                else
                    vars[v] = Core.sprinterIds[tostring(v)]
                end
            end
            -- PL.debug("To send:", vars, "=---")
            sendServerCommand(Core.name, Core.commands.isSprinter, vars)
            Core.toSend = {}
        end
    end
end)

Events.OnClientCommand.Add(function(module, command, playerObj, arguments)
    if module == Core.name and Commands[command] then
        Commands[command](playerObj, arguments)
    end
end)

Events.OnZombieDead.Add(function(zed)

    if zed then
        local id = Core:getId(zed)
        if id and Core.sprinterIds[id] then
            -- it's a sprinter
            Core.addToSend(id, nil)
        else
            return
        end
    end

end);
Events[PL.events.OnEmptyServer].Add(function()
    print("[PhunSprinters] Empty server, clearing sprinter IDs")
    Core.sprinterIds = {}
end)

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
                print("[PhunSprinters] Zombie removed from PhunZones, clearing sprinter ID for zombie " .. tostring(i))
                Core.addToSend(i, nil)
            end
        end
    end)
end

