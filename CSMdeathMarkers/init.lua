-- minetest CSM deathMarkers --
-- 2021 by Luke aka SwissalpS --
-- based on https://gitlab.com/PeterNerlich/death_markers --
local UPDATE_INTERVAL = 3
local WAYPOINT_SATURATION = 1
local WAYPOINT_EXPIRES_SECONDS = 42 * 60

local iDeaths = 0
local tDeaths = {}
local sStoreID = ''
local tColourCache = {}
local bSkipClearOnVisit = false
local oStore = core.get_mod_storage()


-- by PeterNerlich
local function interpolate(a, b, t) return t * (b - a) + a end


-- by PeterNerlich
local function currentColour(fT)

	-- clamp t between 0 and 1, in steps of 0.01
	local iT = math.max(0, math.min(1, math.floor(fT * 100 + 0.5) / 100))

	if nil == tColourCache[iT] then
		-- helper variables
		local iT2 = iT^2	-- t squared
		local iInvT = 1 - iT	-- inverse t
		local iInvT2 = iInvT^2	-- inverse t squared

		local iRed = iT2
		local iGreen = 2 * iT * iInvT
		local iBlue = iInvT2
		local iAverage = math.sqrt(iRed^2 + iGreen^2 + iBlue^2)

		iRed   = interpolate(iAverage, iRed, WAYPOINT_SATURATION)
		iGreen = interpolate(iAverage, iGreen, WAYPOINT_SATURATION)
		iBlue  = interpolate(iAverage, iBlue, WAYPOINT_SATURATION)

		local iWhiteStart = iInvT2^2
		local iDimming = 1 - iT^8

		iRed   = (iRed   * (1 - iWhiteStart) + iWhiteStart) * iDimming
		iGreen = (iGreen * (1 - iWhiteStart) + iWhiteStart) * iDimming
		iBlue  = (iBlue  * (1 - iWhiteStart) + iWhiteStart) * iDimming

		-- we have 255 steps per subpixel
		local iBase = 0xFF

		-- clamp values, discard fractions
		iRed   = math.floor(iBase * math.max(0, math.min(1, iRed)))
		iGreen = math.floor(iBase * math.max(0, math.min(1, iGreen)))
		iBlue  = math.floor(iBase * math.max(0, math.min(1, iBlue)))

		-- pack it into one number representing the RGB values
		tColourCache[iT] = iRed * 2^16 + iGreen * 2^8 + iBlue
	end

	return tColourCache[iT]

end -- currentColour


local function pos2string(tPos)

	return tostring(math.floor(tPos.x)) .. ' | '
			.. tostring(math.floor(tPos.y)) .. ' | '
			.. tostring(math.floor(tPos.z))

end -- pos2string


local function clearAll()

	local oPlayer = core.localplayer

	for sPos, tMarker in pairs(tDeaths) do

		oPlayer:hud_remove(tMarker.id)
		tDeaths[sPos] = nil

	end -- loop waypoints

end -- clearAll


local function onFormInput(sFormName, _)

	if 'bultin:death' ~= sFormName then return end

	bSkipClearOnVisit = false

end -- onFormInput


local function makeWaypoint(oPlayer, sPos, tPos)

	return oPlayer:hud_add({
		hud_elem_type = 'waypoint',
		name = 'Bone #' .. tostring(iDeaths) .. ' ' .. sPos,
		text = 'm',
		precision = 3,
		number = 0xFF0000,
		world_pos = tPos,
		offset = { x = 0, y = 0},
		alignment = {x = 1, y = -1},
	})

end -- makeWaypoint


local function onSave()

	-- save shutdown time
	oStore:set_int(sStoreID .. 'shutdown', os.time())
	-- save death-count
	oStore:set_int(sStoreID .. 'deathCount', iDeaths)
	-- save table of waypoints
	oStore:set_string(sStoreID .. 'deaths', core.serialize(tDeaths))

	--print('[deathMarkers saved marker DB]')

end -- onSave


