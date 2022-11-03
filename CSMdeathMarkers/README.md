[![ContentDB](https://content.minetest.net/packages/SwissalpS/deathmarkers/shields/downloads/)](https://content.minetest.net/packages/SwissalpS/deathmarkers/)
# CSM Death Markers
Minetest Client Side Mod that shows waypoints to where player has died.

The waypoints change colour and fade over time and are stored over sessions per player and server.

If the bones are punched, the waypoint is cleared. It is also cleared if the player stands in the bone position.
Useful when other player has removed bones already, they didn't spawn at all or the items were removed without punching the node.

Based on https://gitlab.com/PeterNerlich/death_markers

## Installing the CSM
Depending on your OS and build/install of Minetest the location is different. The folder you are looking for is called ``clientmods``.
  1. Inside the ``clientmods`` folder create one called something like ``deathMarkers``.
  2. Download and extract the mod files
  3. and move them into the folder you created in step 1.
  4. Turn on client side mods in your minetest settings. From the menu go to settings > all settings > client > enable_client_modding.
  5. Join or start a session and log back out. (This adds a line to mods.conf: ``load_mod_deathmarkers = false``)
  7. In ``clientmods/mods.conf`` change the line ``load_mod_deathmarkers = false`` to ``load_mod_deathmarkers = true``
  8. Join or start a session and enjoy
