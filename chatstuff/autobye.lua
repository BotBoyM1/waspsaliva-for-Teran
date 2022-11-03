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
	autobye_message = "I gotta go, have fun!"
})

-- Function to say the message

function disconnect()
	minetest.disconnect()
end

function bye()
	if type(minetest.settings:get("autobye_message")) ~= "string" or minetest.settings:get("autobye_message") == nil then return end

	local message = minetest.settings:get("autobye_message")

	minetest.send_chat_message(message)
	disconnect()
end

-- Register section

minetest.register_chatcommand("bye", {
	description = "Send's the configured autobye message and exits to mainmenu",

	func = function()
		bye()
	end
})
