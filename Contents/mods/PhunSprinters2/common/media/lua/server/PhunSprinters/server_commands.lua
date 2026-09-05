if isClient() then
    return
end

local Core = PhunSprinters
local Commands = {}

-- The sprinter verdict is NOT synced -- it lives in the zed's own modData and dies with
-- the zed. Settings are a different matter: they are genuinely server-authoritative,
-- they change rarely, and a joining client cannot read them for itself because
-- ConnectToServerState resets every mod option to its default after applying the
-- server's sandbox. See Core.applyServerSettings.
Commands.playerSetup = function(player)
    sendServerCommand(player, Core.name, Core.commands.settings, Core.settings)
end

return Commands
