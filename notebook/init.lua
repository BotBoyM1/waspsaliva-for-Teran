--[[
               __        ___.                  __
  ____   _____/  |_  ____\_ |__   ____   ____ |  | __
 /    \ /  _ \   __\/ __ \| __ \ /  _ \ /  _ \|  |/ /
|   |  (  <_> )  | \  ___/| \_\ (  <_> |  <_> )    <
|___|  /\____/|__|  \___  >___  /\____/ \____/|__|_ \
     \/                 \/    \/                   \/
--]]

local load_time_start = os.clock()
local modname = minetest.get_current_modname()


minetest.register_chatcommand("notebook", {
    params = "",
    description = "Opens a formspec.",
    func = function(param)
		if not worldstorage.get_current_worldname() then
			return false, "Missing worldname."
		end
		minetest.show_formspec("notebook", "size[5,4]"..
			"textarea[0.05,0;5.5,4;text;Write here anything, you want:;"..
			(worldstorage.get_string("notebook:notes") or "").."]"..
			"button_exit[2,3.5;1,1;save;Save]"..
			"button_exit[4.5,-0.5;0.5,1;discard;X]"
		)
		return true, "Opening notebook..."
    end,
})

minetest.register_on_formspec_input(function(formname, fields)
	if formname ~= "notebook" then
		return
	end
	if not fields.text or fields.discard then
		return true
	end
	worldstorage.set_string("notebook:notes", fields.text)
	return true
end)


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "["..modname.."] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
