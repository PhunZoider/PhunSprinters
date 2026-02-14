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

-- don't start calcing until we get ok from server
Core.pendingCalcs = Core.isLocal and false or true

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

            if #Core.toSend > 0 then
                local vars = {}
                for _, v in ipairs(Core.toSend) do
                    if Core.sprinterIds[tostring(v)] == nil then
                        vars[v] = 0
                    else
                        vars[v] = Core.sprinterIds[tostring(v)]
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
    if Core.pendingCalcs then
        return
    end
    Core:enqueueUpdate(zed)
end)

Events[PL.events.OnDawn].Add(function()

    if Core.getOption("Mode") == 1 then
        Core:enableSprinting(false)
    end

    Core.lastRecalc = getTimestampMs()
    Core:recalcOutfits()

end)

Events[PL.events.OnDusk].Add(function()

    if Core.getOption("Mode") == 1 then
        Core:enableSprinting(true)
    end
    Core.lastRecalc = getTimestampMs()

end)
