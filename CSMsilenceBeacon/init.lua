-- silence beacons when placed in a location that leaves no space to activate.
core.register_on_receiving_chat_message(function(sMsg)
	return sMsg:sub(1, 47) == 'Not enough room to activate beacon pointing in '
end)

