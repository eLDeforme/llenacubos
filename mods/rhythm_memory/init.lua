-- Rhythm Memory mod entry point.
-- Loads modules and registers chat commands for input.

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

rhythm_memory = {
    players = {},
    game = nil,
}

rhythm_memory.sequence = dofile(modpath .. "/sequence.lua")
rhythm_memory.hud = dofile(modpath .. "/hud.lua")
rhythm_memory.logic = dofile(modpath .. "/game_logic.lua")

-- Join command used to explicitly set who will be Player 1 and Player 2.
minetest.register_chatcommand("rhythm_join", {
    params = "",
    description = "Join the rhythm memory match queue (max 2 players)",
    func = function(name)
        local ok, msg = rhythm_memory.logic.add_player(name)
        return ok, msg
    end,
})

-- Start command for manual restart in installations.
minetest.register_chatcommand("rhythm_start", {
    params = "",
    description = "Start a rhythm memory match when 2 players are present",
    privs = {server = true},
    func = function()
        local ok, msg = rhythm_memory.logic.start_match()
        return ok, msg
    end,
})

-- Input command. Arduino/HID can be mapped to send these commands quickly.
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

-- Convenience aliases.
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

-- Optional auto-enqueue first two players that join the server.
minetest.register_on_joinplayer(function(player)
    minetest.after(1, function()
        rhythm_memory.logic.try_auto_add(player:get_player_name())
    end)
end)
