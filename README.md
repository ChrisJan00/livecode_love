livecode_love
=============
by Christiaan Janssen


Simple livecoding environment for Löve2D based on LICK.

Overwrites love.run, pressing all errors to the terminal/console


Usage:
------

	require "livecode" 

at the beginning on main.lua.  No further changes needed


When you load extra files via _love.filesystem.load(..)_, they will be tracked by the system.

Each time you save one of these files it will be reloaded automatically and the changes applied.

Additionally, the new callback _love.livereload_ will be called if it exists. 


Control flags:
--------------
 - **livecode.resetOnLoad**  :  if set to "true", _love.load()_ will be called when reloading files (instead of love.livereload)
 - **livecode.logReloads**  :  if set to "true", the message "updated file _FILENAME_" will be printed on the console output each time _FILENAME_ is reloaded
 - **livecode.reloadOnF5**  :  if set to "true", calls _love.load()_ when you press F5 from within the game, effectively resetting the game 
 - **livecode.showErrorOnScreen**  :  When an error occurs, the error message is printed on the console by default.  You can correct the error and the file will be automatically reloaded and execution resumed on save (no need to restart the game). However, the game screen will apear plain black.  This is done on purpose, so that your state (transformations, color, current font) is untouched and will be kept when resuming.  If you want to see the error message in the game screen, set this flag to "true".  Font and transformations will be restored when resuming, but other changes (e.g. current canvas, scissors) will be lost.  If you draw function restitutes them, this will not be a problem.

For changing the flags, the easiest way is to include this library by

	livecode = require "livecode"

Then, for example

	livecode.reloadOnF5 = false


Known limitations
-----------------

If you have errors on initialization of the game, the library might not be able to capture them.  You can recognize the situation because the error screen will be the default blue from Löve2D.  In that case, you need to close the game and relaunch it when you fix the errors.

---
Only files loaded with _love.filesystem.load_ are tracked.  If you use _require_, those files will not be reloaded when changed.  That is a feature of the _require_ function in Lua: once a file is loaded is not loaded again.

---
If you define local variables in your file, outside of functions, reloading the file will overwrite them.  In this case you can use the "or" idiom to keep the current values.

	local exampleList = {}

becomes

	local exampleList = exampleList or {}

In this case "exampleList" will be an empty list the first time the code is run, and will keep its value on successive runs of the same code.

---
Depending on your coding style, the changes in your code might not be applied.  For example consider the following code:

	local EntityList = EntityList or {}

	function love.load()
		table.insert(EntityList, { x = 0 })
	end

	function updateEntity(entity, dt)
		print(entity.x)
	end

	function love.update(dt)
		for i,entity in ipairs(EntityList) do
			updateEntity(entity, dt)
		end
	end

In this example, changes in the body of _updateEntity_ will be applied on reload, since this is a global function.  Reloading the file will overwrite this function.  This is the desired behaviour.  The new version of the function will then be the one called from within _love.update_.

But if the example had different code in _love.load_ and _love.update_:

	function love.load()
		table.insert(EntityList, { x = 0, update = updateEntity })
	end

	function love.update(dt)
		for i,entity in ipairs(EntityList) do
			entity:update(dt)
		end
	end

In this case, reloading the file after making changes in _updateEntity_ overwrites it, but the entity itself is still using the old code, since the assignment is made in the uncalled _love.load_.  Reloading the file will not show the changes in _updateEntity_.
The _love.livereload_ callback is provided for covering this case. In the discussed example one possible implementation would be:

	function love.livereload()
		for i,entity in ipairs(EntityList) do
			entity.update = updateEntity
		end
	end

This points the entity's _update_ function to the new version of _updateEntity_.

-- Christiaan Janssen, July 2014
