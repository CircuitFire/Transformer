require("vehicle")

local function player(event)
    return game.players[event.player_index]
end

local function init_player(player_index)
    global[player_index] = global[player_index] or {}
end

local function full_init()
    for _, player in pairs(game.players) do
        init_player(player.index)
    end
end

script.on_init(full_init)
script.on_configuration_changed(full_init)

script.on_event(defines.events.on_player_created, function(event)
    init_player(event.player_index)
end)

local function toggle_shortcut(event, name)
    local player = player(event)
    player.set_shortcut_toggled("cf-toggle-transform", not player.is_shortcut_toggled("cf-toggle-transform"))
end

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "cf-toggle-transform" then
        toggle_shortcut(event)
    end
end)

script.on_event("cf-toggle-transform", function(event)
	toggle_shortcut(event)
end)

local function nearby_vehicle(player)
    local list = player.surface.find_entities_filtered{
        position = player.position,
        radius = 4,
        type = { "car", "artillery-wagon", "cargo-wagon", "fluid-wagon", "locomotive", "spider-vehicle" }
    }
    return next(list) ~= nil
end

local function nearby_rail(player)
    local list = player.surface.find_entities_filtered{
        position = player.position,
        radius = 3,
        type = { "straight-rail", "curved-rail" }
    }
    return next(list) ~= nil
end

script.on_event("cf-toggle-driving", function(event)
    local player = player(event)
    if not player.is_shortcut_toggled("cf-toggle-transform") then return end
    if player.driving or nearby_vehicle(player) or not player.character then return end

    local err = Vehicle.load(player, nearby_rail(player))
    if err then
        player.create_local_flying_text{ text=err, position=player.position }
    end
end)

script.on_event(defines.events.on_player_driving_changed_state, function(event)
	local player = player(event)
    local vehicle = event.entity
    if not player.is_shortcut_toggled("cf-toggle-transform") then return end
    if player.driving or not player.character then return end
    if vehicle.type == "cargo-wagon" or vehicle.type == "fluid-wagon" or vehicle.type == "artillery-wagon" then return end

    Vehicle.save(player, vehicle)
end)