if isServer() then
    return
end
local Core = PhunSprinters
local getTimestampMs = getTimestampMs

-- ============================================================
-- Performance probe
-- ============================================================
--
-- Answers one question: how much frame time does this mod's per-zed work cost? Run it
-- from the debug Lua console. Nothing here runs unless a probe is started.
--
--   PhunSprinters.probe.spawn(300)          ring of zeds 15-30 tiles out, for a repeatable scene
--   PhunSprinters.probe.start(60, "mode4")  measure for 60 real seconds
--   PhunSprinters.probe.start(60, "off", true)  same, with the mod's per-zed work disabled
--   PhunSprinters.probe.start(60, "d", false, true)  detail: also break the cost down by sub-step
--   PhunSprinters.probe.stop()              end early (also prints the report)
--
-- It works by swapping Core.enqueueUpdate, Core.processQueue and Core.testEnvironment for
-- timed wrappers, and restoring them afterwards. The callers look them up by name on each
-- call, so the hot path itself is untouched.
--
-- Timing: Lua only has a millisecond clock, and one call takes microseconds. Each call is
-- still timed, and the readings summed: a call lasting d ms straddles a clock tick with
-- probability d, so over many calls the sum converges on the true total. The clock's
-- actual step is measured first and reported, because if Windows is running it at 15.6ms
-- the total is still right on average but needs a longer run to settle.
--
-- Detail mode also wraps the sub-steps (DETAIL below), which are likewise called by name.
-- Each gets self and inclusive time, split by which top-level function it ran under. The
-- self time of enqueueUpdate itself is what is left: the square and distance lookups,
-- getPlayer, the queue insert. Nested timers cost something, so the wrapper's own cost is
-- measured and subtracted, but take the plain-mode totals as the real figure and detail
-- mode as the proportions.

local probe = {}
Core.probe = probe

local function printLn(s)
    print("[PhunSprinters probe] " .. s)
end

-- Smallest step the clock actually takes, and what one read costs.
local function calibrate()
    local steps, minStep = 0, nil
    local last = getTimestampMs()
    local deadline = last + 200
    while steps < 20 do
        local now = getTimestampMs()
        if now ~= last then
            local step = now - last
            if not minStep or step < minStep then
                minStep = step
            end
            steps = steps + 1
            last = now
        end
        if now > deadline then
            break
        end
    end

    local n = 100000
    local t0 = getTimestampMs()
    for _ = 1, n do
        getTimestampMs()
    end
    local readCostMs = (getTimestampMs() - t0) / n

    return minStep or 0, readCostMs
end

local function newBucket()
    return {
        calls = 0,
        ms = 0
    }
end

local function timed(bucket, fn, isMethod)
    if isMethod then
        return function(self, ...)
            local t0 = getTimestampMs()
            fn(self, ...)
            bucket.ms = bucket.ms + (getTimestampMs() - t0)
            bucket.calls = bucket.calls + 1
        end
    end
    return function(...)
        local t0 = getTimestampMs()
        fn(...)
        bucket.ms = bucket.ms + (getTimestampMs() - t0)
        bucket.calls = bucket.calls + 1
    end
end

-- ------------------------------------------------------------
-- Detail mode: nested timers
-- ------------------------------------------------------------

-- Sub-steps of the hot path. All are called as Core.<name>, so wrapping them by name sees
-- every call.
local DETAIL = {"getId", "getNumId", "getZedData", "isIgnoredMutant", "mutantType", "speedTypeOf", "adoptIfSprinting",
                "applySprintState", "applyZedVisualState", "updateZed", "shouldSprint", "adjustForLight",
                "effectiveLight", "makeSprint", "makeNormal", "reassertSpeed", "scream"}

-- cur is the bucket set of the top-level function currently running, or prof.other when
-- the call came from anywhere else (the debug overlay, an event handler). stack[depth] is
-- the bucket of the innermost wrapped call, so a finishing call can charge its parent.
local prof = {
    cur = nil,
    other = nil,
    stack = {},
    depth = 0,
    count = 0
}

