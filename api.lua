--------------
-- Modding --
--------------

modding.api = {}

-- Math --

local abs = math.abs
local floor = math.floor
local random = math.random

local function clamp(val, min_n, max_n)
	if val < min_n then
		val = min_n
	elseif max_n < val then
		val = max_n
	end
	return val
end

local vec_dist = vector.distance

local function vec_raise(v, n)
	if not v then return end
	return {x = v.x, y = v.y + n, z = v.z}
end

---------------
-- Local API --
---------------

local function contains_val(tbl, val)
	for _, v in pairs(tbl) do
		if v == val then return true end
	end
	return false
end

----------------------------
-- Registration Functions --
----------------------------

modding.registered_movement_methods = {}

function modding.register_movement_method(name, func)
	modding.registered_movement_methods[name] = func
end

modding.registered_utilities = {}

function modding.register_utility(name, func)
	modding.registered_utilities[name] = func
end

---------------
-- Utilities --
---------------

function modding.is_valid(mob)
	if not mob then return false end
	if type(mob) == "table" then mob = mob.object end
	if type(mob) == "userdata" then
		if mob:is_player() then
			if mob:get_look_horizontal() then return mob end
		else
			if mob:get_yaw() then return mob end
		end
	end
	return false
end

function modding.is_alive(mob)
	if not modding.is_valid(mob) then
		return false
	end
	if type(mob) == "table" then
		return (mob.hp or mob.health or 0) > 0
	end
	if mob:is_player() then
		return mob:get_hp() > 0
	else
		local ent = mob:get_luaentity()
		return ent and (ent.hp or ent.health or 0) > 0
	end
end

------------------------
-- Environment access --
------------------------

local default_node_def = {walkable = true} -- both ignore and unknown nodes are walkable

function modding.get_node_height_from_def(name)
	local def = minetest.registered_nodes[name] or default_node_def
	if not def then return 0.5 end
	if def.walkable then
		if def.drawtype == "nodebox" then
			if def.node_box
			and def.node_box.type == "fixed" then
				if type(def.node_box.fixed[1]) == "number" then
					return 0.5 + def.node_box.fixed[5]
				elseif type(def.node_box.fixed[1]) == "table" then
					return 0.5 + def.node_box.fixed[1][5]
				else
					return 1
				end
			else
				return 1
			end
		else
			return 1
		end
	else
		return 1
	end
end

local get_node = minetest.get_node

function modding.get_node_def(node) -- Node can be name or pos
	if type(node) == "table" then
		node = get_node(node).name
	end
	local def = minetest.registered_nodes[node] or default_node_def
	if def.walkable
	and modding.get_node_height_from_def(node) < 0.26 then
		def.walkable = false -- workaround for nodes like snow
	end
	return def
end

local get_node_def = modding.get_node_def

function modding.get_ground_level(pos, range)
	range = range or 2
	local above = vector.round(pos)
	local under = {x = above.x, y = above.y - 1, z = above.z}
	if not get_node_def(above).walkable and get_node_def(under).walkable then return above end
	if get_node_def(above).walkable then
		for _ = 1, range do
			under = above
			above = {x = above.x, y = above.y + 1, z = above.z}
			if not get_node_def(above).walkable and get_node_def(under).walkable then return above end
		end
	end
	if not get_node_def(under).walkable then
		for _ = 1, range do
			above = under
			under = {x = under.x, y = under.y - 1, z = under.z}
			if not get_node_def(above).walkable and get_node_def(under).walkable then return above end
		end
	end
	return above
end

