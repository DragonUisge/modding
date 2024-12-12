
                                              --------------
                                              -- Commands --
											  --------------




-- Utility function for logging
local function log(message)
    minetest.log("action", "[Custom Commands] " .. message)
end

-- Initialize mod_storage
local storage = minetest.get_mod_storage()

-- Helper function to determine if an entity is a mob and its tamed status
local function is_mob_and_tamed(entity)
    -- Check if the entity has typical mob properties
    if entity.object and entity.name then
        local is_mob = entity.name:find("^waterdragon:") or
                       entity.type == "animal" or
                       entity.type == "monster" or
                       entity.hp or
                       entity.health

        if is_mob then
            -- Check various possible tamed status indicators
            local tamed = entity.tamed or 
                          entity.is_tamed or 
                          entity.owner or 
                          (entity.data and entity.data.tamed) or
                          false
            
            log(string.format("Entity found: %s, Is mob: %s, Tamed status: %s", 
                              entity.name, tostring(is_mob), tostring(tamed)))
            
            return true, tamed
        end
    end
    return false, false
end

-- Improved and Flexible List Mobs Command
minetest.register_chatcommand("list-mobs", {
    params = "[all|tamed|untamed]",
    description = "List mobs in the game",
    func = function(name, param)
        log("list_mobs command called by " .. name .. " with param: " .. (param or "all"))
        
        local mobs = {all = {}, tamed = {}, untamed = {}}
        local count = {total = 0, mobs = 0, tamed = 0, untamed = 0}
        
        for id, entity in pairs(minetest.luaentities) do
            count.total = count.total + 1
            local is_mob, tamed = is_mob_and_tamed(entity)
            if is_mob then
                count.mobs = count.mobs + 1
                local mob_type = tamed and "tamed" or "untamed"
                local mob_info = string.format("%s (%s)", entity.name, mob_type)
                table.insert(mobs.all, mob_info)
                table.insert(mobs[mob_type], entity.name)
                count[mob_type] = count[mob_type] + 1
                log("Added mob to list: " .. mob_info)
            else
                log("Skipped entity: " .. (entity.name or "unnamed") .. " (not recognized as mob)")
            end
        end
        
        log(string.format("Scan complete. Entities: %d, Mobs: %d, Tamed: %d, Untamed: %d", 
                          count.total, count.mobs, count.tamed, count.untamed))

        local filter = param or "all"
        local result
        
        if filter == "all" then
            result = string.format("All mobs (%d):\n%s", #mobs.all, table.concat(mobs.all, "\n"))
        elseif filter == "tamed" then
            result = string.format("Tamed mobs (%d):\n%s", #mobs.tamed, table.concat(mobs.tamed, "\n"))
        elseif filter == "untamed" then
            result = string.format("Untamed mobs (%d):\n%s", #mobs.untamed, table.concat(mobs.untamed, "\n"))
        else
            return false, "Invalid parameter. Use 'all', 'tamed', or 'untamed'."
        end

        if #mobs[filter] == 0 then
            log("No mobs found matching the criteria: " .. filter)
            return true, string.format("No mobs found matching the criteria: %s\n" ..
                                       "Total entities: %d, Mobs: %d, Tamed: %d, Untamed: %d",
                                       filter, count.total, count.mobs, count.tamed, count.untamed)
        else
            log(result)
            return true, result
        end
    end,
})


-- Last Logout Command (unchanged)
minetest.register_chatcommand("last-logout", {
    params = "<playername>",
    description = "Show the last logout time of a player",
    func = function(name, param)
        log("last-logout command called by " .. name .. " for player: " .. param)
        
        if param == "" then
            return false, "Please provide a player name"
        end

        local mod_storage = minetest.get_mod_storage()
        local last_logout = mod_storage:get_string(param .. "_last_logout")

        log("Retrieved last_logout for " .. param .. ": " .. (last_logout or "nil"))

        if last_logout and last_logout ~= "" then
            return true, param .. " last logged out on: " .. last_logout
        else
            return true, "No logout information found for " .. param
        end
    end,
})

-- Add this to handle player logouts
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local mod_storage = minetest.get_mod_storage()
    local logout_time = os.date("%Y-%m-%d %H:%M:%S")
    mod_storage:set_string(name .. "_last_logout", logout_time)
    log("Recorded logout for " .. name .. " at " .. logout_time)
end)

log("Custom commands loaded")



-- Last Login Command
minetest.register_chatcommand("last-login", {
    params = "<playername>",
    description = "Show the last login time of a player",
    func = function(name, param)
        if param == "" then
            return false, "Please provide a player name"
        end

        local auth_handler = minetest.get_auth_handler()
        local entry = auth_handler.get_auth(param)
        if not entry then
            return false, "Player not found"
        end

        if entry.last_login then
            return true, param .. " last logged in on: " .. os.date("%Y-%m-%d %H:%M:%S", entry.last_login)
        else
            return true, param .. " has never logged in"
        end
    end,
})




-- Helper function to determine if an entity is a mob and its tamed status
function is_mob_and_tamed(entity)
    if entity.object and entity.name then
        -- Check various properties that might indicate a mob
        local is_mob = entity.health or
                       entity.hp or
                       entity.breath or
                       entity.type == "animal" or
                       entity.type == "monster" or
                       entity.walk_velocity or
                       entity.jump or
                       entity.drops

        if is_mob then
            -- Check various possible tamed status indicators
            local tamed = entity.tamed or 
                          entity.is_tamed or 
                          entity.owner or 
                          (entity.data and entity.data.tamed) or
                          false
            
            return true, tamed
        end
    end
    return false, false
end

-- Utility function for logging
function log(message)
    minetest.log("action", "[Custom Commands] " .. message)
end

-- Initialize mod_storage
local storage = minetest.get_mod_storage()

-- Helper function to determine if an entity is a mob and its tamed status
function is_mob_and_tamed(entity)
    if entity.object and entity.name then
        -- Check various properties that might indicate a mob
        local is_mob = entity.health or
                       entity.hp or
                       entity.breath or
                       entity.type == "animal" or
                       entity.type == "monster" or
                       entity.walk_velocity or
                       entity.jump or
                       entity.drops

        if is_mob then
            -- Check various possible tamed status indicators
            local tamed = entity.tamed or 
                          entity.is_tamed or 
                          entity.owner or 
                          (entity.data and entity.data.tamed) or
                          false
            
            return true, tamed
        end
    end
    return false, false
end

minetest.register_chatcommand("clear_mobs", {
    params = "[all|tamed|untamed|<mob_name>]",
    description = "Clear mobs from the game",
    func = function(name, param)
        log("clear_mobs command called by " .. name .. " with param: " .. (param or "all"))

        local count = {total = 0, removed = 0}
        local removed_mobs = {}

        for id, entity in pairs(minetest.luaentities) do
            count.total = count.total + 1
            local is_mob, tamed = is_mob_and_tamed(entity)
            if is_mob then
                local should_remove = false
                if param == "all" then
                    should_remove = true
                elseif param == "tamed" and tamed then
                    should_remove = true
                elseif param == "untamed" and not tamed then
                    should_remove = true
                elseif param == entity.name then
                    should_remove = true
                end

                if should_remove then
                    log("Attempting to remove mob: " .. entity.name)
                    
                    -- Try multiple methods to remove the entity
                    local removed = false
                    
                    -- Method 1: Using object:remove()
                    if entity.object and entity.object:remove() then
                        removed = true
                        log("Removed mob using object:remove(): " .. entity.name)
                    end
                    
                    -- Method 2: Using entity's on_die function if it exists
                    if not removed and entity.on_die then
                        entity:on_die()
                        removed = true
                        log("Removed mob using on_die(): " .. entity.name)
                    end
                    
                    -- Method 3: Directly removing from minetest.luaentities
                    if not removed then
                        minetest.luaentities[id] = nil
                        removed = true
                        log("Removed mob by clearing from minetest.luaentities: " .. entity.name)
                    end

                    if removed then
                        count.removed = count.removed + 1
                        table.insert(removed_mobs, entity.name)
                    else
                        log("Failed to remove mob: " .. entity.name)
                    end
                else
                    log("Skipping mob (doesn't match criteria): " .. entity.name)
                end
            else
                log("Skipping entity (not a mob): " .. (entity.name or "unnamed"))
            end
        end

        local result = string.format("%d mobs removed out of %d total entities checked.", count.removed, count.total)
        if #removed_mobs > 0 then
            result = result .. "\nRemoved mobs: " .. table.concat(removed_mobs, ", ")
        end
        log(result)
        return true, result
    end,
})


minetest.register_chatcommand("setspawn", {
    description = "Set spawn point for new players and respawn",
    privs = {server = true},  -- Only server admins can set spawn
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local pos = player:get_pos()
        local rounded_pos = {
            x = math.floor(pos.x + 0.5),
            y = math.floor(pos.y + 0.5),
            z = math.floor(pos.z + 0.5)
        }

        -- Save spawn position
        local spawn_pos = minetest.serialize(rounded_pos)
        local path = minetest.get_worldpath() .. "/spawn.txt"
        local file = io.open(path, "w")
        if not file then
            return false, "Could not save spawn position"
        end
        file:write(spawn_pos)
        file:close()

        minetest.settings:set("static_spawnpoint", string.format("%.1f,%.1f,%.1f", rounded_pos.x, rounded_pos.y, rounded_pos.z))

        return true, string.format("Spawn point set to %.1f,%.1f,%.1f", rounded_pos.x, rounded_pos.y, rounded_pos.z)
    end
})

minetest.register_on_newplayer(function(player)
    local path = minetest.get_worldpath() .. "/spawn.txt"
    local file = io.open(path, "r")
    if not file then
        return -- Если файл не найден, используется стандартный спавн
    end
    
    local spawn_pos = minetest.deserialize(file:read("*all"))
    file:close()
    
    if spawn_pos then
        player:set_pos(spawn_pos)
    end
end)

-- Handle respawn - using built-in Minetest function instead
minetest.register_on_respawnplayer(function(player)
    local path = minetest.get_worldpath() .. "/spawn.txt"
    local file = io.open(path, "r")
    if not file then
        -- If no spawn file exists, use default spawn
        return false
    end
    local spawn_pos = minetest.deserialize(file:read("*all"))
    file:close()
    if spawn_pos then
        player:set_pos(spawn_pos)
        return true
    end
    return false
end)

log("Custom commands loaded with improved clear_mobs")

-- Last Player Position Command
minetest.register_chatcommand("last-player-pos", {
    params = "<player_name>",
    description = "Show the last known position of a player",
    func = function(name, param)
        if param == "" then
            return false, "Please provide a player name"
        end

        local player = minetest.get_player_by_name(param)
        if player then
            local pos = player:get_pos()
            return true, param .. "'s current position: " .. minetest.pos_to_string(pos)
        else
            local player_meta = minetest.get_player_information(param)
            if player_meta and player_meta.last_pos then
                return true, param .. "'s last known position: " .. minetest.pos_to_string(player_meta.last_pos)
            else
                return false, "Player not found or position unknown"
            end
        end
    end,
})

minetest.register_chatcommand("tp_spawn", {
    description = "Teleport to spawn point",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        local path = minetest.get_worldpath() .. "/spawn.txt"
        local file = io.open(path, "r")
        if not file then
            return false, "No spawn point set"
        end
        
        local spawn_pos = minetest.deserialize(file:read("*all"))
        file:close()
        
        if spawn_pos then
            player:set_pos(spawn_pos)
            return true, "Teleported to spawn"
        end
        return false, "Could not read spawn position"
    end
})

-- Хранение HUD ID для каждого игрока
local players_huds = {}

-- Функция для получения групп блока
local function get_node_groups(node_name)
    local def = minetest.registered_nodes[node_name]
    if not def or not def.groups then return "none" end
    
    local groups = {}
    for group, value in pairs(def.groups) do
        table.insert(groups, group)
    end
    
    if #groups == 0 then return "none" end
    return table.concat(groups, ", ")
end

-- Функция для обновления информации в HUD
local function update_node_info(player)
    if not player or not players_huds[player:get_player_name()] then return end
    
    -- Получаем блок, на который смотрит игрок
    local pointed = minetest.raycast(
        vector.add(player:get_pos(), {x=0, y=1.5, z=0}),
        vector.add(player:get_pos(), vector.multiply(player:get_look_dir(), 10)),
        false, 
        false
    ):next()

    local info_text
    if pointed and pointed.type == "node" then
        local pos = pointed.under
        local node = minetest.get_node(pos)
        local node_name = node.name
        local meta = minetest.get_meta(pos)
        local placer = meta:get_string("placer")
        
        -- Получаем описание узла если оно есть
        local nodedef = minetest.registered_nodes[node_name]
        local description = nodedef and nodedef.description or node_name
        local groups = get_node_groups(node_name)
        
        info_text = string.format(
            "Name: %s\n" ..
            "Technical name: %s\n" ..
            "Groups: %s\n" ..
            "Position: %d, %d, %d\n" ..
            "Placed by: %s",
            description,
            node_name,
            groups,
            pos.x, pos.y, pos.z,
            (placer ~= "" and placer or "mapgen")
        )
    else
        info_text = "Not looking at any block"
    end

    -- Обновляем текст в HUD только если он изменился
    local hud_id = players_huds[player:get_player_name()]
    if player:hud_get(hud_id).text ~= info_text then
        player:hud_change(hud_id, "text", info_text)
    end
end

minetest.register_chatcommand("nodeinfo", {
    description = "Toggle node information HUD",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found"
        end

        if players_huds[name] then
            player:hud_remove(players_huds[name])
            players_huds[name] = nil
            return true, "Node info HUD disabled"
        else
            players_huds[name] = player:hud_add({
                hud_elem_type = "text",
                position = {x = 1, y = 0},
                offset = {x = -4.5, y = 4.5},
                text = "Not looking at any block",
                alignment = {x = -1, y = 1},
                number = 0xFFFFFF,
                scale = {x = 100, y = 100}
            })
            return true, "Node info HUD enabled"
        end
    end
})

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        if players_huds[player:get_player_name()] then
            update_node_info(player)
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    players_huds[player:get_player_name()] = nil
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer and placer:is_player() then
        local meta = minetest.get_meta(pos)
        meta:set_string("placer", placer:get_player_name())
    end
end)