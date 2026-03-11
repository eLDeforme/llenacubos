-- Core game state machine.
-- Handles turns, input validation, scoring, and world visualization.

local M = {}

local MAX_BASE_TURNS = 15
local MAX_TOTAL_TURNS = 25
local INPUT_TIMEOUT = 8

local container_origin = {x = 0, y = 1, z = 0}
local container_inner_size = {x = 3, y = 5, z = 1} -- 15 cells exactly.

local function pos_add(a, b)
    return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

local function get_player(name)
    return minetest.get_player_by_name(name)
end

local function setup_container()
    local origin = container_origin
    local sx, sy, sz = container_inner_size.x, container_inner_size.y, container_inner_size.z

    -- Build a simple glass container with stone floor.
    for y = 0, sy + 1 do
        for x = -1, sx do
            for z = -1, sz do
                local p = pos_add(origin, {x = x, y = y, z = z})
                local is_wall = (x == -1 or x == sx or z == -1 or z == sz or y == 0 or y == sy + 1)
                if y == 0 then
                    minetest.set_node(p, {name = "default:stone"})
                elseif is_wall then
                    minetest.set_node(p, {name = "default:glass"})
                else
                    minetest.set_node(p, {name = "air"})
                end
            end
        end
    end
end

local function level_to_pos(level)
    -- Fill bottom-up in row-major order inside 3x5x1 volume => 15 levels.
    local idx = level - 1
    local x = idx % container_inner_size.x
    local y = math.floor(idx / container_inner_size.x)
    return pos_add(container_origin, {x = x, y = y + 1, z = 0})
end

local function set_water_level(level)
    for i = 1, 15 do
        local p = level_to_pos(i)
        if i <= level then
            minetest.set_node(p, {name = "default:water_source"})
        else
            minetest.set_node(p, {name = "air"})
        end
    end
end

local function feedback(pos, success)
    local tex = success and "default_water.png" or "default_lava.png"
    minetest.add_particlespawner({
        amount = 15,
        time = 0.35,
        minpos = pos_add(pos, {x = -0.3, y = 0.2, z = -0.3}),
        maxpos = pos_add(pos, {x = 0.3, y = 1.2, z = 0.3}),
        minvel = {x = -0.5, y = 0.5, z = -0.5},
        maxvel = {x = 0.5, y = 2, z = 0.5},
        minacc = {x = 0, y = -2, z = 0},
        maxacc = {x = 0, y = -4, z = 0},
        minexptime = 0.4,
        maxexptime = 0.8,
        minsize = 1,
        maxsize = 3,
        texture = tex,
        glow = 5,
    })
    minetest.sound_play(success and "default_water_footstep" or "default_dig_cracky", {
        pos = pos,
        gain = 0.8,
        max_hear_distance = 20,
    })
end

local function game_state()
    if not rhythm_memory.game then
        rhythm_memory.game = {
            players = {},
            hud = {},
            score = {},
            turn = 0,
            water_level = 0,
            sequence = nil,
            inputs = {},
            phase = "idle",
            deadline = 0,
        }
    end
    return rhythm_memory.game
end

local function broadcast(msg)
    for _, name in ipairs(game_state().players) do
        minetest.chat_send_player(name, msg)
    end
end

local function refresh_scores()
    local g = game_state()
    for _, name in ipairs(g.players) do
        local player = get_player(name)
        if player and g.hud[name] then
            rhythm_memory.hud.set_score(player, g.hud[name], g.score[name] or 0, g.turn, MAX_TOTAL_TURNS)
        end
    end
end

local function next_turn()
    local g = game_state()
    g.turn = g.turn + 1

    if g.turn > MAX_TOTAL_TURNS then
        M.finish_match()
        return
    end

    g.phase = "show"
    g.sequence = rhythm_memory.sequence.generate(g.turn)
    g.inputs = {}

    for idx, name in ipairs(g.players) do
        local player = get_player(name)
        if player and g.hud[name] then
            rhythm_memory.hud.set_sequence(player, g.hud[name], g.sequence)
            rhythm_memory.hud.set_status(player, g.hud[name], "Watch the sequence...", 0x99CCFF)
        end
        g.inputs[name] = {
            expected = rhythm_memory.sequence.to_player_keys(g.sequence, idx),
            entered = {},
            done = false,
        }
    end

    minetest.after(2.5, function()
        if g.turn == 0 or g.phase ~= "show" then
            return
        end
        g.phase = "input"
        g.deadline = minetest.get_gametime() + INPUT_TIMEOUT
        for _, name in ipairs(g.players) do
            local player = get_player(name)
            if player and g.hud[name] then
                rhythm_memory.hud.set_status(player, g.hud[name], "Repeat now! (/press key)", 0xFFFFFF)
            end
        end
    end)
end

