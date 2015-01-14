-- livecode.lua 
-- by Christiaan Janssen
-- based on LICK
--
-- Simple livecoding environment for Löve2D.
-- Overwrites love.run, pressing all errors to the terminal/console
--
-- Usage:
-- require "livecode" 
-- at the beginning on main.lua.  No further changes needed
--
-- When you load extra files via love.filesystem.load(..), they will be tracked by the system.
-- Each time you save one of these files it will be reloaded automatically and the changes applied.
-- Additionally, the new callback love.livereload will be called if it exists. 
--
-- Control:
-- livecode.resetOnLoad -> if set to "true", love.load() will be called when reloading files (instead of love.livereload)
-- livecode.logReloads  -> if set to "true", the message "updated file _FILENAME_" will be printed on the console output 
--                        each time _FILENAME_ is reloaded
-- livecode.reloadOnKeypressed -> if set to "true", calls love.load() when you press F5 from within the game, effectively resetting the game
-- livecode.showErrorOnScreen -> When an error occurs, the error message is printed on the console by default.  You can correct the
--                          error and the file will be automatically reloaded and execution resumed on save (no need to restart the game)
--                          however, the game screen will apear plain black.  This is done on purpose, so that your state (transformations,
--                          color, current font) is untouched and will be kept when resuming.  If you want to see the error message in
--                          the game screen, set this flag to true.  Font and transformations will be restored when resuming, but other
--                          changes (e.g. current canvas, scissors) will be lost.  If you draw function restitutes them, this will not
--                          be a problem.
-- livecode.reloadKey -> which key triggers a reload
-- livecode.trackFile(filename, func, delay) -> if filename changes, exec func after delay msec (delay is optional).
--                      the purpose of delay is because programs like gimp touch the file in the filesystem at the
--                      beginning of saving it. If we reload an image at that point, the file will be "corrupted".
--                      to prevent that, "delay" is meant to give time to gimp to save the thing.

local livecode = {}
livecode.resetOnLoad = false
livecode.logReloads = true
livecode.reloadOnKeypressed = true
livecode.reloadKey = "f5"
livecode.showErrorOnScreen = true
livecode.trackAssets = true

-- io.stdout:setvbuf("line")

local errorHappened = false
local errorMsg = ""
local timestamps = { ["main.lua"] = love.filesystem.getLastModified("main.lua") }
local trackedAssets = {}
local scheduledAssets = {}
local storedFont = nil

-- override filesystem.load
local orig_loadfile = love.filesystem.load
local function new_loadfile(filename)
    timestamps[filename] = love.filesystem.exists(filename) and love.filesystem.getLastModified(filename)
    return orig_loadfile(filename)
end
love.filesystem.load = new_loadfile


-- error handling
local function storeState()
    love.graphics.push()
    love.graphics.reset()
    love.graphics.origin()
    storedFont = love.graphics.getFont()
    love.graphics.setNewFont(math.floor(14 * love.window.getPixelScale()))
end

local function recoverState()
    love.graphics.pop()
    love.graphics.setFont(storedFont)
end

local function drawError()
    local pos = 20 * love.window.getPixelScale()
    love.graphics.clear()
    love.graphics.print(errorMsg, pos, pos)
    love.graphics.present()
end

local function manageError(msg)
    errorHappened = true

    local p = (debug.traceback("Error: " .. tostring(msg), 2):gsub("\n[^\n]+$", ""))
    p = string.gsub(p, "%[string \"(.-)\"%]", "")
    p = string.gsub(p, "\n\t+%[C%]: in function 'xpcall'", "")

    if livecode.showErrorOnScreen then
        storeState()
        errorMsg = p
    end
    print(p)
end

local function disableError()
    if errorHappened and livecode.showErrorOnScreen then
        recoverState()
    end
    errorHappened = false
end

-- update function
local function update(dt)
    local ok
    local anyFileModified = false

    -- track source files
    for filename,timestamp in pairs(timestamps) do
        if love.filesystem.exists(filename) and not timestamp then
            timestamps[filename] = love.filesystem.getLastModified(filename)
            timestamp = timestamps[filename]
        end
        if timestamp and timestamp < love.filesystem.getLastModified(filename) then
            if livecode.logReloads then
                print("updated file "..filename)
            end
            disableError()
            ok, chunk = xpcall(function() return love.filesystem.load(filename) end, manageError)
            if not ok then break end

            if xpcall(chunk, manageError) then
                anyFileModified = true
            end
        end
    end

    if livecode.trackAssets then
        -- track asset files
        for filename,assetData in pairs(trackedAssets) do
            if love.filesystem.exists(filename) then
                local timestamp = love.filesystem.getLastModified(filename)
                if assetData.timestamp < timestamp then
                    assetData.timestamp = timestamp
                    if assetData.delay then
                        scheduledAssets[assetData.func] = love.timer.getTime() + assetData.delay
                    else
                        if xpcall(assetData.func, manageError) then
                            anyFileModified = true
                        end
                    end
                end
            end
        end

        -- eval scheduled assets
        for func, atime in pairs(scheduledAssets) do
            local ltime = love.timer.getTime()
            if ltime >= atime then
                scheduledAssets[func] = nil
                if xpcall(func, manageError) then
                    anyFileModified = true
                end
            end
        end
    end

    if anyFileModified then
        if livecode.resetOnLoad then
            xpcall(love.load, manageError)
        elseif love.livereload then
            xpcall(love.livereload, manageError)
        end
    end

    if not errorHappened then
        xpcall(function() love.update(dt) end, manageError)
    end
end


local function draw()
    if not errorHappened then
        xpcall(love.draw, manageError)
    elseif livecode.showErrorOnScreen then
        drawError()
    end
end


function love.run()
    math.randomseed(os.time())
    math.random() math.random()

    if love.event then
        love.event.pump()
    end

    if love.load then love.load(arg) end


    local dt = 0
    local ok

    -- Main loop time.
    while true do
        -- Process events.
        if love.event then
            love.event.pump()
            for e,a,b,c,d in love.event.poll() do
            if e == "quit" then
                if not love.quit or not love.quit() then
                    if love.audio then
                        love.audio.stop()
                    end
                return
                end
            end

            ok = xpcall(function() love.handlers[e](a,b,c,d) end, manageError)
            if livecode.reloadOnKeypressed and a == livecode.reloadKey and e == "keypressed" then
                disableError()
                xpcall(love.load, manageError)
            end
        end
    end

    -- Update dt, as we'll be passing it to update
    if love.timer then
        love.timer.step()
        dt = love.timer.getDelta()
    end

    -- Call update and draw
    if love.update then update(dt) end -- will pass 0 if love.timer is disabled

    if love.window and love.graphics then
        love.graphics.clear()
        love.graphics.origin()
        if love.draw then draw() end
        love.graphics.present()
    end

    if love.timer then love.timer.sleep(0.001) end
  end
end

function livecode.trackFile(filename, func, delay)
    if not func then
        trackedAssets[filename] = nil
        return
    end

    trackedAssets[filename] = {
        func = func,
        timestamp = love.filesystem.exists(filename) and love.filesystem.getLastModified(filename) or 0,
        delay = delay/1000
    }

end

-- placeholder empty callbacks
love.load = love.load or function() end
love.update = love.update or function(dt) end
love.draw = love.draw or function() end

return livecode
