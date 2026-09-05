if isClient() then
    return
end

local Commands = {}

-- No client -> server commands. The sprinter verdict used to be published here and
-- rebroadcast to every client; it now lives in the zed's own modData and dies with the
-- zed, so there is nothing to sync. This module and the OnClientCommand dispatcher in
-- server_events stay as the extension point if that changes.

return Commands
