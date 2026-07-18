-- API Constants
MONITOR_WIDTH = 164 -- 0.5 scaling, 8 blocks TODO: calc dynamically
MONITOR_HEIGHT = 81 -- 0.5 scaling, 6 blocks TODO: calc dynamically
CONFIG_PATH = './mm.json'
-- List of background colors avaliable during setup
COLORS = { "orange", "magenta", "lightBlue", "blue", "yellow", "lime", "green", "pink", "red", "purple", "cyan", "brown",
    "gray", "lightGray" }

-- Prerun checks
if #table.pack(peripheral.find("monitor")) == 0 then
    error("Multimonitor API requires at least one connected monitor")
elseif #table.pack(peripheral.find("monitor")) == 1 then
    -- Return direct access to one real monitor without abstractions of this API
    return table.pack(peripheral.find("monitor"))[1]
end

-- Setup configuration
local function setup()
    print("[ Multimonitor API Configuration ]\nEach monitor in the setup should be 8x6 blocks (default maximum size)")
    print("Enter amount of horizontal monitors:")
    local w = tonumber(read())

    print("Enter amount of vertical monitors:")
    local h = tonumber(read())

    local c = w * h

    local total_width = 0
    local total_height = 0

    print("Click on each monitor in this order: left->right, top->bottom")

    local monitors = {}

    local function fill_monitor(m, id, row, col)
        m.setBackgroundColor(colors[COLORS[math.random(1, #COLORS)]])
        m.clear()
        m.setCursorPos(1, 1)
        m.setTextScale(5)
        m.write("Monitor #" .. tostring(id))
        m.setCursorPos(1, 2)
        m.write("Row: " .. tostring(row) .. " | Col: " .. tostring(col))
    end

    local prev_r = -1
    while #monitors < c do
        local e = { os.pullEvent("monitor_touch") }
        print("Click on ", #monitors + 1, " monitor...")
        if e[1] == "monitor_touch" then
            monitors[#monitors + 1] = e[2]
            local m = peripheral.wrap(e[2])

            m.setTextScale(0.5)
            local row, col = math.floor((#monitors - 1) / w), (#monitors - 1) % w
            if row == 0 then
                total_width = total_width + table.pack(m.getSize())[1]
                print(total_width)
            end
            if row > prev_r then
                total_height = total_height + table.pack(m.getSize())[2]
            end
            prev_r = row
            fill_monitor(m, #monitors, row + 1, col + 1)
            print("Registered" .. tostring(#monitors) .. " monitor\n")
        end
    end

    print("Total resolution:", total_width, "x", total_height, " chars")
    print("Verify that the order, row, and column of each monitor in the setup are correct.")
    term.write("OK? [Y/n]:")
    local ans = read()
    if ans:lower():sub(1, 1) == "n" then
        print("Beginning setup from scratch...")
        return setup()
    end

    local config = {}
    config["rows"] = h
    config["cols"] = w
    config["width"] = total_width
    config["height"] = total_height
    config["monitors"] = monitors

    local fp, errmsg = io.open(CONFIG_PATH, "w")
    if not fp then
        print("WARNING! Unable to write config file for future usage, check available disk space")
        if errmsg ~= nil then
            print(errmsg)
        end
        return config
    end
    fp:write(textutils.serialiseJSON(config))
    fp:flush()
    fp:close()
    print("Configuration is finished.\nTo setup again (e.g on physical setup change) delete file `mm.json'")

    return config
end

-- Function for loading config or doing setup if it does not exists
local function load_config()
    if not fs.exists(CONFIG_PATH) then
        return setup()
    end
    local fp = io.open(CONFIG_PATH, "r")
    local data = textutils.unserialiseJSON(fp:read())
    return data
end

CONFIG = load_config()

VirtMonitor = {
    ["_cx"] = 1,
    ["_cy"] = 1,
    ["_cb"] = false,
    ["_bgc"] = colors.black,
    ["_fgc"] = colors.white,
    ["_pid"] = -1
}

-- Function for calculating useful positioning info
-- Returns:
-- 1. ID of the active (current) real monitor
-- 2. X pos of the cursor in active monitor
-- 3. Y pos of the cursor in active monitor
-- 4. Column that contains active monitor
-- 5. Row that contains active monitor
-- 6. Min ID of monitor in current row
-- 7. Max ID of monitor in current row
function VirtMonitor._calc_real_pos()
    local col = math.min(CONFIG["cols"],
        math.floor((VirtMonitor["_cx"] - 1) / MONITOR_WIDTH) + 1)
    local row = math.min(CONFIG["rows"], math.floor((VirtMonitor["_cy"] - 1) / MONITOR_HEIGHT) + 1)

    local mid = col +
        math.min((CONFIG["cols"] * (CONFIG["rows"] - 1)),
            CONFIG["cols"] * math.floor((VirtMonitor["_cy"] - 1) / MONITOR_HEIGHT))

    local rx = VirtMonitor["_cx"] -
        math.min(math.floor((VirtMonitor["_cx"] - 1) / MONITOR_WIDTH) * MONITOR_WIDTH,
            (MONITOR_WIDTH * CONFIG["cols"]) - 1)
    local ry = VirtMonitor["_cy"] -
        math.min(math.floor((VirtMonitor["_cy"] - 1) / MONITOR_HEIGHT) * MONITOR_HEIGHT,
            (MONITOR_HEIGHT * CONFIG["rows"]) - 1)

    local min_id = 1 + ((row - 1) * CONFIG["cols"])
    local max_id = row * CONFIG["cols"]

    return mid, rx, ry, col, row, min_id, max_id
end

-- Fuction for syncing state of monitors in the setup
function VirtMonitor._sync_grid(resync_all)
    local c_mid, rx, ry, _, _, min_id, max_id = VirtMonitor._calc_real_pos()

    if resync_all then
        -- Resync all real monitors, very expensive!
        for k, v in pairs(CONFIG["monitors"]) do
            local m = peripheral.wrap(v)
            m.setBackgroundColor(VirtMonitor["_bgc"])
            m.setTextColor(VirtMonitor["_fgc"])
            if m.getTextScale() ~= 0.5 then
                -- Reset text scale only if needed (saves content otherwise)
                m.setTextScale(0.5)
            end
            m.setCursorBlink(VirtMonitor["_cb"] and k == c_mid)
            m.setCursorPos(k == c_mid and rx or 1, k == c_mid and ry or (min_id <= k and k <= max_id) and ry or 1)
        end
    else
        -- Resync only previous and new active (current) real monitors
        -- Remove cursor blink if active (current) real monitor changed
        if VirtMonitor["_pid"] ~= c_mid then
            local m = peripheral.wrap(CONFIG["monitors"][VirtMonitor["_pid"]])
            m.setCursorBlink(false)
        end

        -- Sync active (current) real monitor state
        local m = peripheral.wrap(CONFIG["monitors"][c_mid])
        m.setCursorBlink(VirtMonitor["_cb"])
        m.setCursorPos(rx, ry)
    end

    VirtMonitor["_pid"] = c_mid
end

-- Function for getting full size (w,h)
-- Returns:
-- 1. Width of the setup
-- 2. Height of the setup
function VirtMonitor.getSize()
    return CONFIG["width"], CONFIG["height"]
end

-- Function for clearing entire setup (every real monitor)
function VirtMonitor.clear()
    for _, m in pairs(CONFIG["monitors"]) do
        peripheral.wrap(m).clear()
    end
end

-- Function for getting text color of the monitor
-- Returs:
-- 1. Text color
function VirtMonitor.getTextColour()
    return VirtMonitor["_fgc"]
end

VirtMonitor.getTextColor = VirtMonitor.getTextColour

-- Function for setting text color of the monitor
function VirtMonitor.setTextColour(colour)
    VirtMonitor["_fgc"] = colour
    VirtMonitor._sync_grid(true)
end

VirtMonitor.setTextColor = VirtMonitor.setTextColour

-- Function for getting background color of the monitor
-- Returns:
-- 1. Background color
function VirtMonitor.getBackgroundColour()
    return VirtMonitor["_bgc"]
end

VirtMonitor.getBackgroundColor = VirtMonitor.getBackgroundColour

-- Function for setting background color of the monitor
function VirtMonitor.setBackgroundColour(colour)
    VirtMonitor["_bgc"] = colour
    VirtMonitor._sync_grid(true)
end

VirtMonitor.setBackgroundColor = VirtMonitor.setBackgroundColour

-- Function for checking if setup supports colors
-- Returns:
-- 1. Whether this setup supports colors
function VirtMonitor.isColor()
    for _, m in pairs(CONFIG["monitors"]) do
        if not m.isColor() then
            return false
        end
    end
    return true
end

VirtMonitor.isColour = VirtMonitor.isColor

-- Function for getting position of the virtual cursor
-- Returns:
-- 1. X pos
-- 2. Y pos
function VirtMonitor.getCursorPos()
    return VirtMonitor["_cx"], VirtMonitor["_cy"]
end

-- Function for setting position of the virtual cursor
function VirtMonitor.setCursorPos(x, y)
    VirtMonitor["_cx"] = x
    VirtMonitor["_cy"] = y

    -- TODO: think about removing full resync to speedup this function
    VirtMonitor._sync_grid(true)
end

-- Function for getting blink state of the virtual cursor
-- Returns:
-- 1. Whether blink is enabled
function VirtMonitor.getCursorBlink()
    return VirtMonitor["_cb"]
end

-- Function for setting blink state of the virtual cursor
function VirtMonitor.setCursorBlink(blink)
    VirtMonitor["_cb"] = blink
    VirtMonitor._sync_grid()
end

-- Function for the writing text on the monitors
function VirtMonitor.write(text)
    text = tostring(text)

    local c_mid, _, _, _, _, _, max_id = VirtMonitor._calc_real_pos()

    local written_width = 0

    -- Write only on monitors on the same row
    for i = c_mid, max_id do
        local m = peripheral.wrap(CONFIG["monitors"][i])
        local cx, _ = m.getCursorPos()

        -- Maximum width for current monitor that we can use to write text, can't be < 0
        local max_width = math.max(MONITOR_WIDTH - cx + 1, 0)

        -- Write part of the text on the monitor
        m.write(text:sub(written_width + 1, written_width + max_width))

        -- Change total written width
        written_width = written_width + #text:sub(written_width + 1, written_width + max_width)
    end

    -- Update cursot position after text write to sync everything
    VirtMonitor.setCursorPos(VirtMonitor["_cx"] + written_width, VirtMonitor["_cy"])
end

-- Function for blitting text on the monitors
function VirtMonitor.blit(text, fgColor, bgColor)
    -- Implementation based on write func, but does sub for fg and bg color strings

    text = tostring(text)
    fgColor = tostring(fgColor)
    bgColor = tostring(bgColor)

    if #text ~= #fgColor or #text ~= #bgColor then
        error("Text and colors length must be equal")
    end

    local c_mid, _, _, _, _, _, max_id = VirtMonitor._calc_real_pos()

    local written_width = 0

    -- Write only on monitors on the same row
    for i = c_mid, max_id do
        local m = peripheral.wrap(CONFIG["monitors"][i])
        local cx, _ = m.getCursorPos()

        -- Maximum width for current monitor that we can use to write text, can't be < 0
        local max_width = math.max(MONITOR_WIDTH - cx + 1, 0)

        -- Blit part of the text on the monitor
        m.blit(text:sub(written_width + 1, written_width + max_width),
            fgColor:sub(written_width + 1, written_width + max_width),
            bgColor:sub(written_width + 1, written_width + max_width))

        -- Change total written width
        written_width = written_width + #text:sub(written_width + 1, written_width + max_width)
    end

    -- Update cursot position after text write to sync everything
    VirtMonitor.setCursorPos(VirtMonitor["_cx"] + written_width, VirtMonitor["_cy"])
end

-- Function for clearing line of the current row
function VirtMonitor.clearLine()
    local _, _, _, _, _, min_id, max_id = VirtMonitor._calc_real_pos()

    -- Clear line only for monitors in active (current) row
    for i = min_id, max_id do
        local m = peripheral.wrap(CONFIG["monitors"][i])
        m.clearLine()
    end
end

-- Resync all monitors before actual usage
VirtMonitor._sync_grid(true)

-- TODO: think about "classes" instead of global table
return VirtMonitor
