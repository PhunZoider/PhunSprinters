if isClient() then
    return
end

local Core = PhunSprinters
local PL = PhunLib
local Commands = {}

Commands.isSprinter = function(player, args)

    PL.debug(args)
    for k, v in pairs(args) do
        if k and Core.sprinterIds[k] ~= v then
            Core.addToSend(k, v)
            print("[PhunSprinters] Set sprinter ID " .. tostring(k) .. " to " .. tostring(v))
        end
    end

end

Commands.playerSetup = function(player)

    sendServerCommand(Core.name, Core.commands.isSprinter, Core.sprinterIds)

end

return Commands