local function evaluate_turn()
    local g = game_state()
    if g.phase ~= "input" then
        return
    end

    g.phase = "resolve"

    for _, name in ipairs(g.players) do
        local data = g.inputs[name]
        local player = get_player(name)
        local success = false

        if data then
            success = (#data.entered == #data.expected)
            if success then
                for i = 1, #data.expected do
                    if data.entered[i] ~= data.expected[i] then
                        success = false
                        break
                    end
                end
            end
        end

        if success then
            g.score[name] = (g.score[name] or 0) + 1
            g.water_level = math.min(15, g.water_level + 1)
            feedback(player and player:get_pos() or container_origin, true)
            if player and g.hud[name] then
                rhythm_memory.hud.set_status(player, g.hud[name], "Correct!", 0x66FF66)
            end
        else
            feedback(player and player:get_pos() or container_origin, false)
            if player and g.hud[name] then
                rhythm_memory.hud.set_status(player, g.hud[name], "Miss!", 0xFF6666)
            end
        end
    end

    set_water_level(g.water_level)
    refresh_scores()

    -- Base game is 15 turns; sudden death continues while container is not full.
    if g.turn >= MAX_BASE_TURNS and (g.water_level >= 15 or g.turn >= MAX_TOTAL_TURNS) then
        minetest.after(1.5, M.finish_match)
    else
        minetest.after(1.5, next_turn)
    end
end

function M.try_auto_add(name)
    local g = game_state()
    if #g.players >= 2 then
        return
    end
    for _, existing in ipairs(g.players) do
        if existing == name then
            return
        end
    end
    table.insert(g.players, name)
    g.score[name] = 0

    local player = get_player(name)
    if player then
        g.hud[name] = rhythm_memory.hud.create(player)
    end

    broadcast(name .. " joined the rhythm game (" .. #g.players .. "/2).")
    if #g.players == 2 then
        M.start_match()
    end
end

function M.add_player(name)
    local g = game_state()
    if #g.players >= 2 then
        return false, "Match already has 2 players."
    end
    for _, existing in ipairs(g.players) do
        if existing == name then
            return false, "You already joined."
        end
    end

    M.try_auto_add(name)
    return true, "Joined match queue."
end

function M.remove_player(name)
    local g = game_state()
    for idx, n in ipairs(g.players) do
        if n == name then
            table.remove(g.players, idx)
            break
        end
    end
    local player = get_player(name)
    if player and g.hud[name] then
        rhythm_memory.hud.remove(player, g.hud[name])
    end
    g.hud[name] = nil
    g.score[name] = nil

    if g.phase ~= "idle" then
        g.phase = "idle"
        g.turn = 0
        g.water_level = 0
        set_water_level(0)
        broadcast("Match stopped because a player left.")
    end
end

function M.start_match()
    local g = game_state()
    if #g.players < 2 then
        return false, "Need exactly 2 players."
    end

    setup_container()
    set_water_level(0)

    g.turn = 0
    g.water_level = 0
    g.phase = "ready"

    for _, name in ipairs(g.players) do
        g.score[name] = 0
        local player = get_player(name)
        if player and not g.hud[name] then
            g.hud[name] = rhythm_memory.hud.create(player)
        end
        if player and g.hud[name] then
            rhythm_memory.hud.set_status(player, g.hud[name], "Match starting...", 0xFFFFFF)
            rhythm_memory.hud.set_sequence(player, g.hud[name], {"L", "R", "L"})
        end
    end

    refresh_scores()
    minetest.after(1.5, next_turn)
    return true, "Rhythm match started."
end

function M.handle_input(name, key)
    local g = game_state()
    if g.phase ~= "input" then
        return false, "Input phase is not active."
    end

    local slot
    for _, pname in ipairs(g.players) do
        if pname == name then
            slot = g.inputs[name]
            break
        end
    end
    if not slot then
        return false, "You are not in this match."
    end

    key = (key or ""):lower()
    if key ~= "w" and key ~= "y" and key ~= "i" and key ~= "p" then
        return false, "Invalid key. Use w/y/i/p."
    end

    table.insert(slot.entered, key)

    if #slot.entered >= #slot.expected then
        slot.done = true
    end

    local all_done = true
    for _, pname in ipairs(g.players) do
        if not g.inputs[pname].done then
            all_done = false
            break
        end
    end

    if all_done then
        evaluate_turn()
    end

    return true, "Registered " .. key
end

function M.finish_match()
    local g = game_state()
    g.phase = "idle"

    local p1, p2 = g.players[1], g.players[2]
    local s1 = p1 and (g.score[p1] or 0) or 0
    local s2 = p2 and (g.score[p2] or 0) or 0

    local result
    if s1 > s2 then
        result = p1 .. " wins!"
    elseif s2 > s1 then
        result = p2 .. " wins!"
    else
        result = "Draw!"
    end

    broadcast(string.format("Match over after %d turns. %s (%d - %d)", g.turn, result, s1, s2))

    for _, name in ipairs(g.players) do
        local player = get_player(name)
        if player and g.hud[name] then
            rhythm_memory.hud.set_status(player, g.hud[name], result, 0xFFFF66)
        end
    end
end

minetest.register_globalstep(function()
    local g = game_state()
    if g.phase == "input" and minetest.get_gametime() >= g.deadline then
        evaluate_turn()
    end
end)

return M
