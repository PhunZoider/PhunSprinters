if isClient() then
    return
end

local Core = PhunSprinters
local Commands = {}

if not Core.isLocal then
    Commands.isSprinter = function(player, args)

        Core.debug(args)
        for k, v in pairs(args) do
            if k and Core.sprinterIds[k] ~= v then
                Core.addToSend(k, v)
            end
        end

    end
end

Commands.playerSetup = function(player)

    sendServerCommand(Core.name, Core.commands.isSprinter, Core.sprinterIds)

end

return Commands
