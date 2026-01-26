if isServer() then
    return
end
local Core = PhunSprinters
local PL = PhunLib

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
    local key = Core:getId(zed)
    debugZedLabels[key] = {
        text = tostring(text),
        untilMs = getTimestampMs() + (durationMs or 2000),
        color = color or {1, 1, 1, 1}
    }
end

function Core.onDebugZedLabels()

    if not Core.getOption("Debug") then
        return
    end
    if not PL.isAdmin() then
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
    local maxDistance = Core.getOption("MaxDistance2") or 25
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
            local dist = ps and ps:DistToProper(zs)
            if ps and dist and dist < maxDistance then

                local key = Core:getId(z)
                local data = Core:getZedData(z)
                local isSprinter = Core.sprinterIds[key]

                local label = {
                    text = key .. " (" .. (tostring(isSprinter) or "?") .. ")",
                    color = {0, 1, 0, 1}
                }

                local color = {0, 1, 0, 1}
                if data then
                    if data.sprinter then
                        local speedText = Core.getZedSpeedType(z) or "?";
                        local fog = env.fogIntensity and string.format("%.2f", env.fogIntensity) or "?"
                        local light = string.format("%.2f", z:getCurrentSquare():getLightLevel(0))

                        local txt = string.format("%.2f", Core.env.adjustedLightIntensity) .. "/" .. light .. "/" ..
                                        threshold .. " " .. tostring(data.sprinting == true) .. ") " ..
                                        tostring(speedText) .. "/" .. tostring(data.originalSpeed or "?")
                        color = data.sprinting and {1, 0, 0, 1} or {1, 1, 0, 1}

                        label = {
                            text = label.text .. " " .. txt,
                            color = color or {1, 1, 1, 1}
                        }
                    end
                end
                if label then

                    -- "Above head": bump Z a bit.
                    local wx, wy, wz = z:getX(), z:getY(), z:getZ() + 1.2
                    local sx, sy = worldToScreen(playerNum, wx, wy, wz)

                    local c = label.color
                    getTextManager():DrawStringCentre(UIFont.Small, sx, sy, label.text, c[1], c[2], c[3], c[4])

                end
            end

        end
    end
end
