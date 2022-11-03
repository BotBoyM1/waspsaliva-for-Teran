local function get_bobber_pos()
    local obs=minetest.get_objects_inside_radius(minetest.localplayer:get_pos(),10)
    for k,v in ipairs(obs) do
        local txt=v:get_item_textures()
        if txt:find("bobber") then
            return v:get_pos()
        end
    end
    return false
end

local fb_state=0
local fb_obpos=vector.new()

minetest.register_globalstep(function()
    if not minetest.settings:get_bool("fishbot") then return end
    if not minetest.localplayer then return end
    if not minetest.switch_to_item('mcl_fishing:fishing_rod_enchanted') then
        minetest.switch_to_item('mcl_fishing:fishing_rod')
    end
    local bpos=get_bobber_pos()
    if not bpos then fb_state=0 end
    if fb_state == 0 then --init
        minetest.interact("activate",{type="nothing"})
        fb_state=1
    elseif fb_state == 1 then --waiting for bobber to settle
        if vector.distance(bpos,fb_obpos) == 0 then
            fb_state=2
        end
    elseif fb_state == 2 then --waiting for bobber to move
        if vector.distance(bpos,fb_obpos) > 0 then
            minetest.after('0.1',function()
                minetest.interact("activate",{type="nothing"})
            end)
            fb_state=3
        end
    elseif fb_state == 3 then --waiting til bobber is gone
        if not bpos then fb_state=0 end
    else
        fb_state=0
    end
    if bpos then fb_obpos=bpos end
end)

minetest.register_cheat('FishBot','Bots','fishbot')
