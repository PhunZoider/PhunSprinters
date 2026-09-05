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

function Core.onDebugZedLabels()

    if not Core.settings.Debug then
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
    local threshold = string.format("%.2f", (Core.settings.DarknessLevel or 74) * 0.01)
    local ps = player:getSquare()
    local env = Core.env
    for i = 0, zeds:size() - 1 do
        local z = zeds:get(i)
        if z then

            local zs = z:getSquare()
            local dist = (ps and zs) and ps:DistToProper(zs)
            if dist and dist < maxDistance then

                local key = Core.getId(z)
                local data = z:getModData().PhunSprinters
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

                -- key is Core.getId = IsoMovingObject.getID(), a PER-CLIENT object
                -- handle. That is fine now: nothing it keys crosses the wire any more.
                -- onlineId is the network identity (what ZombiePacket.id carries), shown
                -- so two clients can still be lined up against the same zed by eye.
                local onlineId = z.getOnlineID and z:getOnlineID()
                local text = key .. "/" .. tostring(onlineId) .. " (" .. state .. ")"

                if data and data.sprinter then
                    local sq = z:getCurrentSquare()
                    local light = sq and string.format("%.2f", sq:getLightLevel(playerNum)) or "?"
                    -- "base>live": recorded base speed, then what the zed actually reads
                    -- as right now. live showing nil means the speedType read is broken.
                    text = text .. " " .. string.format("%.2f", env.adjustedLightIntensity or 0) .. "/" .. light ..
                               "/" .. threshold .. " " .. tostring(data.baseSpeedType or "?") .. ">" ..
                               tostring(Core.speedTypeOf(z)) .. (z:isSkeleton() and " SKEL" or "")
                end

                -- "Above head": bump Z a bit.
                local wx, wy, wz = z:getX(), z:getY(), z:getZ() + 1.2
                local sx, sy = worldToScreen(playerNum, wx, wy, wz)
                getTextManager():DrawStringCentre(UIFont.Small, sx, sy, text, color[1], color[2], color[3], color[4])

            end

        end
    end
end
