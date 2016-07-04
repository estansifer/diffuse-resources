-- Returns a function which, given integer (x, y) coordinates, returns a random
-- value in [0, 1). The same coordinates will give the same value.
--
-- We assume that no one else is using global.randxy to store anything important.
-- name is a string, which is any unique identifier. Two copies of RandXY given
-- the same name will behave identically. Two copies given different names will
-- behave independently.
--
-- Works across saving/loading.
function RandXY(name)
    if global.randxy == nil then
        global.randxy = {}
    end
    if global.randxy[name] == nil then
        global.randxy[name] = {{}, {}}
    end
    local xs = global.randxy[name][1]
    local ys = global.randxy[name][2]

    local function random(x, y)
        return math.random()
        -- The above code is a quick fix because the following code was causing
        -- desyncs in multiplayer... but I have no idea why.
        --[[
        if xs[x] == nil then
            xs[x] = math.random()
        end
        if ys[y] == nil then
            ys[y] = math.random()
        end
        return (xs[x] + ys[y]) % 1
        ]]
    end
    return random
end
