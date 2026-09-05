if isServer() then
    return
end
local getPlayer = getPlayer
local getTimestamp = getTimestamp
local Core = PhunSprinters

-- ============================================================
-- Zombie Queue Management
-- ============================================================

function Core.enqueueUpdate(zed)
    if not zed or zed:isDead() then
        return
    end
    local c = Core
    local id = c.getId(zed)
    local player = getPlayer()
    if not player or Core.queueIds[id] then
        return
    end

    local zs = zed:getSquare()
    local ps = player:getSquare()
    local distance = 0
    if ps and zs and ps.DistToProper then
        distance = ps:DistToProper(zs)
    end
    if distance > (Core.settings.MaxDistance2 or 35) then
        -- too far away
        return
    end

    local data = Core.getZedData(zed)
    if not data then
        return
    end

    if distance < (Core.settings.MinDistance2 or 14) then
        -- Too close to queue, but a zed we already own still needs light adjustment, a
        -- scream on approach, and its speed held against vanilla's re-rolls.
        if data.sprinter then
            if Core.sprint then
                if Core.settings.Mode == 4 or Core.settings.SlowInLight then
                    -- adjust for light
                    Core.adjustForLight(zed, data, zed:getTarget(), distance)
                end
                if data.sprinting and not data.screamed then
                    local target = zed:getTarget()
                    if target and instanceof(target, "IsoPlayer") then
                        Core.scream(zed, data)
                    end
                end
            end
            -- These zeds never reach updateZed, so hold their speed here: vanilla
            -- re-rolls speedType on every inactive -> active cycle.
            Core.reassertSpeed(zed, data)
        end
        return
    end

    if data.sprinter == false then
        -- tested, and not one of ours
        return
    end

    if data.dressed == nil then
        Core.applyZedVisualState(zed, data)
        data.dressed = true
    end

    Core.queueIds[id] = true
    table.insert(Core.queue, zed)
end

local lastQueueFullMessage = 0
function Core.processQueue()
    local count = 0
    local maxCount = Core.settings.MaxQueue or 10

    while #Core.queue > 0 and count < maxCount do
        local zed = table.remove(Core.queue, 1)
        Core.queueIds[Core.getId(zed)] = nil
        Core.updateZed(zed)
        count = count + 1
    end

    if count == maxCount and #Core.queue > 0 then
        if getTimestamp() - lastQueueFullMessage > 3 then
            lastQueueFullMessage = getTimestamp()
            Core.debugLn("Queue is full, " .. tostring(#Core.queue) .. " zombies waiting to be processed")
        end
    end
end
