-- Some settings

function init_settings(T)
	for key, value in pairs(T) do
		if minetest.settings:get(key) == nil then
			if type(value) == "boolean" then
				minetest.settings:set_bool(key, value)
			else
				minetest.settings:set(key, value)
			end
		end
	end
end

init_settings({
	autohi_message = "Hi"
})

-- Function to say the message

function check()
	if not minetest.localplayer then
		minetest.after(0, check)
		return false
	end

	return true
end

function say()
	-- Check if you are in a game
	if check() ~= true then return end

	-- Check if autohi is enabled
	if not minetest.settings:get_bool("autohi") then return end

	if type(minetest.settings:get("autohi_message")) ~= "string" or minetest.settings:get("autohi_message") == nil then return end

	local message = minetest.settings:get("autohi_message")

	minetest.send_chat_message(message)
end

-- Register section

minetest.after(0, say)

minetest.register_cheat("AutoHi", "Chat", "autohi")
