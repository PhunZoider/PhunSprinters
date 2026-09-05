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

local dumpedLate = false

Events.EveryOneMinute.Add(function()
    Core:testNight()

    if not dumpedLate then
        dumpedLate = true
        Core.dumpSettings("one minute in")
    end

    -- An admin editing sandbox options in-game re-pushes them and wipes our change,
    -- so re-assert it. No-ops when nothing needs doing.
    Core.neuterVanillaSprinters()

    -- Pick up admin edits. Previously nothing refreshed settings on the server at all.
    Core:updateSettings()
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

