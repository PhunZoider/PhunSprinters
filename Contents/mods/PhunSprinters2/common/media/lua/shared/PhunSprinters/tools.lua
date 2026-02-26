local Core = PhunSprinters
local getOnlinePlayers = getOnlinePlayers
local tools = {}

tools.isLocal = not isClient() and not isServer() and not isCoopHost()

function tools.debug(...)

    local args = {...}
    for i, v in ipairs(args) do
        if type(v) == "table" then
            tools.printTable(v)
        else
            print(tostring(v))
        end
    end

end

function tools.printTable(t, indent)
    indent = indent or ""
    for key, value in pairs(t or {}) do
        if type(value) == "table" then
            print(indent .. key .. ":")
            tools.printTable(value, indent .. "  ")
        elseif type(value) ~= "function" then
            print(indent .. key .. ": " .. tostring(value))
        end
    end
end

function tools.formatNumber(number, decimals)
    number = number or 0
    -- Round the number to remove the decimal part
    local roundedNumber = math.floor(number + (decimals and 0.005 or 0.5))
    -- Convert to string and format with commas
    local formattedNumber = tostring(roundedNumber):reverse():gsub("(%d%d%d)", "%1,")
    formattedNumber = formattedNumber:reverse():gsub("^,", "")
    return formattedNumber
end

-- Converts PZ decimal hours to readable time
-- use12h = true  -> "9:15 PM"
-- use12h = false -> "21:15"
function tools.formatGameTime(decimalHours, use12h)
    if not decimalHours then
        return "??:??"
    end

    local hour = math.floor(decimalHours)
    local fraction = decimalHours - hour
    local minutes = math.floor(fraction * 60 + 0.5)

    -- handle rounding overflow
    if minutes >= 60 then
        minutes = 0
        hour = (hour + 1) % 24
    end

    if use12h == nil then
        use12h = not getCore():getOptionClock24Hour()
    end

    if use12h then
        local suffix = hour >= 12 and "PM" or "AM"
        local displayHour = hour % 12
        if displayHour == 0 then
            displayHour = 12
        end
        return string.format("%d:%02d %s", displayHour, minutes, suffix)
    end

    -- default: 24h
    return string.format("%02d:%02d", hour, minutes)
end

function tools.isAdmin(player, ignoreLocal)

    if isAdmin() or getDebug() or (Core.isLocal and not ignoreLocal) then
        return true
    end
    return (getAccessLevel and (getAccessLevel() == "moderator" or getAccessLevel() == "admin")) or false

end

function tools.onlinePlayers(all)

    local onlinePlayers;

    if tools.isLocal then
        onlinePlayers = ArrayList.new();
        local p = getPlayer()
        onlinePlayers:add(p);
    elseif all ~= false and isClient() then
        onlinePlayers = ArrayList.new();
        for i = 0, getOnlinePlayers():size() - 1 do
            local player = getOnlinePlayers():get(i);
            if player:isLocalPlayer() then
                onlinePlayers:add(player);
            end
        end
    else
        onlinePlayers = getOnlinePlayers();
    end

    return onlinePlayers;
end

return tools
