-- Rhythm Memory mod entry point.
-- Loads modules, registers lightweight standalone nodes, and chat commands.

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

rhythm_memory = {
    players = {},
    game = nil,
}

-- Register minimal nodes so this game works without the external `default` mod.
minetest.register_node("rhythm_memory:container", {
    description = "Container Block",
    tiles = {"[combine:16x16:0,0=(#d9d9d966)"},
    drawtype = "glasslike",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = true,
    pointable = true,
    diggable = false,
    buildable_to = false,
    groups = {cracky = 3},
})

minetest.register_node("rhythm_memory:floor", {
    description = "Floor Block",
    tiles = {"[combine:16x16:0,0=(#6b6b6bff)"},
    is_ground_content = false,
    groups = {cracky = 3},
})

minetest.register_node("rhythm_memory:water", {
    description = "Rhythm Water Cube",
    tiles = {"[combine:16x16:0,0=(#2f8fd9cc)"},
    use_texture_alpha = "blend",
    paramtype = "light",
    sunlight_propagates = true,
    groups = {crumbly = 3},
})

-- Provide mapgen aliases expected by Luanti when running a standalone game package.
minetest.register_alias("mapgen_stone", "rhythm_memory:floor")
minetest.register_alias("mapgen_water_source", "rhythm_memory:water")
minetest.register_alias("mapgen_river_water_source", "rhythm_memory:water")

rhythm_memory.sequence = dofile(modpath .. "/sequence.lua")
rhythm_memory.hud = dofile(modpath .. "/hud.lua")
rhythm_memory.logic = dofile(modpath .. "/game_logic.lua")

minetest.register_chatcommand("rhythm_join", {
    params = "",
    description = "Join the rhythm memory queue (1 = tutorial, 2 = versus)",
    func = function(name)
        local ok, msg = rhythm_memory.logic.add_player(name)
        return ok, msg
    end,
})

minetest.register_chatcommand("rhythm_start", {
    params = "",
    description = "Start rhythm memory (works with 1 or 2 players)",
    func = function()
        local ok, msg = rhythm_memory.logic.start_match()
        return ok, msg
    end,
})

minetest.register_chatcommand("press", {
    params = "<w|y|i|p>",
    description = "Submit a rhythm step",
    func = function(name, param)
        param = (param or ""):lower():gsub("%s+", "")
        if param == "" then
            return false, "Use /press <w|y|i|p>"
        end

        local ok, msg = rhythm_memory.logic.handle_input(name, param)
        return ok, msg
    end,
})

for _, key in ipairs({"w", "y", "i", "p"}) do
    minetest.register_chatcommand(key, {
        params = "",
        description = "Alias for /press " .. key,
        func = function(name)
            local ok, msg = rhythm_memory.logic.handle_input(name, key)
            return ok, msg
        end,
    })
end

minetest.register_on_leaveplayer(function(player)
    rhythm_memory.logic.remove_player(player:get_player_name())
end)

minetest.register_on_joinplayer(function(player)
    minetest.after(1, function()
        rhythm_memory.logic.try_auto_add(player:get_player_name())
    end)
end)