local function onDeath()

	iDeaths = iDeaths + 1
	local oPlayer = core.localplayer

	-- get player's position
	local tPos = oPlayer:get_pos()
	-- adjust position
	tPos.x = math.floor(tPos.x + 0.5)
	tPos.y = math.floor(tPos.y + 0.5)
	tPos.z = math.floor(tPos.z + 0.5)
	local sPos = pos2string(tPos)

	-- make waypoint and add to table
	tDeaths[sPos] = {
		pos = tPos,
		ts = os.time(),
		id = makeWaypoint(oPlayer, sPos, tPos),
	}

	-- mark player as dead
	bSkipClearOnVisit = true

	onSave()

end -- onDeath


local function onPunch(tPos, tNode)

	if 'bones:bones' ~= tNode.name then return false end

	local sPos = pos2string(tPos)

	if tDeaths[sPos] then

		-- player punched bones -> clear the waypoint
		core.localplayer:hud_remove(tDeaths[sPos].id)
		tDeaths[sPos] = nil

		-- and save (in case our game crashes)
		onSave()

	end

	return false

end -- onPunch


local function onUpdate()

	core.after(UPDATE_INTERVAL, onUpdate)

	local oPlayer = core.localplayer

	local iNow = os.time()
	for sPos, tMarker in pairs(tDeaths) do

		local fT = (iNow - tMarker.ts) / WAYPOINT_EXPIRES_SECONDS
		if 1 < fT then

			-- waypoint has expired -> remove it
			oPlayer:hud_remove(tMarker.id)
			tDeaths[sPos] = nil

		else

			-- adjust colour
			oPlayer:hud_change(tMarker.id, 'number', currentColour(fT))

		end

	end -- loop waypoints

	-- check if player has visited bones and clear marker
	-- skip clearing marker as player may still be dead at bones
	if bSkipClearOnVisit then return end

	local tPos = oPlayer:get_pos()
	local sPos = pos2string(tPos)

	if tDeaths[sPos] then

		-- player is at bones -> clear the waypoint
		oPlayer:hud_remove(tDeaths[sPos].id)
		tDeaths[sPos] = nil

	end

end -- onUpdate


local function onInit()

	local oPlayer = core.localplayer
	if not oPlayer then
		-- onInit was called to early, try again later
		core.after(1, onInit)
		return
	end

	local oSI = core.get_server_info()
	sStoreID = oPlayer:get_name()
	-- in singleplayer mode the port changes
	if 'singleplayer' ~= sStoreID then
		sStoreID = sStoreID .. '-' .. oSI.ip .. ':' .. oSI.port
	end

	-- read death-count
	iDeaths = oStore:get_int(sStoreID .. 'deathCount')
	-- get table of saved markers
	tDeaths = core.deserialize(oStore:get_string(sStoreID .. 'deaths')) or {}
	-- how long between sessions
	local iDiff = os.time() - oStore:get_int(sStoreID .. 'shutdown')

	for sPos, tMarker in pairs(tDeaths) do

		-- add inactive time passed between sessions to each marker
		tMarker.ts = tMarker.ts + iDiff
		-- re-create the waypoint
		tMarker.id = makeWaypoint(oPlayer, sPos, tMarker.pos)

	end -- loop waypoints

	core.after(UPDATE_INTERVAL, onUpdate)

	print('[deathMarkers initialized]')

end -- onInit


-- hook in to core shutdown callback to save markers and shutdown time
core.register_on_shutdown(onSave)
-- hook in to formspec signals to catch when 'you died' formspec is closed
core.register_on_formspec_input(onFormInput)
-- hook in to death event
core.register_on_death(onDeath)
-- hook in to check if our bone is being dug
core.register_on_punchnode(onPunch)
-- add chatcommand to clear all waypoints
core.register_chatcommand('cadw', {
	description = 'Clears all death waypoints.',
	func = clearAll,
	params = '<none>',
})

-- init delayed so core.localplayer exists
core.after(1, onInit)