local function detailBucket(set, name)
    local b = set[name]
    if not b then
        b = {
            calls = 0,
            ms = 0,
            desc = 0, -- wrapped calls nested inside this one's window
            childMs = 0, -- time inside direct children's windows
            childCalls = 0
        }
        set[name] = b
    end
    return b
end

local function profiled(name, fn, topSet)
    return function(...)
        if topSet then
            -- A fresh top-level call. Resetting here also recovers if an error escaped a
            -- nested call and left the stack unbalanced.
            prof.cur = topSet
            prof.depth = 0
        end
        local b = detailBucket(prof.cur, name)
        local parent = prof.depth > 0 and prof.stack[prof.depth]
        local depth = prof.depth + 1
        prof.depth = depth
        prof.stack[depth] = b
        local n0 = prof.count
        prof.count = n0 + 1
        local t0 = getTimestampMs()
        local r1, r2 = fn(...)
        local d = getTimestampMs() - t0
        prof.depth = depth - 1
        b.ms = b.ms + d
        b.calls = b.calls + 1
        b.desc = b.desc + (prof.count - n0 - 1)
        if parent then
            parent.childMs = parent.childMs + d
            parent.childCalls = parent.childCalls + 1
        end
        if topSet then
            prof.cur = prof.other
        end
        return r1, r2
    end
end

-- What one wrapped call costs over a plain one: two clock reads plus the bookkeeping.
local function calibrateWrapper()
    local noop = function()
    end
    local n = 100000
    local t0 = getTimestampMs()
    for _ = 1, n do
        noop()
    end
    local plain = getTimestampMs() - t0

    prof.cur = {}
    prof.depth = 0
    local w = profiled("noop", noop)
    t0 = getTimestampMs()
    for _ = 1, n do
        w()
    end
    local wrapped = getTimestampMs() - t0
    prof.cur = nil
    prof.depth = 0
    return math.max(0, (wrapped - plain) / n)
end

-- Zeds in the cell, in range, and ours, at this moment.
local function census()
    local c = {
        total = 0,
        inRange = 0,
        sprinters = 0,
        running = 0
    }
    local player = getPlayer()
    local ps = player and player:getSquare()
    local maxD = Core.settings.MaxDistance2 or 35
    local zeds = getCell():getZombieList()
    for i = 0, zeds:size() - 1 do
        local zed = zeds:get(i)
        if zed and not zed:isDead() then
            c.total = c.total + 1
            local zs = zed:getSquare()
            if ps and zs and ps:DistToProper(zs) <= maxD then
                c.inRange = c.inRange + 1
            end
            local d = zed:getModData().PhunSprinters
            if d and d.sprinter then
                c.sprinters = c.sprinters + 1
                if d.sprinting then
                    c.running = c.running + 1
                end
            end
        end
    end
    return c
end