function modding.is_pos_moveable(pos, width, height)
	local edge1 = {
		x = pos.x - (width + 0.2),
		y = pos.y,
		z = pos.z - (width + 0.2),
	}
	local edge2 = {
		x = pos.x + (width + 0.2),
		y = pos.y,
		z = pos.z + (width + 0.2),
	}
	local base_p = {x = pos.x, y = pos.y, z = pos.z}
	local top_p = {x = pos.x, y = pos.y + height, z = pos.z}
	for z = edge1.z, edge2.z do
		for x = edge1.x, edge2.x do
			base_p.x, base_p.z = pos.x + x, pos.z + z
			top_p.x, top_p.z = pos.x + x, pos.z + z
			local ray = minetest.raycast(base_p, top_p, false, false)
			for pointed_thing in ray do
				if pointed_thing.type == "node" then
					local name = get_node(pointed_thing.under).name
					if modding.get_node_def(name).walkable then
						return false
					end
				end
			end
		end
	end
	return true
end

local function is_blocked_thin(pos, height)
	local node
	local pos2 = {
		x = floor(pos.x + 0.5),
		y = floor(pos.y + 0.5) - 1,
		z = floor(pos.z + 0.5)
	}

	for _ = 1, height do
		pos2.y = pos2.y + 1
		node = minetest.get_node_or_nil(pos2)

		if not node
		or get_node_def(node.name).walkable then
			return true
		end
	end
	return false
end

function modding.is_blocked(pos, width, height)
	if width <= 0.5 then
		return is_blocked_thin(pos, height)
	end

	local p1 = {
		x = pos.x - (width + 0.2),
		y = pos.y,
		z = pos.z - (width + 0.2),
	}
	local p2 = {
		x = pos.x + (width + 0.2),
		y = pos.y + (height + 0.2),
		z = pos.z + (width + 0.2),
	}

	local node
	local pos2 = {}
	for z = p1.z, p2.z do
		pos2.z = z
		for y = p1.y, p2.y do
			pos2.y = y
			for x = p1.x, p2.x do
				pos2.x = x
				node = minetest.get_node_or_nil(pos2)

				if not node
				or get_node_def(node.name).walkable then
					return true
				end
			end
		end
	end
	return false
end

function modding.fast_ray_sight(pos1, pos2, water)
	local ray = minetest.raycast(pos1, pos2, false, water or false)
	local pointed_thing = ray:next()
	while pointed_thing do
		if pointed_thing.type == "node"
		and modding.get_node_def(pointed_thing.under).walkable then
			return false, vec_dist(pos1, pointed_thing.intersection_point), pointed_thing.ref, pointed_thing.intersection_point
		end
		pointed_thing = ray:next()
	end
	return true, vec_dist(pos1, pos2), false, pos2
end

local fast_ray_sight = modding.fast_ray_sight

function modding.sensor_floor(self, range, water)
	local pos = self.object:get_pos()
	local pos2 = vec_raise(pos, -range)
	local _, dist, node = fast_ray_sight(pos, pos2, water or false)
	return dist, node
end

function modding.sensor_ceil(self, range, water)
	local pos = vec_raise(self.object:get_pos(), self.height)
	local pos2 = vec_raise(pos, range)
	local _, dist, node = fast_ray_sight(pos, pos2, water or false)
	return dist, node
end

