local append = table.insert

-- Change appearance of ores on the map, and remove them from the minimap.

local r = data.raw.resource
local names = {"stone", "coal", "iron-ore", "copper-ore"}

for _, name in ipairs(names) do
    append(r[name].flags, "not-on-map")
    r[name].stages.sheet.filename = "__diffuse-resources__/graphics/entity/" .. name .. "2.png"
    r[name].stage_counts = {1000, 200, 90, 60, 40, 20, 10, 1}
    -- Default:
    -- stage_counts = {1000, 600, 400, 200, 100, 50, 20, 1}
end
r.stone.stage_counts = {200, 50, 30, 20, 15, 10, 5, 1}


-- Add new technologies

local o = 0
local function order()
    o = o + 1
    return "b-e-" .. tostring(o)
end

local i = 0
local function tech(name)
    i = i + 1
    return {
        type = "technology",
        name = "more-" .. name,
        icon = "__diffuse-resources__/graphics/technology/more-" .. name .. ".png",
        icon_size = 64,
        effects = {},
        prerequisites = {"mineral-exploration"},
        unit = {
            count = 50,
            ingredients = {
                {"science-pack-1", 1}
            },
            time = 60
        },
        order = order()
    }
end

data:extend({
        {
            type = "technology",
            name = "mineral-exploration",
            icon = "__diffuse-resources__/graphics/technology/allores.png",
            icon_size = 128, -- irritating
            effects = {},
            prerequisites = {},
            prerequisites = {"landfill"},
            unit = {
                count = 50,
                ingredients = {
                    {"science-pack-1", 2},
                    {"science-pack-2", 1}
                },
                time = 30
            },
            order = order()
        },
        tech("stone"),
        tech("coal"),
        tech("iron-ore"),
        tech("copper-ore"),
        {
            type = "technology",
            name = "applied-geology",
            icon = "__diffuse-resources__/graphics/technology/allores.png",
            icon_size = 128,
            effects = {},
            prerequisites = {"mineral-exploration", "toolbelt"},
            unit = {
                count = 100,
                ingredients = {
                    {"science-pack-1", 1},
                    {"science-pack-2", 1}
                },
                time = 30
            },
            order = order()
        },
        {
            type = "technology",
            name = "aeromagnetic-surveys",
            icon = "__diffuse-resources__/graphics/technology/allores.png",
            icon_size = 128,
            effects = {},
            prerequisites = {"applied-geology", "flying"},
            unit = {
                count = 200,
                ingredients = {
                    {"science-pack-1", 1},
                    {"science-pack-2", 1},
                    {"science-pack-3", 1}
                },
                time = 30
            },
            order = order()
        }
    })
