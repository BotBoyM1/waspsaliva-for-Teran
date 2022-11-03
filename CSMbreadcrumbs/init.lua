-- minetest CSM breadcrumbs --
-- by SwissalpS --
-- Leaves a trail of fading waypoints at intervals.
-- Adds command .bread to configure during gameplay
bc = {
	version = 20211206.1721,
	colour = 0xefef00,
	interval = 30, -- how often to place a new waypoint
	duration = 300, -- how long before waypoints fade
	formName = '__breadcrumbs__',
	store = assert(core.get_mod_storage()),
	bMain = true,
	tCache = {},
	lastid = -1,
}


function bc.clearAll()

	for _, id in pairs(bc.tCache) do
		core.localplayer:hud_remove(id)
	end

	bc.tCache = {}

end -- clearAll


function bc.formInput(sFormName, tFields)

	if bc.formName ~= sFormName then return false end

	local interval = tonumber(tFields.interval)
	local duration = tonumber(tFields.duration)
	local colour = tonumber(tFields.colour)
	if nil == colour and tFields.colour then
		colour = tonumber('0x' .. tFields.colour)
	end

	if tFields.bMain then bc.bMain = 'true' == tFields.bMain end
	if interval and 0 < interval then bc.interval = interval end
	if duration and 0 < duration then bc.duration = duration end
	if colour and -1 < colour then bc.colour = colour end

	if tFields.clear then bc.clearAll() end

	return true

end -- formInput


function bc.formShow()

	local sOut = 'size[5,5]'
		.. 'button[1,0;2,1;clear;Clear All]'
		.. 'checkbox[1,1;bMain;Active;'
		.. (bc.bMain and 'true' or 'false') .. ']'
		.. 'field[interval;Interval;' .. tostring(bc.interval) .. ']'
		.. 'field[duration;Duration;' .. tostring(bc.duration) .. ']'
		.. 'field[colour;Colour;0x' .. string.format('%x', bc.colour) .. ']'
		--[[
		.. 'field_close_on_enter[interval;false]'
		.. 'field_close_on_enter[duration;false]'
		.. 'field_close_on_enter[colour;false]'
		--]]

	core.show_formspec(bc.formName, sOut)

end -- formShow


function bc.init()

	-- read settings
	local colour = bc.store:get_int('colour')
	if 0 < colour then bc.colour = colour end

	local interval = bc.store:get_int('interval')
	if 0 < interval then bc.interval = interval end

	local duration = bc.store:get_int('duration')
	if 0 < duration then bc.duration = duration end

	local sMain = bc.store:get_string('bMain')
	bc.bMain = '' == sMain

	-- start loop
	core.after(5, bc.update)

end -- init


function bc.pos2string(tPos)

	return tostring(math.floor(tPos.x)) .. ' | '
			.. tostring(math.floor(tPos.y)) .. ' | '
			.. tostring(math.floor(tPos.z))

end -- pos2string


function bc.remove(id, sPos)

	core.localplayer:hud_remove(id)
	bc.tCache[sPos] = nil

end -- remove


function bc.shutdown()

	-- save settings
	bc.store:set_int('colour', bc.colour)
	bc.store:set_int('interval', bc.interval)
	bc.store:set_int('duration', bc.duration)
	bc.store:set_string('bMain', bc.bMain and '' or '-')

end -- shutdown


function bc.update()

	-- call again
	core.after(bc.interval, bc.update)

	if not bc.bMain then return end

	local oP = core.localplayer
	if not oP then return end

	local tPos = oP:get_pos()
	local sPos = bc.pos2string(tPos)

	if bc.tCache[sPos] then return end

	local id = oP:hud_add({
		hud_elem_type = 'waypoint',
		name = sPos,
		text = 'm',
		precision = 5,
		number = bc.colour,
		world_pos = tPos,
		offset = { x = 0, y = 0},
		alignment = {x = 1, y = -1},
	})
	bc.tCache[sPos] = id

	-- have waypoint fade
	core.after(bc.duration, bc.remove, id, sPos)

end -- update


-- hook in to core shutdown callback
core.register_on_shutdown(bc.shutdown)
-- hook in to formspec signals
core.register_on_formspec_input(bc.formInput)
-- register chat command
core.register_chatcommand('bread', {
	description = 'Invokes formspec to change settings .',
	func = bc.formShow,
	params = '<none>',
})

-- start delayed
core.after(5, bc.init)

--print('[CSM, Too Much Info, Loaded]')
print('[bread-crumbs Loaded]')