function modding.get_nearby_player(self, range)
	local pos = self.object:get_pos()
	if not pos then return end
	local stored = self._nearby_obj or {}
	local objects = (#stored > 0 and stored) or self:store_nearby_objects(range)
	for _, object in ipairs(objects) do
		if object:is_player()
		and modding.is_alive(object) then
			return object
		end
	end
end

function modding.get_nearby_players(self, range)
	local pos = self.object:get_pos()
	if not pos then return end
	local stored = self._nearby_obj or {}
	local objects = (#stored > 0 and stored) or self:store_nearby_objects(range)
	local nearby = {}
	for _, object in ipairs(objects) do
		if object:is_player()
		and modding.is_alive(object) then
			table.insert(nearby, object)
		end
	end
	return nearby
end

function modding.get_nearby_object(self, name, range)
	local pos = self.object:get_pos()
	if not pos then return end
	local stored = self._nearby_obj or {}
	local objects = (#stored > 0 and stored) or self:store_nearby_objects(range)
	for _, object in ipairs(objects) do
		local ent = modding.is_alive(object) and object:get_luaentity()
		if ent
		and object ~= self.object
		and not ent._ignore
		and ((type(name) == "table" and contains_val(name, ent.name))
		or ent.name == name) then
			return object
		end
	end
end

function modding.get_nearby_objects(self, name, range)
	local pos = self.object:get_pos()
	if not pos then return end
	local stored = self._nearby_obj or {}
	local objects = (#stored > 0 and stored) or self:store_nearby_objects(range)
	local nearby = {}
	for _, object in ipairs(objects) do
		local ent = modding.is_alive(object) and object:get_luaentity()
		if ent
		and object ~= self.object
		and not ent._ignore
		and ((type(name) == "table" and contains_val(name, ent.name))
		or ent.name == name) then
			table.insert(nearby, object)
		end
	end
	return nearby
end

modding.get_nearby_entity = modding.get_nearby_object
modding.get_nearby_entities = modding.get_nearby_objects

--------------------
-- Global Mob API --
--------------------

function modding.default_water_physics(self)
	local pos = self.stand_pos
	local stand_node = self.stand_node
	if not pos or not stand_node then return end
	local gravity = self._movement_data.gravity or -9.8
	local submergence = self.liquid_submergence or 0.25
	local drag = self.liquid_drag or 0.7

	if minetest.get_item_group(stand_node.name, "liquid") > 0 then -- In Liquid
		local vel = self.object:get_velocity()
		if not vel then return end

		self.in_liquid = stand_node.name

		if submergence < 1 then
			local mob_level = pos.y + (self.height * submergence)

			-- Find Water Surface
			local nodes = minetest.find_nodes_in_area_under_air(
				{x = pos.x, y = pos.y, z = pos.z},
				{x = pos.x, y = pos.y + 3, z = pos.z},
				"group:liquid"
			) or {}

			local surface_level = (#nodes > 0 and nodes[#nodes].y or pos.y + self.height + 3)
			surface_level = floor(surface_level + 0.9)

			local height_diff = mob_level - surface_level

			-- Apply Bouyancy
			if height_diff <= 0 then
				local displacement = clamp(abs(height_diff) / submergence, 0.5, 1) * self.width

				self.object:set_acceleration({x = 0, y = displacement, z = 0})
			else
				self.object:set_acceleration({x = 0, y = gravity, z = 0})
			end
		end

		-- Apply Drag
		self.object:set_velocity({
			x = vel.x * (1 - self.dtime * drag),
			y = vel.y * (1 - self.dtime * drag),
			z = vel.z * (1 - self.dtime * drag)
		})
	else
		self.in_liquid = nil

		self.object:set_acceleration({x = 0, y = gravity, z = 0})
	end
end

function modding.default_vitals(self)
	local pos = self.stand_pos
	local node = self.stand_node
	if not pos or node then return end

	local max_fall = self.max_fall or 3
	local in_liquid = self.in_liquid
	local on_ground = self.touching_ground
	local damage = 0

	-- Fall Damage
	if max_fall > 0
	and not in_liquid then
		local fall_start = self._fall_start or (not on_ground and pos.y)
		if fall_start
		and on_ground then
			damage = floor(fall_start - pos.y)
			if damage < max_fall then
				damage = 0
			else
				local resist = self.fall_resistance or 0
				damage = damage - damage * resist
			end
			fall_start = nil
		end
		self._fall_start = fall_start
	end

	-- Environment Damage
	if self:timer(1) then
		local stand_def = modding.get_node_def(node.name)
		local max_breath = self.max_breath or 0

		-- Suffocation
		if max_breath > 0 then
			local head_pos = {x = pos.x, y = pos.y + self.height, z = pos.z}
			local head_def = modding.get_node_def(head_pos)
			if head_def.groups
			and (minetest.get_item_group(head_def.name, "water") > 0
			or (head_def.walkable
			and head_def.groups.disable_suffocation ~= 1
			and head_def.drawtype == "normal")) then
				local breath = self._breath
				if breath <= 0 then
					damage = damage + 1
				else
					self._breath = breath - 1
					self:memorize("_breath", breath)
				end
			end
		end

		-- Burning
		local fire_resist = self.fire_resistance or 0
		if fire_resist < 1
		and minetest.get_item_group(stand_def.name, "igniter") > 0
		and stand_def.damage_per_second then
			damage = (damage or 0) + stand_def.damage_per_second * fire_resist
		end
	end

	-- Apply Damage
	if damage > 0 then
		self:hurt(damage)
		self:indicate_damage()
		if random(4) < 2 then
			self:play_sound("hurt")
		end
	end

	-- Entity Cramming
	if self:timer(5) then
		local objects = minetest.get_objects_inside_radius(pos, 0.2)
		if #objects > 10 then
			self:indicate_damage()
			self.hp = self:memorize("hp", -1)
			self:death_func()
		end
	end
end

function modding.drop_items(self)
	if not self.drops then return end
	local pos = self.object:get_pos()
	if not pos then return end

	local drop_def, item_name, min_items, max_items, chance, amount, drop_pos
	for i = 1, #self.drops do
		drop_def = self.drops[i]
		item_name = drop_def.name
		if not item_name then return end
		chance = drop_def.chance or 1

		if random(chance) < 2 then
			min_items = drop_def.min or 1
			max_items = drop_def.max or 2
			amount = random(min_items, max_items)
			drop_pos = {
				x = pos.x + random(-5, 5) * 0.1,
				y = pos.y,
				z = pos.z + random(-5, 5) * 0.1
			}

			local item = minetest.add_item(drop_pos, ItemStack(item_name .. " " .. amount))
			if item then
				item:add_velocity({
					x = random(-2, 2),
					y = 1.5,
					z = random(-2, 2)
				})
			end
		end
	end
end

function modding.basic_punch_func(self, puncher, tflp, tool_caps, dir)
	if not puncher then return end
	local tool
	local tool_name = ""
	local add_wear = false
	if puncher:is_player() then
		tool = puncher:get_wielded_item()
		tool_name = tool:get_name()
		add_wear = not minetest.is_creative_enabled(puncher:get_player_name())
	end
	if (self.immune_to
	and contains_val(self.immune_to, tool_name)) then
		return
	end
	local damage = 0
	local armor_grps = self.object:get_armor_groups() or self.armor_groups or {}
	for group, val in pairs(tool_caps.damage_groups or {}) do
		local dmg_x = tflp / (tool_caps.full_punch_interval or 1.4)
		damage = damage + val * clamp(dmg_x, 0, 1) * ((armor_grps[group] or 0) / 100.0)
	end
	if damage > 0 then
		local dist = vec_dist(self.object:get_pos(), puncher:get_pos())
		dir.y = 0.2
		if self.touching_ground then
			local power = clamp((damage / dist) * 8, 0, 8)
			self:apply_knockback(dir, power)
		end
		self:hurt(damage)
	end
	if add_wear then
		local wear = floor((tool_caps.full_punch_interval / 75) * 9000)
		tool:add_wear(wear)
		puncher:set_wielded_item(tool)
	end
	if random(2) < 2 then
		self:play_sound("hurt")
	end
	if (tflp or 0) > 0.5 then
		self:play_sound("hit")
	end
	self:indicate_damage()
end

local path = minetest.get_modpath("modding")

dofile(path.."/mob_meta.lua")

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

-- Add this to your mob API file

local BEHAVIORS = {"follow", "stay", "wander"}

local function get_distance(pos1, pos2)
    return vector.distance(pos1, pos2)
end

local function get_direction(pos1, pos2)
    return vector.direction(pos1, pos2)
end

local function toggle_mob_behavior(self, player)
    if not player:get_player_control().sneak then
        return
    end

    local wielded_item = player:get_wielded_item()
    if wielded_item:get_name() ~= "default:sword_steel" then
        return
    end

    self.behavior = self.behavior or 1
    self.behavior = (self.behavior % #BEHAVIORS) + 1

    local new_behavior = BEHAVIORS[self.behavior]
    minetest.chat_send_player(player:get_player_name(), "Mob behavior set to: " .. new_behavior)

    if new_behavior == "follow" then
        self.order = "follow"
        self.following = player
    elseif new_behavior == "stay" then
        self.order = "stand"
        self.following = nil
    else  -- wander
        self.order = "wander"
        self.following = nil
    end
end

local BEHAVIORS = {"follow", "stay", "wander"}

function get_distance(pos1, pos2)
    return vector.distance(pos1, pos2)
end

function get_direction(pos1, pos2)
    return vector.direction(pos1, pos2)
end

function toggle_mob_behavior(self, player)
    if not player:get_player_control().sneak then
        return
    end

    local wielded_item = player:get_wielded_item()
    if wielded_item:get_name() ~= "default:sword_steel" then
        return
    end

    self.behavior = self.behavior or 1
    self.behavior = (self.behavior % #BEHAVIORS) + 1

    local new_behavior = BEHAVIORS[self.behavior]
    minetest.chat_send_player(player:get_player_name(), "Mob behavior set to: " .. new_behavior)

    if new_behavior == "follow" then
        self.order = "follow"
        self.following = player
    elseif new_behavior == "stay" then
        self.order = "stand"
        self.following = nil
    else  -- wander
        self.order = "wander"
        self.following = nil
    end
end


function modding.mob_follow(self, player)
    local pos = player:get_pos()
    local mob_pos = self.object:get_pos()
    local distance = get_distance(mob_pos, pos)
    
    if distance > 3 then
        local dir = get_direction(mob_pos, pos)
        local speed = (distance > 10) and self.run_velocity or self.walk_velocity
        self.object:set_velocity(vector.multiply(dir, speed))

        -- Simple pathfinding: jump if there's an obstacle
        local front_node_pos = vector.add(mob_pos, vector.multiply(dir, 1))
        local front_node = minetest.get_node(front_node_pos)
        if minetest.registered_nodes[front_node.name].walkable then
            self.object:set_velocity({x = dir.x * speed, y = self.jump_height, z = dir.z * speed})
        end
    else
        self.object:set_velocity({x=0, y=0, z=0})
    end
end

function modding.mob_stay(self)
    self.object:set_velocity({x=0, y=0, z=0})
end

function modding.mob_wander(self, dtime)
    self.wander_timer = self.wander_timer + dtime
    if self.wander_timer > 10 or not self.wander_target then
        self.wander_timer = 0
        local pos = self.object:get_pos()
        self.wander_target = {
            x = pos.x + math.random(-self.wander_distance, self.wander_distance),
            y = pos.y,
            z = pos.z + math.random(-self.wander_distance, self.wander_distance)
        }
    end

    local mob_pos = self.object:get_pos()
    local dir = get_direction(mob_pos, self.wander_target)
    local distance = get_distance(mob_pos, self.wander_target)

    if distance > 1 then
        self.object:set_velocity(vector.multiply(dir, self.walk_velocity))

        -- Simple pathfinding: jump if there's an obstacle
        local front_node_pos = vector.add(mob_pos, vector.multiply(dir, 1))
        local front_node = minetest.get_node(front_node_pos)
        if minetest.registered_nodes[front_node.name].walkable then
            self.object:set_velocity({x = dir.x * self.walk_velocity, y = self.jump_height, z = dir.z * self.walk_velocity})
        end
    else
        self.wander_target = nil
        self.object:set_velocity({x=0, y=0, z=0})
    end
end