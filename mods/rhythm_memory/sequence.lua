-- Sequence generation utilities.
--
-- We generate left/right steps with symbols bound to each player's keys:
--   Player 1: w (left), y (right)
--   Player 2: u (left), o (right)

local M = {}

local left_right = {"L", "R"}

-- Increase sequence length from 3 to 5 across the match.
function M.length_for_turn(turn)
    if turn <= 5 then
        return 3
    elseif turn <= 10 then
        return 4
    end
    return 5
end

function M.generate(turn)
    local len = M.length_for_turn(turn)
    local seq = {}
    for idx = 1, len do
        seq[idx] = left_right[math.random(1, 2)]
    end
    return seq
end

-- Convert abstract steps to keys per player.
function M.to_player_keys(sequence, player_idx)
    local mapping
    if player_idx == 1 then
        mapping = {L = "w", R = "y"}
    else
        mapping = {L = "u", R = "o"}
    end

    local out = {}
    for idx, step in ipairs(sequence) do
        out[idx] = mapping[step]
    end
    return out
end

return M
