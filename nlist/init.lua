
ws = {}
ws.registered_globalhacks = {}
ws.displayed_wps={}

ws.c = core

ws.range=4
ws.target=nil
ws.targetpos=nil

local nextact = {}
local ghwason={}

local nodes_this_tick=0

function ws.s(name,value)
    if value == nil then
        return ws.c.settings:get(name)
    else
        ws.c.settings:set(name,value)
        return ws.c.settings:get(name)
    end
end
function ws.sb(name,value)
    if value == nil then
        return ws.c.settings:get_bool(name)
    else
        ws.c.settings:set_bool(name,value)
        return ws.c.settings:get_bool(name)
    end
end

function ws.dcm(msg)
    return minetest.display_chat_message(msg)
end
function ws.set_bool_bulk(settings,value)
    if type(settings) ~= 'table' then return false end
    for k,v in pairs(settings) do
        minetest.settings:set_bool(v,value)
    end
    return true
end

function ws.shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function ws.in_list(val, list)
    if type(list) ~= "table" then return false end
    for i, v in pairs(list) do
        if v == val then
            return true
        end
    end
    return false
end

function ws.random_table_element(tbl)
    local ks = {}
    for k in pairs(tbl) do
        table.insert(ks, k)
    end
    return tbl[ks[math.random(#ks)]]
end

function ws.center()
    --local lp=ws.dircoord(0,0,0)
    --minetest.localplayer:set_pos(lp)
end

function ws.globalhacktemplate(setting,func,funcstart,funcstop,daughters,delay)
    funcstart = funcstart or function() end
    funcstop = funcstop or function() end
    delay = delay or 0.5
    return function()
        if not minetest.localplayer then return end
        if minetest.settings:get_bool(setting) then
            if tps_client and tps_client.ping and tps_client.ping > 1000 then return end
            nodes_this_tick = 0
            if nextact[setting] and nextact[setting] > os.clock() then return end
            nextact[setting] = os.clock() + delay
            if not ghwason[setting] then
                if not funcstart() then
                    ws.set_bool_bulk(daughters,true)
                    ghwason[setting] = true
                    --ws.dcm(setting.. " activated")
                    ws.center()
                    minetest.settings:set('last-dir',ws.getdir())
                    minetest.settings:set('last-y',ws.dircoord(0,0,0).y)
                else minetest.settings:set_bool(setting,false)
                end
            else
                func()
            end

        elseif ghwason[setting] then
            ghwason[setting] = false
            ws.set_bool_bulk(daughters,false)
            funcstop()
            --ws.dcm(setting.. " deactivated")
        end
    end
end

function ws.register_globalhack(func)
    table.insert(ws.registered_globalhacks,func)
end

function ws.register_globalhacktemplate(name,category,setting,func,funcstart,funcstop,daughters)
    ws.register_globalhack(ws.globalhacktemplate(setting,func,funcstart,funcstop,daughters))
    minetest.register_cheat(name,category,setting)
end

ws.rg=ws.register_globalhacktemplate

function ws.step_globalhacks(dtime)
    for i, v in ipairs(ws.registered_globalhacks) do
        v(dtime)
    end
end

minetest.register_globalstep(function(dtime) ws.step_globalhacks(dtime) end)
minetest.settings:set_bool('continuous_forward',false)

function ws.on_connect(func)
	if not minetest.localplayer then minetest.after(0,function() ws.on_connect(func) end) return end
	if func then func() end
end

ws.on_connect(function()
    local ldir =minetest.settings:get('last-dir')
    if ldir then ws.setdir(ldir) end
end)


-- COORD MAGIC

function ws.is_same_pos(pos1,pos2)
    return vector.distance(vector.round(pos1),vector.round(pos2)) == 0
end
function ws.get_reachable_positions(range,under)
    under=under or false
    range=range or 4
    local rt={}
    local lp=vector.round(minetest.localplayer:get_pos())
    local ylim=range
    if under then ylim=-1 end
    for x = -range,range,1 do
        for y = -range,ylim,1 do
            for z = -range,range,1 do
                table.insert(rt,vector.round(vector.add(lp,vector.new(x,y,z))))
            end
        end
    end
    return rt
end

function ws.do_area(radius,func,plane)
    for k,v in pairs(ws.get_reachable_positions(range)) do
        if not plane or v.y == minetest.localplayer:get_pos().y -1 then
            func(v)
        end
    end
end

function ws.get_hud_by_texture(texture)
	local def
	local i = -1
	repeat
		i = i + 1
		def = minetest.localplayer:hud_get(i)
	until not def or def.text == texture
	if def then
		return def
	end
	def.number=0
	return def
end

function ws.find_player(name)
	    for k, v in ipairs(minetest.localplayer.get_nearby_objects(500)) do
			if v:get_name() == name then
				return v:get_pos(),v
			end
	    end
end

function ws.display_wp(pos,name)
    local ix = #ws.displayed_wps + 1
    ws.displayed_wps[ix] = minetest.localplayer:hud_add({
            hud_elem_type = 'waypoint',
            name          = name,
            text          = name,
            number        = 0x00ff00,
            world_pos     = pos
        })
    return ix
end

function ws.clear_wp(ix)
    table.remove(ws.displayed_wps,ix)
end

function ws.clear_wps()
    for k,v in ipairs(ws.displayed_wps) do
        minetest.localplayer:hud_remove(v)
        table.remove(ws.displayed_wps,k)
    end
end

function ws.register_chatcommand_alias(old, ...)
      local def = assert(minetest.registered_chatcommands[old])
      def.name = nil
     for i = 1, select('#', ...) do
         minetest.register_chatcommand(select(i, ...), table.copy(def))
     end
end

function ws.round2(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function ws.pos_to_string(pos)
     if type(pos) == 'table' then
         pos = minetest.pos_to_string(vector.round(pos))
     end
     if type(pos) == 'string' then
         return pos
     end
     return pos
end

function ws.string_to_pos(pos)
     if type(pos) == 'string' then
         pos = minetest.string_to_pos(pos)
     end
     if type(pos) == 'table' then
         return vector.round(pos)
     end
     return pos
end



--ITEMS
function ws.find_item_in_table(items,rnd)
    if type(items) == 'string' then
        return minetest.find_item(items)
    end
    if type(items) ~= 'table' then return end
    if rnd then items=ws.shuffle(items) end
    for i, v in pairs(items) do
        local n = minetest.find_item(v)
        if n then
            return n
        end
    end
    return false
end

function ws.find_empty(inv)
    for i, v in ipairs(inv) do
        if v:is_empty() then
            return i
        end
    end
    return false
end

function ws.find_named(inv, name)
	if not inv then return -1 end
    if not name then return end
    for i, v in ipairs(inv) do
        if v:get_name():find(name) then
            return i
        end
    end
end

function ws.itemnameformat(description)
    description = description:gsub(string.char(0x1b) .. "%(.@[^)]+%)", "")
    description = description:match("([^\n]*)")
    return description
end

function ws.find_nametagged(list, name)
    for i, v in ipairs(list) do
        if ws.itemnameformat(v:get_description()) == name then
            return i
        end
    end
end

local hotbar_slot=8
function ws.to_hotbar(it,hslot)
    local tpos=nil
    local plinv = minetest.get_inventory("current_player")
    if hslot and hslot < 10 then
        tpos=hslot
    else
        for i, v in ipairs(plinv.main) do
            if i<10 and v:is_empty() then
                tpos = i
                break
            end
        end
    end
    if tpos == nil then tpos=hotbar_slot end
	local mv = InventoryAction("move")
	mv:from("current_player", "main", it)
	mv:to("current_player", "main", tpos)
	mv:apply()
    return tpos
end

function ws.switch_to_item(itname,hslot)
    if not minetest.localplayer then return false end
    local plinv = minetest.get_inventory("current_player")
    for i, v in ipairs(plinv.main) do
        if i<10 and v:get_name() == itname then
            minetest.localplayer:set_wield_index(i)
            return true
        end
    end
    local pos = ws.find_named(plinv.main, itname)
    if pos then
        minetest.localplayer:set_wield_index(ws.to_hotbar(pos,hslot))
        return true
    end
    return false
end
function ws.in_inv(itname)
    if not minetest.localplayer then return false end
    local plinv = minetest.get_inventory("current_player")
    local pos = ws.find_named(plinv.main, itname)
    if pos then
        return true
    end
end

function core.switch_to_item(item) return ws.switch_to_item(item) end

function ws.switch_inv_or_echest(name,max_count,hslot)
	if not minetest.localplayer then return false end
    local plinv = minetest.get_inventory("current_player")
    if ws.switch_to_item(name) then return true end

    local epos = ws.find_named(plinv.enderchest, name)
    if epos then
        local tpos
        for i, v in ipairs(plinv.main) do
            if i < 9 and v:is_empty() then
                tpos = i
                break
            end
        end
        if not tpos then tpos=hotbar_slot end

        if tpos then
            local mv = InventoryAction("move")
            mv:from("current_player", "enderchest", epos)
            mv:to("current_player", "main", tpos)
            if max_count then
                mv:set_count(max_count)
            end
            mv:apply()
            minetest.localplayer:set_wield_index(tpos)
            return true
        end
    end
    return false
end

local function posround(n)
    return math.floor(n + 0.5)
end

local function fmt(c)
    return tostring(posround(c.x))..","..tostring(posround(c.y))..","..tostring(posround(c.z))
end

local function map_pos(value)
    if value.x then
        return value
    else
        return {x = value[1], y = value[2], z = value[3]}
    end
end

function ws.invparse(location)
    if type(location) == "string" then
        if string.match(location, "^[-]?[0-9]+,[-]?[0-9]+,[-]?[0-9]+$") then
            return "nodemeta:" .. location
        else
            return location
        end
    elseif type(location) == "table" then
        return "nodemeta:" .. fmt(map_pos(location))
    end
end

function ws.invpos(p)
    return "nodemeta:"..p.x..","..p.y..","..p.z
end


-- TOOLS


local function check_tool(stack, node_groups, old_best_time)
	local toolcaps = stack:get_tool_capabilities()
	if not toolcaps then return end
	local best_time = old_best_time
	for group, groupdef in pairs(toolcaps.groupcaps) do
		local level = node_groups[group]
		if level then
			local this_time = groupdef.times[level]
			if this_time and this_time < best_time then
				best_time = this_time
			end
		end
	end
	return best_time < old_best_time, best_time
end

local function find_best_tool(nodename, switch)
	local player = minetest.localplayer
	local inventory = minetest.get_inventory("current_player")
	local node_groups = minetest.get_node_def(nodename).groups
	local new_index = player:get_wield_index()
	local is_better, best_time = false, math.huge

	is_better, best_time = check_tool(player:get_wielded_item(), node_groups, best_time)
	if inventory.hand then
	    is_better, best_time = check_tool(inventory.hand[1], node_groups, best_time)
    end

	for index, stack in ipairs(inventory.main) do
		is_better, best_time = check_tool(stack, node_groups, best_time)
		if is_better then
			new_index = index
		end
	end

	return new_index,best_time
end

function ws.get_digtime(nodename)
    local idx,tm=find_best_tool(nodename)
    return tm
end

function ws.select_best_tool(pos)
    local nd=minetest.get_node_or_nil(pos)
    local nodename='air'
    if nd then nodename=nd.name end
    local t=find_best_tool(nodename)
    minetest.localplayer:set_wield_index(ws.to_hotbar(t,hotbar_slot))
	--minetest.localplayer:set_wield_index(find_best_tool(nodename))
end

--- COORDS
function ws.coord(x, y, z)
    return vector.new(x,y,z)
end
function ws.ordercoord(c)
    if c.x == nil then
        return {x = c[1], y = c[2], z = c[3]}
    else
        return c
    end
end

-- x or {x,y,z} or {x=x,y=y,z=z}
function ws.optcoord(x, y, z)
    if y and z then
        return ws.coord(x, y, z)
    else
        return ws.ordercoord(x)
    end
end
function ws.cadd(c1, c2)
    return vector.add(c1,c2)
    --return ws.coord(c1.x + c2.x, c1.y + c2.y, c1.z + c2.z)
end

function ws.relcoord(x, y, z, rpos)
    local pos = rpos or minetest.localplayer:get_pos()
    pos.y=math.ceil(pos.y)
    --math.floor(pos.y) + 0.5
    return ws.cadd(pos, ws.optcoord(x, y, z))
end

local function between(x, y, z) -- x is between y and z (inclusive)
    return y <= x and x <= z
end

function ws.getdir(yaw) --
    local rot = yaw or minetest.localplayer:get_yaw() % 360
    if between(rot, 315, 360) or between(rot, 0, 45) then
        return "north"
    elseif between(rot, 135, 225) then
        return "south"
    elseif between(rot, 225, 315) then
        return "east"
    elseif between(rot, 45, 135) then
        return "west"
    end
end

function ws.getaxis()
    local dir=ws.getdir()
    if dir == "north" or dir == "south" then return "z" end
    return "x"
end
function ws.setdir(dir) --
    if dir == "north" then
        minetest.localplayer:set_yaw(0)
    elseif dir == "south" then
        minetest.localplayer:set_yaw(180)
    elseif dir == "east" then
        minetest.localplayer:set_yaw(270)
    elseif dir == "west" then
        minetest.localplayer:set_yaw(90)
    end
end

function ws.dircoord(f, y, r ,rpos, rdir)
    local dir= ws.getdir(rdir)
    local coord = ws.optcoord(f, y, r)
    local f = coord.x
    local y = coord.y
    local r = coord.z
    local lp= rpos or minetest.localplayer:get_pos()
    if dir == "north" then
        return ws.relcoord(r, y, f,rpos)
    elseif dir == "south"  then
        return ws.relcoord(-r, y, -f,rpos)
    elseif dir == "east" then
        return ws.relcoord(f, y, -r,rpos)
    elseif dir== "west" then
        return ws.relcoord(-f, y, r,rpos)
    end
    return ws.relcoord(0, 0, 0,rpos)
end

function ws.get_dimension(pos)
    if pos.y > -65 then return "overworld"
    elseif pos.y > -8000 then return "void"
    elseif pos.y > -27000 then return "end"
    elseif pos.y > -28930 then return "void"
    elseif pos.y > -31000 then return "nether"
    else return "void"
    end
end

function ws.aim(tpos)
    local ppos=minetest.localplayer:get_pos()
    local dir=vector.direction(ppos,tpos)
    local yyaw=0;
    local pitch=0;
    if dir.x < 0 then
        yyaw = math.atan2(-dir.x, dir.z) + (math.pi * 2)
    else
        yyaw = math.atan2(-dir.x, dir.z)
    end
    yyaw = ws.round2(math.deg(yyaw),2)
    pitch = ws.round2(math.deg(math.asin(-dir.y) * 1),2);
    minetest.localplayer:set_yaw(yyaw)
    minetest.localplayer:set_pitch(pitch)
end

function ws.gaim(tpos,v,g)
    local v = v or 40
    local g = g or 9.81
    local ppos=minetest.localplayer:get_pos()
    local dir=vector.direction(ppos,tpos)
    local yyaw=0;
    local pitch=0;
    if dir.x < 0 then
        yyaw = math.atan2(-dir.x, dir.z) + (math.pi * 2)
    else
        yyaw = math.atan2(-dir.x, dir.z)
    end
    yyaw = ws.round2(math.deg(yyaw),2)
    local y = dir.y
	dir.y = 0
    local x = vector.length(dir)
    pitch=math.atan(math.pow(v, 2) / (g * x) + math.sqrt(math.pow(v, 4)/(math.pow(g, 2) * math.pow(x, 2)) - 2 * math.pow(v, 2) * y/(g * math.pow(x, 2)) - 1))
    --pitch = ws.round2(math.deg(math.asin(-dir.y) * 1),2);
    minetest.localplayer:set_yaw(yyaw)
    minetest.localplayer:set_pitch(math.deg(pitch))
end

function ws.buildable_to(pos)
    local node=minetest.get_node_or_nil(pos)
    if node then
        return minetest.get_node_def(node.name).buildable_to
    end
end

function ws.tplace(p,n,stay)
    if not p then return end
    if n then ws.switch_to_item(n) end
    local opos=ws.dircoord(0,0,0)
    local tpos=vector.add(p,vector.new(0,1,0))
    minetest.localplayer:set_pos(tpos)
    ws.place(p,{n})
    if not stay then
        minetest.after(0.1,function() 
            minetest.localplayer:set_pos(opos)
        end)
    end
end

minetest.register_chatcommand("tplace", {
    description = "tp-place",
    param = "Y",
    func = function(param)
		return ws.tplace(minetest.string_to_pos(param))
    end
})

function ws.ytp(param)
    local y=tonumber(param)
    local lp=ws.dircoord(0,0,0)
    if lp.y < y + 50 then return false,"Can't TP up." end
    if y < -30912 then return false,"Don't TP into the void lol." end
    minetest.localplayer:set_pos(vector.new(lp.x,y,lp.z))
end

local function tablearg(arg)
    local tb={}
    if type(arg) == 'string' then
        tb={arg}
    elseif type(arg) == 'table' then
        tb=arg
    elseif type(arg) == 'function' then
        tb=arg()
    end
    return tb
end

function ws.isnode(pos,arg)--arg is either an itemstring, a table of itemstrings or a function returning an itemstring
    local nodename=tablearg(arg)
    local nd=minetest.get_node_or_nil(pos)
    if nd and nodename and ws.in_list(nd.name,nodename) then
        return true
    end
end

function ws.can_place_at(pos)
    local node = minetest.get_node_or_nil(pos)
    return (node and (node.name == "air" or node.name=="mcl_core:water_source" or node.name=="mcl_core:water_flowing" or node.name=="mcl_core:lava_source" or node.name=="mcl_core:lava_flowing" or minetest.get_node_def(node.name).buildable_to))
end

-- should check if wield is placeable
-- minetest.get_node(wielded:get_name()) ~= nil should probably work
-- otherwise it equips armor and eats food
function ws.can_place_wielded_at(pos)
    local wield_empty = minetest.localplayer:get_wielded_item():is_empty()
    return not wield_empty and ws.can_place_at(pos)
end


function ws.find_any_swap(items,hslot)
    hslot=hslot or 8
    for i, v in ipairs(items) do
        local n = minetest.find_item(v)
        if n then
            ws.switch_to_item(v,hslot)
            return true
        end
    end
    return false
end


-- swaps to any of the items and places if need be
-- returns true if placed and in inventory or already there, false otherwise

local lastact=0
local lastplc=0
local lastdig=0
local actint=10
function ws.place(pos,items,hslot, place)
    --if nodes_this_tick > 8 then return end
    --nodes_this_tick = nodes_this_tick + 1
    --if not inside_constraints(pos) then return end
    if not pos then return end
    if not ws.can_place_at(pos) then return end
    items=tablearg(items)

    place = place or minetest.place_node

    local node = minetest.get_node_or_nil(pos)
    if not node then return end
    -- already there
    if ws.isnode(pos,items) then
        return true
    else
        if ws.find_any_swap(items,hslot) then
            place(pos)
            return true
        end
    end
end

function ws.place_if_able(pos)
    if not pos then return end
    if not inside_constraints(pos) then return end
    if ws.can_place_wielded_at(pos) then
        minetest.place_node(pos)
    end
end

function ws.is_diggable(pos)
    if not pos then return false end
    local nd=minetest.get_node_or_nil(pos)
    if not nd then return false end
    local n = minetest.get_node_def(nd.name)
    if n and n.diggable then return true end
    return false
end

function ws.dig(pos,condition,autotool)
    --if not inside_constraints(pos) then return end
    if autotool == nil then autotool = true end
    if condition and not condition(pos) then return false end
    if not ws.is_diggable(pos) then return end
    local nd=minetest.get_node_or_nil(pos)
    if nd and minetest.get_node_def(nd.name).diggable then
        if autotool then ws.select_best_tool(pos) end
        minetest.dig_node(pos)
    end
    return true
end

function ws.chunk_loaded()
	local ign=minetest.find_nodes_near(ws.dircoord(0,0,0),10,{'ignore'},true)
	if #ign == 0 then return true end
	return false
end

function ws.get_near(nodes,range)
    range=range or 5
    local nds=minetest.find_nodes_near(ws.dircoord(0,0,0),rang,nodes,true)
    if #nds > 0 then return nds end
    return false
end

function ws.is_laggy()
    if tps_client and tps_client.ping and tps_client.ping > 1000 then return true end
end


function ws.donodes(poss,func,condition)
    if ws.is_laggy() then return end
    local dn_i=0
    for k,v in pairs(poss) do
        if dn_i > 8 then return end
        --local nd=minetest.get_node_or_nil(v)
        if condition == nil or condition(v) then
            func(v)
            dn_i = dn_i + 1
        end
    end
end

function ws.dignodes(poss,condition)
    local func=function(p) ws.dig(p) end
    ws.donodes(poss,func,condition)
end


function ws.replace(pos,arg)
    arg=tablearg(arg)
    local nd=minetest.get_node_or_nil(pos)
    if nd and not ws.in_list(nd.name,arg) and ws.buildable_to(pos) then
        local tm=ws.get_digtime(nd.name) or 0
        ws.dig(pos)
        minetest.after(tm + 0.1,function()
            ws.place(pos,arg)
        end)
        return tm
    else
        return ws.place(pos,arg)
    end
end

function ws.playeron(p)
	local pls=minetest.get_player_names()
	for k,v in pairs(pls) do
		if v == p then return true end
	end
	return false
end


function ws.between(x, y, z) -- x is between y and z (inclusive)
    return y <= x and x <= z
end


local wall_pos1={x=-1255,y=6,z=792}
local wall_pos2={x=-1452,y=80,z=981}
local iwall_pos1={x=-1266,y=6,z=802}
local iwall_pos2={x=-1442,y=80,z=971}

function ws.in_cube(tpos,wpos1,wpos2)
    local xmax=wpos2.x
    local xmin=wpos1.x

    local ymax=wpos2.y
    local ymin=wpos1.y

    local zmax=wpos2.z
    local zmin=wpos1.z
    if wpos1.x > wpos2.x then
        xmax=wpos1.x
        xmin=wpos2.x
    end
    if wpos1.y > wpos2.y then
        ymax=wpos1.y
        ymin=wpos2.y
    end
    if wpos1.z > wpos2.z then
        zmax=wpos1.z
        zmin=wpos2.z
    end
    if ws.between(tpos.x,xmin,xmax) and ws.between(tpos.y,ymin,ymax) and ws.between(tpos.z,zmin,zmax) then
        return true
    end
    return false
end

function ws.in_wall(pos)
    if ws.in_cube(pos,wall_pos1,wall_pos2) and not in_cube(pos,iwall_pos1,iwall_pos2) then
        return true end
    return false
end

function ws.inside_wall(pos)
    local p1=iwall_pos1
    local p2=iwall_pos2
    if ws.in_cube(pos,p1,p2) then return true end
    return false
end

function ws.find_closest_reachable_airpocket(pos)
    local lp=ws.dircoord(0,0,0)
    local nds=minetest.find_nodes_near(lp,5,{'air'})
    local odst=10
    local rt=lp
    for k,v in ipairs(nds) do
        local dst=vector.distance(pos,v)
        if dst < odst then odst=dst rt=v end
    end
    if odst==10 then return false end
    return vector.add(rt,vector.new(0,-1,0))
end


-- DEBUG
local function printwieldedmeta()
    ws.dcm(dump(minetest.localplayer:get_wielded_item():get_meta():to_table()))
end
minetest.register_cheat('ItemMeta','Test',printwieldedmeta)
nlist = {}
ws.on_connect(function()
    ws.lp=minetest.localplayer
end)
local storage=minetest.get_mod_storage()
local sl="default"
local mode=1 --1:add, 2:remove
local nled_hud
local edmode_wason=false
nlist.selected=sl
nlist.dumppos={}

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
dofile(modpath .. "/forms.lua")
minetest.register_cheat('Lists','nList',function()ws.display_list_formspec("NodeLists",nlist.get_lists(),{}) end)

ws.rg('NlEdMode','nList','nlist_edmode', function()nlist.show_list(sl,true) end,function() end,function()nlist.hide() end)




minetest.register_on_punchnode(function(p, n)
    if not minetest.settings:get_bool('nlist_edmode') then return end
    if mode == 1 then
        nlist.add(sl,n.name)
    elseif mode ==2 then
        nlist.remove(sl,n.name)
    end

end)


function nlist.add(list,node)
    if node == "" then mode=1 return end
    local tb=nlist.get(list)
    local str=''
    for k,v in pairs(tb) do
        str=str..','..v
        if v == node then return end
    end
    str=str..','..node
    storage:set_string(list,str)
    ws.dcm('added '..str..' to list '..list)
end

function nlist.remove(list,node)
    if node == "" then mode=2 return end
    local tb=nlist.get(list)
    local rstr=''
    for k,v in pairs(tb) do
        if v ~= node then rstr = rstr .. ',' .. v end
    end
    storage:set_string(list, rstr)
end

function nlist.get(list)
    local arr=storage:get_string(list):split(',')
    if not arr then arr={} end
    return arr
end

function nlist.get_dumppos()
    local arr=minetest.deserialize(storage:get_string("dumppos"))
    if not arr then arr={} end
    nlist.dumppos=arr
    return arr
end
function nlist.set_dumppos(list,pos)
    nlist.dumppos=nlist.get_dumppos()
    nlist.dumppos[list]=pos
    storage:set_string('dumppos',minetest.serialize(nlist.dumppos))
end



function nlist.get_lists()
    local ret={}
    for name, _ in pairs(storage:to_table().fields) do
        table.insert(ret, name)
    end
    table.sort(ret)
    return ret
end

function nlist.rename(oldname, newname)
    oldname, newname = tostring(oldname), tostring(newname)
    local list = storage:get_string(oldname)
    if not list or not  storage:set_string(newname,list)then return end
    if oldname ~= newname then
         storage:set_string(list,'')
    end
    return true
end

function nlist.clear(list)
    storage:set_string(list,'')
end


function nlist.getd()
    return nlist.get_string(minetest.get_current_modname())
end

function nlist.show_list(list,hlp)
    if not list then return end
    local act="add"
    if mode == 2 then act="remove" end
    local txt=list .. "\n --\n" .. table.concat(nlist.get(list),"\n")
    local htxt="Nodelist edit mode\n .nla/.nlr to switch\n punch node to ".. act .. "\n.nlc to clear\n"
    if hlp then txt=htxt .. txt end
    set_nled_hud(txt)
end

function nlist.hide()
    if nled_hud then minetest.localplayer:hud_remove(nled_hud) nled_hud=nil end
end

function nlist.random(list)
    local str=storage:get(list)
    local tb=str:split(',')
    local kk = {}
    for k in pairs(tb) do
        table.insert(kk, k)
    end
    return tb[kk[math.random(#kk)]]
end


function set_nled_hud(ttext)
    if not minetest.localplayer then return end
    if type(ttext) ~= "string" then return end


    local dtext ="List: ".. ttext

    if nled_hud then
        minetest.localplayer:hud_change(nled_hud,'text',dtext)
    else
        nled_hud = minetest.localplayer:hud_add({
            hud_elem_type = 'text',
            name          = "Nodelist",
            text          = dtext,
            number        = 0x00ff00,
            direction   = 0,
            position = {x=0.8,y=0.40},
            alignment ={x=1,y=1},
            offset = {x=0, y=0}
        })
    end
    return true
end

local function todflist(list)
    --if not minetest.settings:get(list) then return end
    minetest.settings:set(list,table.concat(nlist.get(nlist.selected),","))
end

minetest.register_chatcommand('nls',{func=function(list) sl=list nlist.selected=list end})
minetest.register_chatcommand('nlshow',{func=function() nlist.show_list(sl) end})
minetest.register_chatcommand('nla',{func=function(el) nlist.add(sl,el)  end})
minetest.register_chatcommand('nlr',{func=function(el) nlist.remove(sl,el) end})
minetest.register_chatcommand('nlc',{func=function(el) nlist.clear(sl) end})

minetest.register_chatcommand('nlawi',{func=function() nlist.add(sl,minetest.localplayer:get_wielded_item():get_name())  end})
minetest.register_chatcommand('nlrwi',{func=function() nlist.remove(sl,minetest.localplayer:get_wielded_item():get_name())  end})

minetest.register_chatcommand('nltodf',{func=function(p) todflist(tostring(p)) end})


minetest.register_cheat("NlToDfXray",'nList',function()
    todflist('xray_nodes')
end)
minetest.register_cheat("NlToDfSearch",'nList',function()
    todflist('search_nodes')
end)
minetest.register_cheat("NlToDfEject",'nList',function()
    todflist('eject_nodes')
end)

function nlist.get_mtnodes()
    local arr= {
        "default:3dtorch",
        "default:acacia_bush",
        "default:acacia_bush_leaves",
        "default:acacia_bush_sapling",
        "default:acacia_bush_stem",
        "default:acacia_leaves",
        "default:acacia_log",
        "default:acacia_sapling",
        "default:acacia_tree",
        "default:acacia_wood",
        "default:apple",
        "default:apple_log",
        "default:apple_mark",
        "default:apple_tree",
        "default:aspen_leaves",
        "default:aspen_log",
        "default:aspen_sapling",
        "default:aspen_tree",
        "default:aspen_wood",
        "default:axe_",
        "default:axe_bronze",
        "default:axe_diamond",
        "default:axe_mese",
        "default:axe_steel",
        "default:axe_stone",
        "default:axe_wood",
        "default:blueberries",
        "default:blueberry_bush",
        "default:blueberry_bush_leaves",
        "default:blueberry_bush_leaves_with_berries",
        "default:blueberry_bush_sapling",
        "default:book",
        "default:bookshelf",
        "default:book_written",
        "default:brick",
        "default:bronzeblock",
        "default:bronze_ingot",
        "default:bush",
        "default:bush_leaves",
        "default:bush_sapling",
        "default:bush_stem",
        "default:cactus",
        "default:cave_ice",
        "default:chest",
        "default:chest_locked",
        "default:clay",
        "default:clay_brick",
        "default:clay_lump",
        "default:cloud",
        "default:coalblock",
        "default:coal_lump",
        "default:cobble",
        "default:cobble]",
        "default:convert_saplings_to_node_timer",
        "default:copperblock",
        "default:copper_ingot",
        "default:copper_lump",
        "default:coral_brown",
        "default:coral_cyan",
        "default:coral_green",
        "default:coral_orange",
        "default:coral_pink",
        "default:corals",
        "default:coral_skeleton",
        "default:desert_cobble",
        "default:desert_sand",
        "default:desert_sandstone",
        "default:desert_sandstone_block",
        "default:desert_sandstone_brick",
        "default:desert_stone",
        "default:desert_stone_block",
        "default:desert_stonebrick",
        "default:diamond",
        "default:diamondblock",
        "default:dirt",
        "default:dirt_with_coniferous_litter",
        "default:dirt_with_dry_grass",
        "default:dirt_with_grass",
        "default:dirt_with_grass_footsteps",
        "default:dirt_with_rainforest_litter",
        "default:dirt_with_snow",
        "default:dry_dirt",
        "default:dry_dirt_with_dry_grass",
        "default:dry_grass_",
        "default:dry_grass_1",
        "default:dry_shrub",
        "default:emergent_jungle_sapling",
        "default:emergent_jungle_tree",
        "default:fence_acacia_wood",
        "default:fence_aspen_wood",
        "default:fence_junglewood",
        "default:fence_pine_wood",
        "default:fence_rail_acacia_wood",
        "default:fence_rail_aspen_wood",
        "default:fence_rail_junglewood",
        "default:fence_rail_pine_wood",
        "default:fence_rail_wood",
        "default:fence_wood",
        "default:fern_",
        "default:fern_1",
        "default:flint",
        "default:furnace",
        "default:furnace_active",
        "default:glass",
        "default:goldblock",
        "default:gold_ingot",
        "default:gold_lump",
        "default:grass_",
        "default:grass_1",
        "default:gravel",
        "default:ice",
        "default:iron_lump",
        "default:junglegrass",
        "default:jungleleaves",
        "default:jungle_log",
        "default:junglesapling",
        "default:jungle_tree",
        "default:jungletree",
        "default:jungle_tree(swamp)",
        "default:junglewood",
        "default:kelp",
        "default:key",
        "default:ladder",
        "default:ladder_steel",
        "default:ladder_wood",
        "default:large_cactus",
        "default:large_cactus_seedling",
        "default:lava_flowing",
        "default:lava_source",
        "default:leaves",
        "default:marram_grass",
        "default:marram_grass_",
        "default:marram_grass_1",
        "default:marram_grass_2",
        "default:marram_grass_3",
        "default:mese",
        "default:mese_block",
        "default:mese_crystal",
        "default:mese_crystal_fragment",
        "default:meselamp",
        "default:mese_post_light",
        "default:mese_post_light_acacia",
        "default:mese_post_light_aspen_wood",
        "default:mese_post_light_junglewood",
        "default:mese_post_light_pine_wood",
        "default:mossycobble",
        "default:obsidian",
        "default:obsidian_block",
        "default:obsidianbrick",
        "default:obsidian_glass",
        "default:obsidian_shard",
        "default:paper",
        "default:papyrus",
        "default:papyrus_on_dirt",
        "default:papyrus_on_dry_dirt",
        "default:permafrost",
        "default:permafrost_with_moss",
        "default:permafrost_with_stones",
        "default:pick_",
        "default:pick_bronze",
        "default:pick_diamond",
        "default:pick_mese",
        "default:pick_steel",
        "default:pick_stone",
        "default:pick_wood",
        "default:pine_bush",
        "default:pine_bush_needles",
        "default:pine_bush_sapling",
        "default:pine_bush_stem",
        "default:pine_log",
        "default:pine_needles",
        "default:pine_sapling",
        "default:pine_tree",
        "default:pinetree",
        "default:pine_wood",
        "default:pinewood",
        "default:rail",
        "default:river_water_flowing",
        "default:river_water_source",
        "default:sand",
        "default:sandstone",
        "default:sandstone_block",
        "default:sandstonebrick",
        "default:sand_with_kelp",
        "default:sapling",
        "default:shovel_",
        "default:shovel_bronze",
        "default:shovel_diamond",
        "default:shovel_mese",
        "default:shovel_steel",
        "default:shovel_stone",
        "default:shovel_wood",
        "default:sign_wall",
        "default:sign_wall_",
        "default:sign_wall_steel",
        "default:sign_wall_wood",
        "default:silver_sand",
        "default:silver_sandstone",
        "default:silver_sandstone_block",
        "default:silver_sandstone_brick",
        "default:skeleton_key",
        "default:small_pine_tree",
        "default:snow",
        "default:snowblock",
        "default:steelblock",
        "default:steel_ingot",
        "default:stick",
        "default:stone",
        "default:stone_block",
        "default:stonebrick",
        "default:stone_with_coal",
        "default:stone_with_copper",
        "default:stone_with_diamond",
        "default:stone_with_gold",
        "default:stone_with_iron",
        "default:stone_with_mese",
        "default:stone_with_tin",
        "default:sword_",
        "default:sword_bronze",
        "default:sword_diamond",
        "default:sword_mese",
        "default:sword_steel",
        "default:sword_stone",
        "default:sword_wood",
        "default:tinblock",
        "default:tin_ingot",
        "default:tin_lump",
        "default:torch",
        "default:torch_ceiling",
        "default:torch_wall",
        "default:tree",
        "default:upgrade_",
        "default:water_flowing",
        "default:waterlily",
        "default:water_source",
        "default:wood"
    }
    return arr
end

function nlist.get_mclnodes()
    local arr={
    "mcl_anvils:anvil",
    'mcl_anvils:anvil',
    'mcl_anvils:anvil_damage_1',
    'mcl_anvils:anvil_damage_2',
    'mcl_anvils:update_formspec_0_60_0',
    'mcl_armor:boots_',
    'mcl_armor:boots_chain',
    'mcl_armor:boots_diamond',
    'mcl_armor:boots_gold',
    'mcl_armor:boots_iron',
    'mcl_armor:boots_leather',
    'mcl_armor:chestplate_',
    'mcl_armor:chestplate_chain',
    'mcl_armor:chestplate_diamond',
    'mcl_armor:chestplate_gold',
    'mcl_armor:chestplate_iron',
    'mcl_armor:chestplate_leather',
    'mcl_armor:helmet_',
    'mcl_armor:helmet_chain',
    'mcl_armor:helmet_diamond',
    'mcl_armor:helmet_gold',
    'mcl_armor:helmet_iron',
    'mcl_armor:helmet_leather',
    'mcl_armor:leggings_',
    'mcl_armor:leggings_chain',
    'mcl_armor:leggings_diamond',
    'mcl_armor:leggings_gold',
    'mcl_armor:leggings_iron',
    'mcl_armor:leggings_leather',
    'mcl_banners:banner_item_',
    'mcl_banners:banner_item_white',
    'mcl_banners:hanging_banner',
    'mcl_banners:respawn_entities',
    'mcl_banners:standing_banner',
    'mcl_beds:bed_',
    'mcl_beds:bed_red_bottom',
    'mcl_beds:bed_red_top',
    'mcl_beds:bed_white_bottom',
    'mcl_beds:sleeping',
    'mcl_beds:spawn',
    'mcl_biomes:chorus_plant',
    'mcl_boats:boat',
    'mcl_books:book',
    'mcl_books:bookshelf',
    'mcl_books:signing',
    'mcl_books:writable_book',
    'mcl_books:written_book',
    'mcl_bows:arrow',
    'mcl_bows:arrow_box',
    'mcl_bows:arrow_entity',
    'mcl_bows:bow',
    'mcl_bows:bow_',
    'mcl_bows:bow_0',
    'mcl_bows:bow_1',
    'mcl_bows:bow_2',
    'mcl_bows:use_bow',
    'mcl_brewing:stand',
    'mcl_brewing:stand_',
    'mcl_brewing:stand_000',
    'mcl_brewing:stand_001',
    'mcl_brewing:stand_010',
    'mcl_brewing:stand_011',
    'mcl_brewing:stand_100',
    'mcl_brewing:stand_101',
    'mcl_brewing:stand_110',
    'mcl_brewing:stand_111',
    'mcl_buckets:bucket_empty',
    'mcl_buckets:bucket_lava',
    'mcl_buckets:bucket_river_water',
    'mcl_buckets:bucket_water',
    'mcl_cake:cake',
    'mcl_cake:cake_',
    'mcl_cake:cake_1',
    'mcl_cake:cake_6',
    'mcl_cauldrons:cauldron',
    'mcl_cauldrons:cauldron_',
    'mcl_cauldrons:cauldron_1',
    'mcl_cauldrons:cauldron_1r',
    'mcl_cauldrons:cauldron_2',
    'mcl_cauldrons:cauldron_2r',
    'mcl_cauldrons:cauldron_3',
    'mcl_cauldrons:cauldron_3r',
    'mcl_chests:chest',
    'mcl_chests:ender_chest',
    'mcl_chests:reset_trapped_chests',
    'mcl_chests:trapped_chest',
    'mcl_chests:trapped_chest_',
    'mcl_chests:trapped_chest_left',
    'mcl_chests:trapped_chest_on',
    'mcl_chests:trapped_chest_on_left',
    'mcl_chests:trapped_chest_on_right',
    'mcl_chests:trapped_chest_right',
    'mcl_chests:update_ender_chest_formspecs_0_60_0',
    'mcl_chests:update_formspecs_0_51_0',
    'mcl_chests:update_shulker_box_formspecs_0_60_0',
    'mcl_chests:violet_shulker_box',
    'mcl_clock:clock',
    'mcl_clock:clock_',
    'mcl_cocoas:cocoa_1',
    'mcl_cocoas:cocoa_2',
    'mcl_cocoas:cocoa_3',
    'mcl_colorblocks:concrete_',
    'mcl_colorblocks:concrete_powder_',
    'mcl_colorblocks:glazed_terracotta_',
    'mcl_colorblocks:glazed_terracotta_black',
    'mcl_colorblocks:glazed_terracotta_blue',
    'mcl_colorblocks:glazed_terracotta_brown',
    'mcl_colorblocks:glazed_terracotta_cyan',
    'mcl_colorblocks:glazed_terracotta_green',
    'mcl_colorblocks:glazed_terracotta_grey',
    'mcl_colorblocks:glazed_terracotta_light_blue',
    'mcl_colorblocks:glazed_terracotta_lime',
    'mcl_colorblocks:glazed_terracotta_magenta',
    'mcl_colorblocks:glazed_terracotta_orange',
    'mcl_colorblocks:glazed_terracotta_pink',
    'mcl_colorblocks:glazed_terracotta_purple',
    'mcl_colorblocks:glazed_terracotta_red',
    'mcl_colorblocks:glazed_terracotta_silver',
    'mcl_colorblocks:glazed_terracotta_white',
    'mcl_colorblocks:glazed_terracotta_yellow',
    'mcl_colorblocks:hardened_clay',
    'mcl_colorblocks:hardened_clay_',
    'mcl_colorblocks:hardened_clay_orange',
    'mcl_comparators:comparator_',
    'mcl_comparators:comparator_off_',
    'mcl_comparators:comparator_off_comp',
    'mcl_comparators:comparator_off_sub',
    'mcl_comparators:comparator_on_',
    'mcl_comparators:comparator_on_comp',
    'mcl_comparators:comparator_on_sub',
    'mcl_compass:compass',
    'mcl_core:acacialeaves',
    'mcl_core:acaciasapling',
    'mcl_core:acaciatree',
    'mcl_core:acaciawood',
    'mcl_core:andesite',
    'mcl_core:andesite_smooth',
    'mcl_core:apple',
    'mcl_core:apple_gold',
    'mcl_core:axe_diamond',
    'mcl_core:axe_gold',
    'mcl_core:axe_iron',
    'mcl_core:axe_stone',
    'mcl_core:axe_wood',
    'mcl_core:barrier',
    'mcl_core:bedrock',
    'mcl_core:birchsapling',
    'mcl_core:birchtree',
    'mcl_core:birchwood',
    'mcl_core:bone_block',
    'mcl_core:bowl',
    'mcl_core:brick',
    'mcl_core:brick_block',
    'mcl_core:cactus',
    'mcl_core:charcoal_lump',
    'mcl_core:clay',
    'mcl_core:clay_lump',
    'mcl_core:coalblock',
    'mcl_core:coal_lump',
    'mcl_core:coarse_dirt',
    'mcl_core:cobble',
    'mcl_core:cobblestone',
    'mcl_core:cobweb',
    'mcl_core:darksapling',
    'mcl_core:darktree',
    'mcl_core:darkwood',
    'mcl_core:deadbush',
    'mcl_core:diamond',
    'mcl_core:diamondblock',
    'mcl_core:diorite',
    'mcl_core:diorite_smooth',
    'mcl_core:dirt',
    'mcl_core:dirt_with_dry_grass',
    'mcl_core:dirt_with_dry_grass_snow',
    'mcl_core:dirt_with_grass',
    'mcl_core:dirt_with_grass_snow',
    'mcl_core:emerald',
    'mcl_core:emeraldblock',
    'mcl_core:flint',
    'mcl_core:frosted_ice_',
    'mcl_core:frosted_ice_0',
    'mcl_core:glass',
    'mcl_core:glass_',
    'mcl_core:glass_black',
    'mcl_core:glass_blue',
    'mcl_core:glass_brown',
    'mcl_core:glass_cyan',
    'mcl_core:glass_gray',
    'mcl_core:glass_green',
    'mcl_core:glass_light_blue',
    'mcl_core:glass_lime',
    'mcl_core:glass_magenta',
    'mcl_core:glass_orange',
    'mcl_core:glass_pink',
    'mcl_core:glass_purple',
    'mcl_core:glass_red',
    'mcl_core:glass_silver',
    'mcl_core:glass_white',
    'mcl_core:glass_yellow',
    'mcl_core:goldblock',
    'mcl_core:gold_ingot',
    'mcl_core:gold_nugget',
    'mcl_core:granite',
    'mcl_core:granite_smooth',
    'mcl_core:grass_path',
    'mcl_core:gravel',
    'mcl_core:ice',
    'mcl_core:ironblock',
    'mcl_core:iron_ingot',
    'mcl_core:iron_nugget',
    'mcl_core:jungleleaves',
    'mcl_core:junglesapling',
    'mcl_core:jungletree',
    'mcl_core:junglewood',
    'mcl_core:ladder',
    'mcl_core:lapisblock',
    'mcl_core:lava_flowing',
    'mcl_core:lava_source',
    'mcl_core:leaves',
    'mcl_core:mat',
    'mcl_core:mossycobble',
    'mcl_core:mycelium',
    'mcl_core:mycelium_snow',
    'mcl_core:obsidian',
    'mcl_core:packed_ice',
    'mcl_core:paper',
    'mcl_core:pick_diamond',
    'mcl_core:pick_gold',
    'mcl_core:pick_iron',
    'mcl_core:pick_stone',
    'mcl_core:pick_wood',
    'mcl_core:podzol',
    'mcl_core:podzol_snow',
    'mcl_core:realm_barrier',
    'mcl_core:redsand',
    'mcl_core:redsandstone',
    'mcl_core:redsandstonecarved',
    'mcl_core:redsandstonesmooth',
    'mcl_core:redsandstonesmooth2',
    'mcl_core:reeds',
    'mcl_core:replace_legacy_dry_grass_0_65_0',
    'mcl_core:sand',
    'mcl_core:sandstone',
    'mcl_core:sandstonecarved',
    'mcl_core:sandstonesmooth',
    'mcl_core:sandstonesmooth2',
    'mcl_core:sapling',
    'mcl_core:shears',
    'mcl_core:shovel_diamond',
    'mcl_core:shovel_gold',
    'mcl_core:shovel_iron',
    'mcl_core:shovel_stone',
    'mcl_core:shovel_wood',
    'mcl_core:slimeblock',
    'mcl_core:snow',
    'mcl_core:snow_',
    'mcl_core:snowblock',
    'mcl_core:spruceleaves',
    'mcl_core:sprucesapling',
    'mcl_core:sprucetree',
    'mcl_core:sprucewood',
    'mcl_core:stick',
    'mcl_core:stone',
    'mcl_core:stonebrick',
    'mcl_core:stonebrickcarved',
    'mcl_core:stonebrickcracked',
    'mcl_core:stonebrickmossy',
    'mcl_core:stone_smooth',
    'mcl_core:stone_with_coal',
    'mcl_core:stone_with_diamond',
    'mcl_core:stone_with_emerald',
    'mcl_core:stone_with_gold',
    'mcl_core:stone_with_iron',
    'mcl_core:stone_with_lapis',
    'mcl_core:stone_with_redstone',
    'mcl_core:stone_with_redstone_lit',
    'mcl_core:sugar',
    'mcl_core:sword_diamond',
    'mcl_core:sword_gold',
    'mcl_core:sword_iron',
    'mcl_core:sword_stone',
    'mcl_core:sword_wood',
    'mcl_core:tallgrass',
    'mcl_core:torch',
    'mcl_core:tree',
    'mcl_core:vine',
    'mcl_core:void',
    'mcl_core:water_flowing',
    'mcl_core:water_source',
    'mcl_core:wood',
    'mcl_dispenser:dispenser_down',
    'mcl_dispenser:dispenser_up',
    'mcl_dispensers:dispenser',
    'mcl_dispensers:dispenser_down',
    'mcl_dispensers:dispenser_up',
    'mcl_dispensers:update_formspecs_0_60_0',
    'mcl_doors:acacia_door',
    'mcl_doors:birch_door',
    'mcl_doors:dark_oak_door',
    'mcl_doors:iron_door',
    'mcl_doors:iron_trapdoor',
    'mcl_doors:iron_trapdoor_open',
    'mcl_doors:jungle_door',
    'mcl_doors:register_door',
    'mcl_doors:register_trapdoor',
    'mcl_doors:spruce_door',
    'mcl_doors:trapdoor',
    'mcl_doors:trapdoor_open',
    'mcl_doors:wooden_door',
    'mcl_droppers:dropper',
    'mcl_droppers:dropper_down',
    'mcl_droppers:dropper_up',
    'mcl_droppers:update_formspecs_0_51_0',
    'mcl_droppers:update_formspecs_0_60_0',
    'mcl_dye:black',
    'mcl_dye:blue',
    'mcl_dye:brown',
    'mcl_dye:cyan',
    'mcl_dye:dark_green',
    'mcl_dye:dark_grey',
    'mcl_dye:green',
    'mcl_dye:grey',
    'mcl_dye:lightblue',
    'mcl_dye:magenta',
    'mcl_dye:orange',
    'mcl_dye:pink',
    'mcl_dye:red',
    'mcl_dye:violet',
    'mcl_dye:white',
    'mcl_dye:yellow',
    'mcl_end:chorus_flower',
    'mcl_end:chorus_flower_dead',
    'mcl_end:chorus_fruit',
    'mcl_end:chorus_fruit_popped',
    'mcl_end:chorus_plant',
    'mcl_end:dragon_egg',
    'mcl_end:end_bricks',
    'mcl_end:ender_eye',
    'mcl_end:end_rod',
    'mcl_end:end_stone',
    'mcl_end:purpur_block',
    'mcl_end:purpur_pillar',
    'mcl_farming:add_gourd',
    'mcl_farming:add_plant',
    'mcl_farming:beetroot',
    'mcl_farming:beetroot_',
    'mcl_farming:beetroot_0',
    'mcl_farming:beetroot_1',
    'mcl_farming:beetroot_2',
    'mcl_farming:beetroot_item',
    'mcl_farming:beetroot_seeds',
    'mcl_farming:beetroot_soup',
    'mcl_farming:bread',
    'mcl_farming:carrot',
    'mcl_farming:carrot_',
    'mcl_farming:carrot_1',
    'mcl_farming:carrot_2',
    'mcl_farming:carrot_3',
    'mcl_farming:carrot_4',
    'mcl_farming:carrot_5',
    'mcl_farming:carrot_6',
    'mcl_farming:carrot_7',
    'mcl_farming:carrot_item',
    'mcl_farming:carrot_item_gold',
    'mcl_farming:cookie',
    'mcl_farming:grow_plant',
    'mcl_farming:growth',
    'mcl_farming:hay_block',
    'mcl_farming:hoe_diamond',
    'mcl_farming:hoe_gold',
    'mcl_farming:hoe_iron',
    'mcl_farming:hoe_stone',
    'mcl_farming:hoe_wood',
    'mcl_farming:melon',
    'mcl_farming:melon_item',
    'mcl_farming:melon_seeds',
    'mcl_farming:melontige_',
    'mcl_farming:melontige_1',
    'mcl_farming:melontige_2',
    'mcl_farming:melontige_3',
    'mcl_farming:melontige_4',
    'mcl_farming:melontige_5',
    'mcl_farming:melontige_6',
    'mcl_farming:melontige_7',
    'mcl_farming:melontige_linked',
    'mcl_farming:melontige_unconnect',
    'mcl_farming:mushroom_brown',
    'mcl_farming:mushroom_red',
    'mcl_farming:place_seed',
    'mcl_farming:potato',
    'mcl_farming:potato_',
    'mcl_farming:potato_1',
    'mcl_farming:potato_2',
    'mcl_farming:potato_3',
    'mcl_farming:potato_4',
    'mcl_farming:potato_5',
    'mcl_farming:potato_6',
    'mcl_farming:potato_7',
    'mcl_farming:potato_item',
    'mcl_farming:potato_item_baked',
    'mcl_farming:potato_item_poison',
    'mcl_farming:pumkin_seeds',
    'mcl_farming:pumpkin',
    'mcl_farming:pumpkin_',
    'mcl_farming:pumpkin_1',
    'mcl_farming:pumpkin_2',
    'mcl_farming:pumpkin_3',
    'mcl_farming:pumpkin_4',
    'mcl_farming:pumpkin_5',
    'mcl_farming:pumpkin_6',
    'mcl_farming:pumpkin_7',
    'mcl_farming:pumpkin_face',
    'mcl_farming:pumpkin_face_light',
    'mcl_farming:pumpkin_pie',
    'mcl_farming:pumpkin_seeds',
    'mcl_farming:pumpkintige_linked',
    'mcl_farming:pumpkintige_unconnect',
    'mcl_farming:soil',
    'mcl_farming:soil_wet',
    'mcl_farming:stem_color',
    'mcl_farming:wheat',
    'mcl_farming:wheat_',
    'mcl_farming:wheat_1',
    'mcl_farming:wheat_2',
    'mcl_farming:wheat_3',
    'mcl_farming:wheat_4',
    'mcl_farming:wheat_5',
    'mcl_farming:wheat_6',
    'mcl_farming:wheat_7',
    'mcl_farming:wheat_item',
    'mcl_farming:wheat_seeds',
    'mcl_fences:dark_oak_fence',
    'mcl_fences:fence',
    'mcl_fences:nether_brick_fence',
    'mcl_fire:basic_flame',
    'mcl_fire:eternal_fire',
    'mcl_fire:fire',
    'mcl_fire:fire_charge',
    'mcl_fire:flint_and_steel',
    'mcl_fire:smoke',
    'mcl_fishing:bobber',
    'mcl_fishing:bobber_entity',
    'mcl_fishing:clownfish_raw',
    'mcl_fishing:fish_cooked',
    'mcl_fishing:fishing_rod',
    'mcl_fishing:fish_raw',
    'mcl_fishing:pufferfish_raw',
    'mcl_fishing:salmon_cooked',
    'mcl_fishing:salmon_raw',
    'mcl_flowerpots:flower_pot',
    'mcl_flowerpots:flower_pot_',
    'mcl_flowers:allium',
    'mcl_flowers:azure_bluet',
    'mcl_flowers:blue_orchid',
    'mcl_flowers:dandelion',
    'mcl_flowers:double_fern',
    'mcl_flowers:double_fern_top',
    'mcl_flowers:double_grass',
    'mcl_flowers:double_grass_top',
    'mcl_flowers:fern',
    'mcl_flowers:lilac',
    'mcl_flowers:lilac_top',
    'mcl_flowers:oxeye_daisy',
    'mcl_flowers:peony',
    'mcl_flowers:peony_top',
    'mcl_flowers:poppy',
    'mcl_flowers:rose_bush',
    'mcl_flowers:rose_bush_top',
    'mcl_flowers:sunflower',
    'mcl_flowers:sunflower_top',
    'mcl_flowers:tallgrass',
    'mcl_flowers:tulip_orange',
    'mcl_flowers:tulip_pink',
    'mcl_flowers:tulip_red',
    'mcl_flowers:tulip_white',
    'mcl_flowers:waterlily',
    'mcl_furnaces:flames',
    'mcl_furnaces:furnace',
    'mcl_furnaces:furnace_active',
    'mcl_furnaces:update_formspecs_0_60_0',
    'mcl_heads:creeper',
    'mcl_heads:skeleton',
    'mcl_heads:wither_skeleton',
    'mcl_heads:zombie',
    'mcl_hoppers:hopper',
    'mcl_hoppers:hopper_disabled',
    'mcl_hoppers:hopper_item',
    'mcl_hoppers:hopper_side',
    'mcl_hoppers:hopper_side_disabled',
    'mcl_hoppers:update_formspec_0_60_0',
    'mcl_hunger:exhaustion',
    'mcl_hunger:hunger',
    'mcl_hunger:saturation',
    'mcl_inventory:workbench',
    'mcl_itemframes:item',
    'mcl_itemframes:item_frame',
    'mcl_itemframes:respawn_entities',
    'mcl_itemframes:update_legacy_item_frames',
    'mcl_jukebox:jukebox',
    'mcl_jukebox:record_',
    'mcl_jukebox:record_1',
    'mcl_jukebox:record_2',
    'mcl_jukebox:record_3',
    'mcl_jukebox:record_4',
    'mcl_jukebox:record_5',
    'mcl_jukebox:record_6',
    'mcl_jukebox:record_7',
    'mcl_jukebox:record_8',
    'mcl_jukebox:record_9',
    'mcl_maps:empty_map',
    'mcl_maps:filled_map',
    'mcl_meshhand:hand',
    'mcl_minecarts:activator_rail',
    'mcl_minecarts:activator_rail_on',
    'mcl_minecarts:check_front_up_down',
    'mcl_minecarts:chest_minecart',
    'mcl_minecarts:command_block_minecart',
    'mcl_minecarts:detector_rail',
    'mcl_minecarts:detector_rail_on',
    'mcl_minecarts:furnace_minecart',
    'mcl_minecarts:get_rail_direction',
    'mcl_minecarts:get_sign',
    'mcl_minecarts:golden_rail',
    'mcl_minecarts:golden_rail_on',
    'mcl_minecarts:hopper_minecart',
    'mcl_minecarts:is_rail',
    'mcl_minecarts:minecart',
    'mcl_minecarts:rail',
    'mcl_minecarts:tnt_minecart',
    'mcl_minecarts:velocity_to_dir',
    'mcl_mobitems:beef',
    'mcl_mobitems:blaze_powder',
    'mcl_mobitems:blaze_rod',
    'mcl_mobitems:bone',
    'mcl_mobitems:carrot_on_a_stick',
    'mcl_mobitems:chicken',
    'mcl_mobitems:cooked_beef',
    'mcl_mobitems:cooked_chicken',
    'mcl_mobitems:cooked_mutton',
    'mcl_mobitems:cooked_porkchop',
    'mcl_mobitems:cooked_rabbit',
    'mcl_mobitems:ender_eye',
    'mcl_mobitems:feather',
    'mcl_mobitems:ghast_tear',
    'mcl_mobitems:gunpowder',
    'mcl_mobitems:leather',
    'mcl_mobitems:magma_cream',
    'mcl_mobitems:milk_bucket',
    'mcl_mobitems:mutton',
    'mcl_mobitems:nether_star',
    'mcl_mobitems:porkchop',
    'mcl_mobitems:rabbit',
    'mcl_mobitems:rabbit_foot',
    'mcl_mobitems:rabbit_hide',
    'mcl_mobitems:rabbit_stew',
    'mcl_mobitems:rotten_flesh',
    'mcl_mobitems:saddle',
    'mcl_mobitems:shulker_shell',
    'mcl_mobitems:slimeball',
    'mcl_mobitems:spider_eye',
    'mcl_mobitems:string',
    'mcl_mobs:nametag',
    'mcl_mobspawners:doll',
    'mcl_mobspawners:respawn_entities',
    'mcl_mobspawners:spawner',
    'mcl_mushrooms:brown_mushroom_block_cap_corner',
    'mcl_mushrooms:brown_mushroom_block_cap_side',
    'mcl_mushrooms:mushroom_brown',
    'mcl_mushrooms:mushroom_red',
    'mcl_mushrooms:mushroom_stew',
    'mcl_mushrooms:red_mushroom_block_cap_corner',
    'mcl_mushrooms:red_mushroom_block_cap_side',
    'mcl_mushrooms:replace_legacy_mushroom_caps',
    'mcl_nether:glowstone',
    'mcl_nether:glowstone_dust',
    'mcl_nether:magma',
    'mcl_nether:nether_brick',
    'mcl_observers:observer_down',
    'mcl_observers:observer_down_off',
    'mcl_observers:observer_down_on',
    'mcl_observers:observer_off',
    'mcl_observers:observer_on',
    'mcl_observers:observer_up',
    'mcl_observers:observer_up_off',
    'mcl_observers:observer_up_on',
    'mcl_ocean:dead_',
    'mcl_ocean:dead_brain_coral_block',
    'mcl_ocean:dried_kelp',
    'mcl_ocean:dried_kelp_block',
    'mcl_ocean:kelp',
    'mcl_ocean:kelp_',
    'mcl_ocean:kelp_dirt',
    'mcl_ocean:kelp_gravel',
    'mcl_ocean:kelp_redsand',
    'mcl_ocean:kelp_sand',
    'mcl_ocean:prismarine',
    'mcl_ocean:prismarine_brick',
    'mcl_ocean:prismarine_crystals',
    'mcl_ocean:prismarine_dark',
    'mcl_ocean:prismarine_shard',
    'mcl_ocean:seagrass',
    'mcl_ocean:seagrass_',
    'mcl_ocean:seagrass_dirt',
    'mcl_ocean:seagrass_gravel',
    'mcl_ocean:seagrass_redsand',
    'mcl_ocean:seagrass_sand',
    'mcl_ocean:sea_lantern',
    'mcl_ocean:sea_pickle_',
    'mcl_ocean:sea_pickle_1_',
    'mcl_ocean:sea_pickle_1_dead_brain_coral_block',
    'mcl_ocean:sea_pickle_1_off_',
    'mcl_ocean:sea_pickle_1_off_dead_brain_coral_block',
    'mcl_paintings:painting',
    'mcl_playerplus:surface',
    'mcl_player:preview',
    'mcl_portals:end_portal_frame',
    'mcl_portals:end_portal_frame_eye',
    'mcl_portals:portal',
    'mcl_portals:portal_end',
    'mcl_potions:awkward',
    'mcl_potions:dragon_breath',
    'mcl_potions:fermented_spider_eye',
    'mcl_potions:fire_resistance',
    'mcl_potions:glass_bottle',
    'mcl_potions:harming',
    'mcl_potions:harming_2',
    'mcl_potions:harming_2_splash',
    'mcl_potions:harming_splash',
    'mcl_potions:healing',
    'mcl_potions:healing_2',
    'mcl_potions:healing_2_splash',
    'mcl_potions:healing_splash',
    'mcl_potions:invisibility',
    'mcl_potions:invisibility_plus',
    'mcl_potions:invisibility_plus_splash',
    'mcl_potions:invisibility_splash',
    'mcl_potions:leaping',
    'mcl_potions:leaping_plus',
    'mcl_potions:leaping_plus_splash',
    'mcl_potions:leaping_splash',
    'mcl_potions:mundane',
    'mcl_potions:night_vision',
    'mcl_potions:night_vision_arrow',
    'mcl_potions:night_vision_lingering',
    'mcl_potions:night_vision_plus',
    'mcl_potions:night_vision_plus_arrow',
    'mcl_potions:night_vision_plus_lingering',
    'mcl_potions:night_vision_plus_splash',
    'mcl_potions:night_vision_splash',
    'mcl_potions:poison',
    'mcl_potions:poison_2',
    'mcl_potions:poison_2_splash',
    'mcl_potions:poison_splash',
    'mcl_potions:regeneration',
    'mcl_potions:river_water',
    'mcl_potions:slowness',
    'mcl_potions:slowness_plus',
    'mcl_potions:slowness_plus_splash',
    'mcl_potions:slowness_splash',
    'mcl_potions:speckled_melon',
    'mcl_potions:strength',
    'mcl_potions:strength_2',
    'mcl_potions:strength_2_lingering',
    'mcl_potions:strength_2_splash',
    'mcl_potions:strength_lingering',
    'mcl_potions:strength_plus',
    'mcl_potions:strength_plus_lingering',
    'mcl_potions:strength_plus_splash',
    'mcl_potions:strength_splash',
    'mcl_potions:swiftness',
    'mcl_potions:swiftness_plus',
    'mcl_potions:swiftness_plus_splash',
    'mcl_potions:swiftness_splash',
    'mcl_potions:thick',
    'mcl_potions:water',
    'mcl_potions:water_breathing',
    'mcl_potions:water_splash',
    'mcl_potions:weakness',
    'mcl_potions:weakness_lingering',
    'mcl_potions:weakness_plus',
    'mcl_potions:weakness_plus_lingering',
    'mcl_potions:weakness_plus_splash',
    'mcl_potions:weakness_splash',
    'mcl_signs:respawn_entities',
    'mcl_signs:set_text_',
    'mcl_signs:standing_sign',
    'mcl_signs:standing_sign22_5',
    'mcl_signs:standing_sign45',
    'mcl_signs:standing_sign67_5',
    'mcl_signs:text',
    'mcl_signs:wall_sign',
    'mcl_skins:skin_id',
    'mcl_skins:skin_select',
    'mcl_sponges:sponge',
    'mcl_sponges:sponge_wet',
    'mcl_sponges:sponge_wet_river_water',
    'mcl_sprint:sprint',
    'mcl_stairs:slab_',
    'mcl_stairs:slab_concrete_',
    'mcl_stairs:slab_purpur_block',
    'mcl_stairs:slab_quartzblock',
    'mcl_stairs:slab_redsandstone',
    'mcl_stairs:slab_sandstone',
    'mcl_stairs:slab_stone',
    'mcl_stairs:slab_stonebrick',
    'mcl_stairs:slab_stone_double',
    'mcl_stairs:slab_wood',
    'mcl_stairs:stair_',
    'mcl_stairs:stair_cobble',
    'mcl_stairs:stair_concrete_',
    'mcl_stairs:stair_sandstone',
    'mcl_stairs:stair_stonebrick',
    'mcl_stairs:stair_stonebrickcracked',
    'mcl_stairs:stair_stonebrickcracked_inner',
    'mcl_stairs:stair_stonebrickcracked_outer',
    'mcl_stairs:stair_stonebrick_inner',
    'mcl_stairs:stair_stonebrickmossy',
    'mcl_stairs:stair_stonebrickmossy_inner',
    'mcl_stairs:stair_stonebrickmossy_outer',
    'mcl_stairs:stair_stonebrick_outer',
    'mcl_stairs:stairs_wood',
    'mcl_supplemental:nether_brick_fence_gate',
    'mcl_supplemental:nether_brick_fence_gate_open',
    'mcl_supplemental:red_nether_brick_fence',
    'mcl_supplemental:red_nether_brick_fence_gate',
    'mcl_supplemental:red_nether_brick_fence_gate_open',
    'mcl_throwing:arrow',
    'mcl_throwing:bow',
    'mcl_throwing:egg',
    'mcl_throwing:egg_entity',
    'mcl_throwing:ender_pearl',
    'mcl_throwing:ender_pearl_entity',
    'mcl_throwing:flying_bobber',
    'mcl_throwing:flying_bobber_entity',
    'mcl_throwing:snowball',
    'mcl_throwing:snowball_entity',
    'mcl_tnt:tnt',
    'mcl_tools:axe_diamond',
    'mcl_tools:axe_gold',
    'mcl_tools:axe_iron',
    'mcl_tools:axe_stone',
    'mcl_tools:axe_wood',
    'mcl_tools:pick_diamond',
    'mcl_tools:pick_gold',
    'mcl_tools:pick_iron',
    'mcl_tools:pick_stone',
    'mcl_tools:pick_wood',
    'mcl_tools:shears',
    'mcl_tools:shovel_diamond',
    'mcl_tools:shovel_gold',
    'mcl_tools:shovel_iron',
    'mcl_tools:shovel_stone',
    'mcl_tools:shovel_wood',
    'mcl_tools:sword_diamond',
    'mcl_tools:sword_gold',
    'mcl_tools:sword_iron',
    'mcl_tools:sword_stone',
    'mcl_tools:sword_wood',
    'mcl_torches:flames',
    'mcl_torches:torch',
    'mcl_torches:torch_wall',
    'mcl_walls:andesite',
    'mcl_walls:brick',
    'mcl_walls:cobble',
    'mcl_walls:diorite',
    'mcl_walls:endbricks',
    'mcl_walls:granite',
    'mcl_walls:mossycobble',
    'mcl_walls:netherbrick',
    'mcl_walls:prismarine',
    'mcl_walls:rednetherbrick',
    'mcl_walls:redsandstone',
    'mcl_walls:sandstone',
    'mcl_walls:stonebrick',
    'mcl_walls:stonebrickmossy',
    'mcl_wool:black',
    'mcl_wool:black_carpet',
    'mcl_wool:blue',
    'mcl_wool:blue_carpet',
    'mcl_wool:brown',
    'mcl_wool:brown_carpet',
    'mcl_wool:cyan',
    'mcl_wool:cyan_carpet',
    'mcl_wool:dark_blue',
    'mcl_wool:gold',
    'mcl_wool:green',
    'mcl_wool:green_carpet',
    'mcl_wool:grey',
    'mcl_wool:grey_carpet',
    'mcl_wool:light_blue',
    'mcl_wool:light_blue_carpet',
    'mcl_wool:lime',
    'mcl_wool:lime_carpet',
    'mcl_wool:magenta',
    'mcl_wool:magenta_carpet',
    'mcl_wool:orange',
    'mcl_wool:orange_carpet',
    'mcl_wool:pink',
    'mcl_wool:pink_carpet',
    'mcl_wool:purple',
    'mcl_wool:purple_carpet',
    'mcl_wool:red',
    'mcl_wool:red_carpet',
    'mcl_wool:silver',
    'mcl_wool:silver_carpet',
    'mcl_wool:white',
    'mcl_wool:white_carpet',
    'mcl_wool:yellow',
    'mcl_wool:yellow_carpet'
    }
    return arr
end