local function percentile(sorted, p)
    if #sorted == 0 then
        return 0
    end
    local i = math.max(1, math.min(#sorted, math.ceil(#sorted * p)))
    return sorted[i]
end

local run = nil

local function onTick()
    if not run then
        return
    end
    local now = getTimestampMs()
    if run.lastTick then
        run.frames[#run.frames + 1] = now - run.lastTick
    end
    run.lastTick = now
    if now >= run.endsAt then
        probe.stop()
    end
end

local function restore()
    if run and run.originals then
        Core.enqueueUpdate = run.originals.enqueueUpdate
        Core.processQueue = run.originals.processQueue
        Core.testEnvironment = run.originals.testEnvironment
        for name, fn in pairs(run.originals.detail or {}) do
            Core[name] = fn
        end
    end
    prof.cur = nil
    prof.other = nil
    prof.depth = 0
    Events.OnTick.Remove(onTick)
end

function probe.start(seconds, label, disableMod, detail)
    if run then
        printLn("already running, call PhunSprinters.probe.stop() first")
        return
    end
    seconds = seconds or 60

    local step, readCost = calibrate()
    -- Detail on a disabled run would time nothing.
    detail = detail == true and disableMod ~= true
    local wrapCost = detail and calibrateWrapper() or 0

    run = {
        label = label or "run",
        disabled = disableMod == true,
        seconds = seconds,
        clockStep = step,
        readCost = readCost,
        wrapCost = wrapCost,
        enqueue = newBucket(),
        queue = newBucket(),
        env = newBucket(),
        frames = {},
        before = census(),
        originals = {
            enqueueUpdate = Core.enqueueUpdate,
            processQueue = Core.processQueue,
            testEnvironment = Core.testEnvironment
        }
    }

    if run.disabled then
        -- Baseline: the event still fires, but the mod does nothing with it.
        local noop = function()
        end
        Core.enqueueUpdate = timed(run.enqueue, noop)
        Core.processQueue = timed(run.queue, noop)
    elseif detail then
        run.detail = {
            enqueue = {},
            queue = {},
            other = {}
        }
        run.originals.detail = {}
        for _, name in ipairs(DETAIL) do
            local fn = Core[name]
            if type(fn) == "function" then
                run.originals.detail[name] = fn
                Core[name] = profiled(name, fn)
            end
        end
        prof.other = run.detail.other
        prof.cur = prof.other
        prof.depth = 0
        Core.enqueueUpdate = profiled("enqueueUpdate", run.originals.enqueueUpdate, run.detail.enqueue)
        Core.processQueue = profiled("processQueue", run.originals.processQueue, run.detail.queue)
    else
        Core.enqueueUpdate = timed(run.enqueue, run.originals.enqueueUpdate)
        Core.processQueue = timed(run.queue, run.originals.processQueue)
    end
    Core.testEnvironment = timed(run.env, run.originals.testEnvironment, true)

    run.startedAt = getTimestampMs()
    run.endsAt = run.startedAt + seconds * 1000
    Events.OnTick.Add(onTick)

    printLn(string.format("started '%s' for %ds%s%s. Clock step %dms, read %.4fms", run.label, seconds,
        run.disabled and " (mod disabled)" or "", detail and " (detail)" or "", step, readCost))
    if detail then
        printLn(string.format("detail wrapper costs %.2f us/call, subtracted from the figures", wrapCost * 1000))
    end
end

function probe.stop()
    if not run then
        return
    end
    local r = run
    restore()
    run = nil

    local elapsed = getTimestampMs() - r.startedAt
    local frames = r.frames
    local ticks = #frames
    table.sort(frames)
    local frameSum = 0
    for i = 1, ticks do
        frameSum = frameSum + frames[i]
    end
    local avgFrame = ticks > 0 and frameSum / ticks or 0
    local after = census()

    -- Each timed call includes roughly one clock read of its own.
    local function cost(b)
        local corrected = math.max(0, b.ms - b.calls * r.readCost)
        return {
            perTick = ticks > 0 and corrected / ticks or 0,
            perCallUs = b.calls > 0 and corrected / b.calls * 1000 or 0,
            callsPerTick = ticks > 0 and b.calls / ticks or 0
        }
    end
    if r.detail then
        -- The top-level wrappers recorded into the detail sets. Take out the cost of the
        -- wrapped calls nested inside them, so the totals compare with a plain run.
        local function top(set, name)
            local b = set[name]
            if not b then
                return newBucket()
            end
            return {
                calls = b.calls,
                ms = b.ms - b.desc * r.wrapCost
            }
        end
        r.enqueue = top(r.detail.enqueue, "enqueueUpdate")
        r.queue = top(r.detail.queue, "processQueue")
    end
    local e, q, env = cost(r.enqueue), cost(r.queue), cost(r.env)
    local modPerTick = e.perTick + q.perTick + env.perTick

    local lines = {
        "==== " .. r.label .. (r.disabled and " (mod disabled)" or "") .. " ====",
        string.format("%.1fs, %d ticks. Mode %s, DefaultRisk %s, SlowInLight %s, sprint conditions %s",
            elapsed / 1000, ticks, tostring(Core.settings.Mode), tostring(Core.settings.DefaultRisk),
            tostring(Core.settings.SlowInLight), tostring(Core.sprint)),
        string.format("zeds  start: %d total, %d in range, %d sprinters, %d running", r.before.total,
            r.before.inRange, r.before.sprinters, r.before.running),
        string.format("zeds  end:   %d total, %d in range, %d sprinters, %d running", after.total, after.inRange,
            after.sprinters, after.running),
        string.format("frame ms: avg %.2f  p50 %d  p95 %d  p99 %d  max %d  (~%.0f fps)", avgFrame,
            percentile(frames, 0.5), percentile(frames, 0.95), percentile(frames, 0.99), frames[ticks] or 0,
            avgFrame > 0 and 1000 / avgFrame or 0),
        string.format("enqueueUpdate:   %.3f ms/tick  %.1f calls/tick  %.2f us/call", e.perTick, e.callsPerTick,
            e.perCallUs),
        string.format("processQueue:    %.3f ms/tick  %.1f calls/tick  %.2f us/call", q.perTick, q.callsPerTick,
            q.perCallUs),
        string.format("testEnvironment: %.3f ms/tick  %.2f calls/tick  %.2f us/call", env.perTick, env.callsPerTick,
            env.perCallUs),
        string.format("MOD TOTAL:       %.3f ms/tick = %.1f%% of an average frame", modPerTick,
            avgFrame > 0 and modPerTick / avgFrame * 100 or 0),
        string.format("clock step %dms%s", r.clockStep,
            r.clockStep > 2 and " -- coarse clock, use runs of 120s+ for stable totals" or "")
    }
    if r.detail then
        local function pad(str, w)
            return str .. string.rep(" ", math.max(1, w - #str))
        end
        local function perTick(ms)
            return ticks > 0 and ms / ticks or 0
        end
        local sections = {{"enqueue", "under enqueueUpdate"}, {"queue", "under processQueue"},
                          {"other", "called from elsewhere"}}
        for _, section in ipairs(sections) do
            local rows = {}
            for name, b in pairs(r.detail[section[1]]) do
                -- Every wrapped call nested in this window cost wrapCost, of which about one
                -- clock read fell inside its own window and is already in childMs.
                local incl = math.max(0, b.ms - b.calls * r.readCost - b.desc * r.wrapCost)
                local own = math.max(0, b.ms - b.childMs - b.calls * r.readCost - b.childCalls *
                    math.max(0, r.wrapCost - r.readCost))
                rows[#rows + 1] = {
                    name = name,
                    calls = b.calls,
                    incl = incl,
                    own = own
                }
            end
            if #rows > 0 then
                table.sort(rows, function(a, b)
                    return a.own > b.own
                end)
                lines[#lines + 1] = "-- detail, " .. section[2] .. ", by self time --"
                lines[#lines + 1] = pad("function", 22) .. pad("calls/tick", 12) .. pad("self ms/tick", 14) ..
                                        pad("incl ms/tick", 14) .. "self us/call"
                for _, row in ipairs(rows) do
                    lines[#lines + 1] = pad(row.name, 22) ..
                                            pad(string.format("%.1f", ticks > 0 and row.calls / ticks or 0), 12) ..
                                            pad(string.format("%.3f", perTick(row.own)), 14) ..
                                            pad(string.format("%.3f", perTick(row.incl)), 14) ..
                                            string.format("%.2f", row.calls > 0 and row.own / row.calls * 1000 or 0)
                end
            end
        end
        lines[#lines + 1] = "self of enqueueUpdate = queued and verdict checks, squares, distance, queue insert"
        lines[#lines + 1] = "self of processQueue = the dequeue loop, getPlayer and the player square"
    end
    for _, l in ipairs(lines) do
        printLn(l)
    end
    return lines
end

-- A ring of zeds around the player, so every run starts from the same layout.
function probe.spawn(count, minRadius, maxRadius)
    local player = getPlayer()
    if not player then
        return
    end
    count = count or 300
    minRadius = minRadius or 15
    maxRadius = maxRadius or 30
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    for i = 1, count do
        local angle = (i / count) * 2 * math.pi
        local radius = minRadius + ZombRand(maxRadius - minRadius + 1)
        addZombiesInOutfit(math.floor(px + math.cos(angle) * radius), math.floor(py + math.sin(angle) * radius), pz, 1,
            nil, 50)
    end
    printLn(string.format("spawned %d zeds %d-%d tiles out", count, minRadius, maxRadius))
end
