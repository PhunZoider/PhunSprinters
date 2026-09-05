if isClient() then
    return
end
require "PhunSprinters/core"
local Commands = require "PhunSprinters/server_commands"
local Core = PhunSprinters

Events.OnServerStarted.Add(function()
    Core:ini()
    Core:testNight()

end)

-- Cheap signature of the settings we hand to clients, so an admin edit can be noticed
-- and pushed without sending the table every minute.
local function settingsSignature()
    local keys = {}
    for k in pairs(Core.settings) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        table.insert(parts, k .. "=" .. tostring(Core.settings[k]))
    end
    return table.concat(parts, ",")
end

local lastSignature = nil

Events.EveryOneMinute.Add(function()
    Core:testNight()
    -- An admin editing sandbox options in-game re-pushes them and wipes our change,
    -- so re-assert it. No-ops when nothing needs doing.
    Core.neuterVanillaSprinters()

    -- Pick up admin edits, and pass them on. Clients cannot read these for themselves.
    Core:updateSettings()
    local signature = settingsSignature()
    if lastSignature == nil then
        lastSignature = signature
    elseif lastSignature ~= signature then
        lastSignature = signature
        Core.debugLn("Settings changed, pushing to clients")
        sendServerCommand(Core.name, Core.commands.settings, Core.settings)
    end
end)

-- Gone with the sprinter verdict table: the per-second batched send to clients, the
-- empty-server reset that cleared it, and the OnZombieDead / PhunZones OnZombieRemoved
-- handlers that pruned it. A verdict now lives in the zed's own modData, so the zed
-- dying or being recycled disposes of it with no bookkeeping at all.

Events.OnClientCommand.Add(function(module, command, playerObj, arguments)
    if module == Core.name and Commands[command] then
        Commands[command](playerObj, arguments)
    end
end)

