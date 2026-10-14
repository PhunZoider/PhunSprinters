if isServer() then
    return
end
local getPlayer = getPlayer
local getTimestamp = getTimestamp
local Core = PhunSprinters

-- ============================================================
-- Zombie Queue Management
-- ============================================================
--
-- enqueueUpdate runs for every zed in the cell on every tick, so everything here is
-- ordered cheapest-exit-first. Measured costs and the reasoning are in
-- Docs/perf-probe.md; in short, each Kahlua call costs around a microsecond, so the
-- win is in not making calls at all.

-- How often, in ticks, a zed already tested "not a sprinter" is looked at again. It
-- still has to be looked at: another controller may promote it (adoptIfSprinting), The
-- Mutants may reclassify it, or the object may be reused for a new zed (getZedData).
-- None of those need noticing within a tick. For scale, with 300 sprinters and a queue
-- of 20 per tick, each queued sprinter is already only updated every ~15 ticks.
local NOT_SPRINTER_RECHECK_TICKS = 10

local tick = 0

-- The player's square, looked up once per tick in processQueue rather than once per zed.
local playerSquare = nil

-- FIFO of zeds waiting for updateZed. head and tail move forward instead of shifting the
-- array: table.remove(queue, 1) moved every entry down on each call, and with ~280 queued
-- that was over half of processQueue's cost. keys[i] is queue[i]'s getNumId, kept so the
-- dequeue does not have to ask the zed again.
local queue, keys = {}, {}
local head, tail = 1, 0
-- getNumId -> true while that zed is in the queue.
local queued = {}

function Core.enqueueUpdate(zed)
    if not zed or zed:isDead() then
        return
    end

    local key = Core.getNumId(zed)
    if queued[key] then
        -- already waiting its turn
        return
    end

    local ps = playerSquare
    if not ps then
        return
    end

    -- Tested, and not one of ours. Staggered by id so the rechecks spread across ticks.
    local md = zed:getModData().PhunSprinters
    if md and md.sprinter == false and (tick + key) % NOT_SPRINTER_RECHECK_TICKS ~= 0 then
        return
    end

    local zs = zed:getSquare()
    local distance = zs and ps:DistToProper(zs) or 0
    if distance > (Core.settings.MaxDistance2 or 35) then
        -- too far away
        return
    end

    local data = Core.getZedData(zed)
    if not data then
        return
    end

    -- Another controller may have promoted this zed since we last looked. Do this
    -- before either branch below, so a zed we previously tested as "no" is not skipped
    -- while it is visibly sprinting.
    Core.adoptIfSprinting(zed, data)

    if distance < (Core.settings.MinDistance2 or 14) then
        -- Too close to queue, but a zed we already own still has to start, stop, react
        -- to light, scream, and hold its speed. Same decision as updateZed makes, so it
        -- is the same function -- this used to be a second copy and they drifted apart.
        if data.sprinter then
            Core.applySprintState(zed, data)
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

    tail = tail + 1
    queue[tail] = zed
    keys[tail] = key
    queued[key] = true
end

local lastQueueFullMessage = 0

-- Runs once per tick (from OnTick), so it also does the per-tick bookkeeping that
-- enqueueUpdate reads.
function Core.processQueue()
    tick = tick + 1
    local player = getPlayer()
    playerSquare = player and player:getSquare() or nil

    local count = 0
    local maxCount = Core.settings.MaxQueue or 20

    while head <= tail and count < maxCount do
        local zed = queue[head]
        queued[keys[head]] = nil
        queue[head] = nil
        keys[head] = nil
        head = head + 1
        Core.updateZed(zed)
        count = count + 1
    end

    if head > tail then
        -- Empty: start the indices over so they stay small.
        head, tail = 1, 0
    elseif count == maxCount then
        if getTimestamp() - lastQueueFullMessage > 3 then
            lastQueueFullMessage = getTimestamp()
            Core.debugLn("Queue is full, " .. tostring(tail - head + 1) .. " zombies waiting to be processed")
        end
    end
end
