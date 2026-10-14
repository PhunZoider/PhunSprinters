if isServer() then
    return
end
local Core = PhunSprinters

local function worldToScreen(playerNum, wx, wy, wz)
    -- IsoUtils uses isometric projection; camera offsets shift into viewport space.
    local sx = IsoUtils.XToScreen(wx, wy, wz, 0)
    local sy = IsoUtils.YToScreen(wx, wy, wz, 0)

    -- Offsets can be per-player in splitscreen; try per-player first, fall back.
    local offX = (IsoCamera.getOffX and IsoCamera.getOffX(playerNum)) or IsoCamera.getOffX()
    local offY = (IsoCamera.getOffY and IsoCamera.getOffY(playerNum)) or IsoCamera.getOffY()

    sx = sx - offX
    sy = sy - offY

    -- If splitscreen, add that player's viewport origin.
    if IsoCamera.getScreenLeft and IsoCamera.getScreenTop then
        sx = sx + IsoCamera.getScreenLeft(playerNum)
        sy = sy + IsoCamera.getScreenTop(playerNum)
    end

    return sx, sy
end

local debugZedLabels = {}

local function setLabel(zed, text, durationMs, color)
    if not zed or not text then
        return
    end
    local key = Core.getId(zed)
    debugZedLabels[key] = {
        text = tostring(text),
        untilMs = getTimestampMs() + (durationMs or 2000),
        color = color or {1, 1, 1, 1}
    }
end

local speedNames = {
    [1] = "Sprinter",
    [2] = "Fast Shambler",
    [3] = "Shambler"
}

-- Simple mode: what the zed is doing right now, nothing else. Colour carries the verdict:
-- green not one of ours, yellow one of ours being held back, red one of ours running.
-- Untested stays grey for the same reason as in Extended: it is not a "no" yet.
local function simpleLabel(z, data)
    local live = Core.speedTypeOf(z)
    local text = speedNames[live] or tostring(live)
    local color
    if not data or data.sprinter == nil then
        color = {0.7, 0.7, 0.7, 1}
    elseif data.sprinter ~= true then
        color = {0, 1, 0, 1}
    elseif data.sprinting then
        color = {1, 0, 0, 1}
    else
        color = {1, 1, 0, 1}
    end
    return text, color
end

-- Extended mode: everything per zed that explains a decision.
local function extendedLabel(z, data, player)

    local key = Core.getId(z)
    local isSprinter = data and data.sprinter

    -- The verdict is the zed's own modData and nothing else, so these four
    -- states are the whole story. Green must not double as the default:
    -- "never tested" and "tested and failed" look identical to a player
    -- otherwise, which once made routine first-time testing look like
    -- re-rolling.
    local color, state
    if isSprinter == nil then
        color, state = {0.7, 0.7, 0.7, 1}, "untested"
    elseif isSprinter ~= true then
        color, state = {0, 1, 0, 1}, "no"
    elseif data.sprinting then
        color, state = {1, 0, 0, 1}, "run"
    else
        color, state = {1, 1, 0, 1}, "walk"
    end

    -- Only what varies per zed. The global light, the fog, the darkness
    -- threshold, the mode and whether sprinting is on at all are all in the
    -- sensor UI's debug tooltip already, once, instead of repeated on every
    -- label. Only one id too: Core.getId is what the mod keys on, and the
    -- onlineId was diagnostic residue from the MP sync investigation.
    local text = key .. " " .. state

    local live = Core.speedTypeOf(z)

    if data and data.sprinter then
        -- Light only matters to the decision in these two modes; anywhere
        -- else it is a number that explains nothing.
        if Core.settings.Mode == 4 or Core.settings.SlowInLight then
            text = text .. " L" .. string.format("%.0f", Core.effectiveLight(z, player))
        end
        -- "base>live": the speed it returns to, then what it reads as now.
        text = text .. " " .. tostring(data.baseSpeedType or "?") .. ">" .. tostring(live)
        -- Its own sprint speed, once it has been given one.
        if data.speedScalePct then
            text = text .. " " .. tostring(data.speedScalePct) .. "%"
        end
    else
        text = text .. " " .. tostring(live)
    end

    if z:isSkeleton() then
        text = text .. " SKEL"
    end

    return text, color
end

function Core.onDebugZedLabels()

    local mode = Core.debugMode()
    if mode == Core.debugModes.off then
        return
    end
    if not Core.tools.isAdmin(getPlayer()) then
        return
    end

    local player = getSpecificPlayer(0)
    if not player then
        return
    end
    local playerNum = player:getPlayerNum()

    local zeds = getCell():getZombieList()
    if not zeds then
        return
    end

    local t = getTimestampMs()
    local maxDistance = Core.settings.MaxDistance2 or 25
    if maxDistance > 25 then
        maxDistance = 25
    end
    local ps = player:getSquare()
    for i = 0, zeds:size() - 1 do
        local z = zeds:get(i)
        if z then

            local zs = z:getSquare()
            local dist = (ps and zs) and ps:DistToProper(zs)
            if dist and dist < maxDistance then

                local data = z:getModData().PhunSprinters
                local text, color
                if mode == Core.debugModes.simple then
                    text, color = simpleLabel(z, data)
                else
                    text, color = extendedLabel(z, data, player)
                end

                -- "Above head": bump Z a bit.
                local wx, wy, wz = z:getX(), z:getY(), z:getZ() + 1.2
                local sx, sy = worldToScreen(playerNum, wx, wy, wz)
                getTextManager():DrawStringCentre(UIFont.Small, sx, sy, text, color[1], color[2], color[3], color[4])

            end

        end
    end
end
