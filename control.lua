require "config"
require "lib/randxy"

local append = table.insert

local msg = 0
function db(s)
    local p = game.players[1]
    if p ~= nil then
        p.print('[' .. msg .. ']    ' .. s)
        msg = msg + 1
    end
end

-- Functions that, given a position (x, y), return a random number from [0, 1)
-- Given the same input, always returns the same output
-- Defined in on_load
local random_amount = RandXY("amount")
local random_type = RandXY("type")

local cauchy_min = 0.5 - math.atan(2) / math.pi -- about 0.14758

-- Does not account for the richness multiplier. Returns a random number near 1.
local function resource_amount(x, y)
    local cdf = cauchy_min + random_amount(x, y) * (1 - cauchy_min)
    -- Cauchy distribution
    -- cdf = (1 / pi) * atan((x - x0) / gamma) + 0.5
    -- x0 = 1
    -- gamma = 1 / 2
    -- We require x > 0, so cdf > 0.5 - atan(2) / pi = cauchy_min
    local a = math.tan(math.pi * (cdf - 0.5)) / 2 + 1
    -- Since the tail is too thick, we take the square root if it is above 1
    if a > 1 then
        a = math.sqrt(a)
    end
    return a
end

local tf
local function update_tf()
    tf = 0
    for _, r in pairs(global.saved_config.resources) do
        tf = tf + r.frequency
    end
end

local function resource_type(x, y)
    local f = tf * random_type(x, y)
    for name, r in pairs(global.saved_config.resources) do
        f = f - r.frequency
        if f < 0 then
            return name
        end
    end
    return "stone"
end

-- Rectangle from (x1, y1) inclusive to (x2, y2) exclusive
local function roll_region(surface, region)
    local resources = global.saved_config.resources
    local entities = surface.find_entities_filtered{
            area = {{region.x1, region.y1}, {region.x2, region.y2}},
            type = "resource"}
    for _, e in ipairs(entities) do
        if e.name ~= "crude-oil" then
            e.destroy()
        end
    end

    for x = region.x1, region.x2 - 1 do
        for y = region.y1, region.y2 - 1 do
            local terrain = surface.get_tile(x, y).name
            if not (terrain == "water" or terrain == "deepwater"
                or terrain == "water-green" or terrain == "deepwater-green") then
                local name = resource_type(x, y)
                local r = resources[name].richness
                local amount = math.floor(r * resource_amount(x, y))
                if amount > 0 then
                    surface.create_entity(
                            {
                                name = name,
                                amount = amount,
                                position = {x, y}
                            }
                        )
                end
            end
        end
    end
end

local function reroll_region(surface, region)
    local resources = global.saved_config.resources

    local entities = surface.find_entities_filtered{
            area = {{region.x1, region.y1}, {region.x2, region.y2}},
            type = "resource"}

    for _, e in ipairs(entities) do
        if e.name ~= "crude-oil" then
            local new_name = resource_type(e.position.x, e.position.y)
            if new_name ~= e.name then
                local new_r = resources[new_name].richness
                local old_r = resources[e.name].richness
                local new_amount = math.floor(new_r * e.amount / old_r)
                if new_amount > 0 then
                    surface.create_entity(
                            {
                                name = new_name,
                                amount = new_amount,
                                position = e.position
                            }
                        )
                end
                e.destroy()
            end
        end
    end
end

local function make_chunk(event)
    local c = global.saved_config
    if c == nil then
        return
    end

    local x1 = event.area.left_top.x
    local y1 = event.area.left_top.y
    local x2 = event.area.right_bottom.x
    local y2 = event.area.right_bottom.y

    local region = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}

    append(global.all_regions, {event.surface, region})
    if x1 * x1 + y1 * y1 < 400 * 400 then
        roll_region(event.surface, region)
    else
        append(global.pending_rolls, {event.surface, region})
    end
end

local function dist(region)
    return (region.x1 * region.x1 + region.y1 * region.y1 +
        region.x2 * region.x2 + region.y2 * region.y2)
end

local function reroll_everything()
    global.pending_rerolls = {}
    for _, r in ipairs(global.all_regions) do
        append(global.pending_rerolls, r)
    end
    local function comp(a, b)
        return dist(a[2]) > dist(b[2])
    end
    table.sort(global.pending_rerolls, comp)
    db("(debug) Processing " .. tostring(#global.pending_rerolls) .. " regions...")
end

local function unresearch(name)
    local t = game.forces.player.technologies[name]
    if t.researched then
        t.researched = false
    end
end

local function update_research(event)
    local r = event.research
    if r.name == "applied-geology" or r.name == "aeromagnetic-surveys" then
        unresearch("more-stone")
        unresearch("more-coal")
        unresearch("more-iron-ore")
        unresearch("more-copper-ore")
    end

    for name, res in pairs(global.saved_config.resources) do
        if r.name == ("more-" .. name) then
            res.frequency = res.frequency * 1.2
            update_tf()
            reroll_everything()
            unresearch("aeromagnetic-surveys")
        end
    end
end

local function on_tick(event)
    if (event.tick % 10) == 0 then
        if #(global.pending_rolls) > 0 then
            local x = table.remove(global.pending_rolls)
            roll_region(x[1], x[2])
        elseif #(global.pending_rerolls) > 0 then
            local x = table.remove(global.pending_rerolls)
            reroll_region(x[1], x[2])
            if #(global.pending_rerolls) == 0 then
                db("...done.")
            end
        end
    end
end

local function check_for_filters(event)
    local e = event.created_entity
    if e.name == "filter-inserter" or e.name == "stack-filter-inserter" then
        local surface = e.surface
        local p = e.position

        e.health = 1
        surface.create_entity{
                name = 'cluster-grenade',
                position = p,
                target = e,
                speed = 0
            }
    end
end

local function on_load(event)
    local c = global.saved_config
    if c ~= nil then
        update_tf()
        script.on_event(defines.events.on_chunk_generated, make_chunk)
        script.on_event(defines.events.on_tick, on_tick)
        script.on_event(defines.events.on_research_finished, update_research)
    end
    -- We don't use global.saved_config here so that user can enable / disable this
    -- in the middle of a save
    if config.no_filter_inserters then
        script.on_event(defines.events.on_built_entity, check_for_filters)
        script.on_event(defines.events.on_robot_built_entity, check_for_filters)
    end
end

local function on_init(event)
    global.saved_config = config
    global.all_regions = {}
    global.pending_rolls = {}
    global.pending_rerolls = {}
    on_load(nil)
end

script.on_init(on_init)
script.on_load(on_load)
