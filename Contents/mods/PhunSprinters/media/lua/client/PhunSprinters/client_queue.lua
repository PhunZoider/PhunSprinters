if isServer() then
    return
end
local getPlayer = getPlayer
local getTimestamp = getTimestamp
local Core = PhunSprinters

-- ============================================================
-- Zombie Queue Management
-- ============================================================

function Core:enqueueUpdate(zed)
    if not zed or zed:isDead() then
        return
    end

    local id = self:getId(zed)
    local isSprinter = self.sprinterIds[tostring(id)]
    local player = getPlayer()
    if not player or self.queueIds[id] then
        return
    end

    -- local dx, dy = zed:getX() - player:getX(), zed:getY() - player:getY()
    -- local distance = dx * dx + dy * dy
    local zs = zed:getSquare()
    local ps = player:getSquare()
    local distance = ps and ps:DistToProper(zs) or 0
    if distance < (self.settings.MinDistance2 or 14) then
        -- too close
        if self.sprint and isSprinter then
            if self.settings.Mode == 4 or self.settings.SlowInLight then
                -- adjust for light
                self:adjustForLight(zed, self:getZedData(zed), zed:getTarget(), distance)
            end
        end

        return
    elseif distance > (self.settings.MaxDistance2 or 35) then
        -- too far away
        return
    end

    local data = self:getZedData(zed)
    if data then
        if data.sprinter == false then
            return
        end
        -- if data.modified then
        if data.dressed == nil then
            self:applyZedVisualState(zed, data)
            data.dressed = true
        end
        --     return
        -- end
    end

    self.queueIds[id] = true
    table.insert(self.queue, zed)
end

local lastQueueFullMessage = 0
function Core:processQueue()
    local count = 0
    local maxCount = self.settings.MaxQueue or 10

    while #self.queue > 0 and count < maxCount do
        local zed = table.remove(self.queue, 1)
        self.queueIds[self:getId(zed)] = nil
        self:updateZed(zed)
        count = count + 1
    end

    if self.settings.Debug and count == maxCount and #self.queue > 0 then
        if getTimestamp() - lastQueueFullMessage > 3 then
            lastQueueFullMessage = getTimestamp()
            print("PhunSprinters: Queue full — " .. tostring(#self.queue) .. " more zombies waiting.")
        end
    end
end
