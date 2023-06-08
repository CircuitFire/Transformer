--[[
vehicle
    name
    color
    health
    inventory
    ammo
    logistics
    fuel
    equipment
    schedule
    targeting
]]

Vehicle = {}

local function inventory_type(vehicle, type)
    if vehicle.type == "car" then
        if type == "trunk" then
            return defines.inventory.car_trunk     
        elseif type == "ammo" then
            return defines.inventory.car_ammo
        end
    elseif vehicle.type == "spider-vehicle" then
        if type == "trunk" then
            return defines.inventory.spider_trunk   
        elseif type == "ammo" then
            return defines.inventory.spider_ammo
        elseif type == "trash" then
            return defines.inventory.spider_trash
        end
    end
end

local function save_inventory(vehicle, type)
    if not type then return end
    local inv = vehicle.get_inventory(type)

    filters = {}
    for i=1, #inv do
        filters[i] = inv.get_filter(i)
    end

    return {
        items = inv.get_contents(),
        filters = filters,
    }
end

local function save_logistics(vehicle)
    local trash = vehicle.get_inventory(defines.inventory.spider_trash)
    if not trash then return end

    local requests = {}
    for i=1, vehicle.request_slot_count do
        local temp = vehicle.get_vehicle_logistic_slot(i)
        if temp.name then
            requests[i] = temp
        end
    end

    return {
        enabled = vehicle.vehicle_logistic_requests_enabled,
        buffer = vehicle.request_from_buffers,
        requests = requests,
        moving = vehicle.enable_logistics_while_moving,
        trash = trash.get_contents(),
    }
end

local function save_burner(burner)
    if not burner then return end
    return {
        currently_burning = burner.currently_burning,
        remaining_burning_fuel = burner.remaining_burning_fuel,
        inventory = burner.inventory.get_contents(),
        burnt_result_inventory = burner.burnt_result_inventory.get_contents(),
    }
end

local function save_equipment(grid)
    if not grid then return end
    local list = {}
    for _, item in pairs(grid.equipment) do
        table.insert(
            list,
            {
                name = item.name,
                position = item.position,
                energy = item.energy,
                shield = item.shield,
                burner = save_burner(item.burner),
            }
        )
    end
    return list
end

function Vehicle.save(player, vehicle)
    local type = "other"
    if vehicle.type == "locomotive" then
        if #vehicle.train.carriages > 1 then return end
        type = "train"
    end
    if global[player.index][type] then return end

    global[player.index][type] = {
        name = vehicle.name,
        color = vehicle.color,
        health = vehicle.health,
        inventory = save_inventory(vehicle, inventory_type(vehicle, "trunk")),
        ammo = save_inventory(vehicle, inventory_type(vehicle, "ammo")),
        logistics = save_logistics(vehicle),
        fuel = save_burner(vehicle.burner),
        equipment = save_equipment(vehicle.grid),
        schedule = vehicle.train and vehicle.train.schedule,
        targeting = vehicle.type == "spider-vehicle" and vehicle.vehicle_automatic_targeting_parameters
    }

    vehicle.destroy()
end

local function load_inventory(vehicle, type, saved)
    local inv = vehicle.get_inventory(type)

    for i, filter in pairs(saved.filters) do
        inv.set_filter(i, filter)
    end
    for name, count in pairs(saved.items) do
        inv.insert{name=name, count=count}
    end
end

local function load_burner(burner, saved)
    if not burner then return end

    burner.currently_burning = saved.currently_burning
    burner.remaining_burning_fuel = saved.remaining_burning_fuel
    local inv = burner.inventory
    for name, count in pairs(saved.inventory) do
        inv.insert{name=name, count=count}
    end
    inv = burner.burnt_result_inventory
    for _, item in pairs(saved.burnt_result_inventory) do
        inv.insert{name=name, count=count}
    end
end

local function load_equipment(grid, saved)
    for _, item in pairs(saved) do
        local new = grid.put{name=item.name, position=item.position}
        if new.max_shield > 0 then new.shield = item.shield end
        new.energy = item.energy
        load_burner(new.burner, item.burner)
    end
end

local function load_logistics(vehicle, saved)
    local inv = vehicle.get_inventory(defines.inventory.spider_trash)
    for name, count in pairs(saved.trash) do
        inv.insert{name=name, count=count}
    end

    for i, data in pairs(saved.requests) do
        vehicle.set_vehicle_logistic_slot(i, data)
    end

    vehicle.enable_logistics_while_moving = saved.moving
    vehicle.request_from_buffers = saved.buffer
    vehicle.vehicle_logistic_requests_enabled = saved.enabled
end

function Vehicle.load(player, nearby_rail)
    local position = player.position
    local direction = player.character.direction
    local load

    if nearby_rail and global[player.index]["train"] then
        load = "train"
    else
        load = "other"
    end

    local saved = global[player.index][load]
    if not saved then return { "error.no-vehicle" } end

    local temp_pos = player.surface.find_non_colliding_position("character", position, 100, 10)
    if not temp_pos then return { "error.no-space" } end
    player.teleport(temp_pos)

    local vehicle = player.surface.create_entity {
        name = saved.name,
        position = position,
        force = player.force,
        direction = direction,
    }
    if not vehicle then
        player.teleport(position)
        return { "error.no-space" }
    end

    local temp_pos = player.surface.find_non_colliding_position("character", position, 10, 1)
    if not temp_pos then
        vehicle.destroy()
        player.teleport(position)
        return { "error.no-space" }
    end
    player.teleport(temp_pos)

    vehicle.health = saved.health
    if saved.inventory then load_inventory(vehicle, inventory_type(vehicle, "trunk"), saved.inventory) end
    if saved.ammo then load_inventory(vehicle, inventory_type(vehicle, "ammo"), saved.ammo) end
    if saved.logistics then load_logistics(vehicle, saved.logistics) end
    if saved.fuel then load_burner(vehicle.burner, saved.fuel) end
    if saved.equipment then load_equipment(vehicle.grid, saved.equipment) end
    if saved.schedule then vehicle.train.schedule = saved.schedule end
    if vehicle.type == "spider-vehicle" then vehicle.vehicle_automatic_targeting_parameters = saved.targeting end

    global[player.index][load] = nil
end