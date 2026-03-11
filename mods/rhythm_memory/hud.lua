-- HUD management for the rhythm memory game.

local M = {}

local function arrow_text(sequence)
    local parts = {}
    for _, step in ipairs(sequence) do
        if step == "L" then
            table.insert(parts, "←")
        else
            table.insert(parts, "→")
        end
    end
    return table.concat(parts, " ")
end

function M.create(player)
    local pmeta = {
        title = player:hud_add({
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.1},
            text = "Rhythm Memory",
            number = 0xFFFFFF,
            scale = {x = 100, y = 24},
            alignment = {x = 0, y = 0},
        }),
        sequence = player:hud_add({
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.16},
            text = "Waiting for players...",
            number = 0x88CCFF,
            scale = {x = 100, y = 24},
            alignment = {x = 0, y = 0},
        }),
        score = player:hud_add({
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.22},
            text = "Score: 0",
            number = 0xAAFFAA,
            scale = {x = 100, y = 24},
            alignment = {x = 0, y = 0},
        }),
        status = player:hud_add({
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.28},
            text = "",
            number = 0xFFFFAA,
            scale = {x = 100, y = 24},
            alignment = {x = 0, y = 0},
        }),
    }
    return pmeta
end

function M.remove(player, refs)
    if not player or not refs then
        return
    end
    for _, id in pairs(refs) do
        player:hud_remove(id)
    end
end

function M.set_sequence(player, refs, sequence)
    player:hud_change(refs.sequence, "text", "Sequence: " .. arrow_text(sequence))
end

function M.set_score(player, refs, score, turn, max_turns)
    player:hud_change(refs.score, "text", string.format("Score: %d | Turn: %d/%d", score, turn, max_turns))
end

function M.set_status(player, refs, text, color)
    player:hud_change(refs.status, "text", text)
    if color then
        player:hud_change(refs.status, "number", color)
    end
end

return M
