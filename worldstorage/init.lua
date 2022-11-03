
worldstorage = {}

local modstorage = core.get_mod_storage()

local activate_functions = {}
function worldstorage.register_on_activate(f)
	activate_functions[#activate_functions+1] = f
end

local worldname
function worldstorage.get_current_worldname()
	return worldname
end
local function set_worldname(name)
	local first_time = worldname == nil
	worldname = name
	for i = 1, #activate_functions do
		activate_functions[i](first_time)
	end
	return "Worldname set to "..name.."."
end

--minetest.register_on_connect(function()
minetest.show_formspec("worldstorage_worldname",
		"field[worldname;Enter the current worldname:;]")
--end)

minetest.register_on_formspec_input(function(formname, fields)
	if formname ~= "worldstorage_worldname" then
		return
	end
	if not fields.worldname then
		minetest.display_chat_message("You can still set the worldname with "..
				"the chatcommand.")
		return true
	end
	local msg = set_worldname(fields.worldname)
	minetest.display_chat_message(msg)
	return true
end)

minetest.register_chatcommand("worldname", {
    params = "set <name> / get",
    description = "",
    func = function(param)
		if param == "get" then
			if not worldname then
				return false, "No worldname set."
			end
			return true, worldname
		elseif param:sub(1, 4) == "set " then
			param = param:sub(5)
		end
		return true, set_worldname(param)
    end,
})

worldstorage.register_on_activate(function(first_time)
	if not first_time then
		return
	end

	local prefix = worldname.."/"

	function worldstorage.get_int(key)
		return modstorage:get_int(prefix..key)
	end

	function worldstorage.set_int(key, value)
		modstorage:set_int(prefix..key, value)
	end

	function worldstorage.get_float(key)
		return modstorage:get_float(prefix..key)
	end

	function worldstorage.set_float(key, value)
		modstorage:set_float(prefix..key, value)
	end

	function worldstorage.get_string(key)
		return modstorage:get_string(prefix..key)
	end

	function worldstorage.set_string(key, value)
		modstorage:set_string(prefix..key, value)
	end

	function worldstorage.to_table()
		local t = modstorage:to_table()
		for k,_ in pairs(t) do
			if k:sub(1, #prefix) ~= prefix then
				t[k] = nil
			end
		end
		return t
	end

	function worldstorage.from_table(values)
		local t = modstorage:to_table()
		for k, v in pairs(values) do
			t[prefix..k] = v
		end
		modstorage:from_table(t)
	end
end)
