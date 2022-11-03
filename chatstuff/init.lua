-- Get the modpath of current csm

local modpath = minetest.get_modpath("chatstuff")

-- Execute the files

dofile(modpath .. "autobye.lua")
dofile(modpath .. "autohi.lua")
