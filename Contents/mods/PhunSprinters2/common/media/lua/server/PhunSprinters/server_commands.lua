if isClient() then
    return
end

local Commands = {}

-- No client -> server commands. The sprinter verdict is not synced: it lives in the
-- zed's own modData and dies with the zed. This module and the OnClientCommand
-- dispatcher in server_events stay as the extension point if that changes.

return Commands
