-- Initialize mod storage to keep track of player spawn points and bed ownership
local mod_storage = core.get_mod_storage()

-- Check if the original bed respawn system is enabled (must be disabled for this mod to work)
local original_bed_respawn_enabled = core.settings:get_bool("enable_bed_respawn", true)

-- Retrieve custom messages from the mod's configuration file or use defaults
local SET_SPAWN_MESSAGE = core.settings:get("spawnpoint_msg") or "Your spawn point is now set"
local BED_TAKEN_OVER_MESSAGE = core.settings:get("bed_detroyed_msg") or "Your bed has been taken over by another player"

-- Key suffix used to track if a player has died
local DIED_FLAG_KEY_SUFFIX = "_died"

-- List of bed nodes to override (starts with basic beds and expands if mods are present)
local bed_nodes = {
    "beds:bed",
    "beds:fancy_bed",
  }
-- Function to check if a mod is loaded by its name
local function is_mod_active(mod_name)
  return core.get_modpath(mod_name) ~= nil
end

-- Add colorful beds to the list if the mod is active
if is_mod_active("colorful_beds") then
  for node_name, _ in pairs(core.registered_nodes) do
    if string.find(node_name, "^colorful_beds:") and string.find(node_name, "bed") then
      table.insert(bed_nodes, node_name)
      end
  end
end

-- Only proceed if the original bed respawn is disabled
if not original_bed_respawn_enabled then
  -- Iterate through each bed node to override their behavior
  for _, bed_node in ipairs(bed_nodes) do
    local original_on_right_click = core.registered_nodes[bed_node].on_rightclick
    local original_after_dig_node = core.registered_nodes[bed_node].after_dig_node

    -- Define new bed functionality
    local updated_bed_definition = {
      on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        local player_name = player:get_player_name()
        local stored_bed_pos = mod_storage:get_string(player_name)
        local current_bed_pos_str = core.pos_to_string(pos)
        local is_valid_spawn = false

        -- Check if the bed is already claimed by another player
        if stored_bed_pos ~= "" and stored_bed_pos == current_bed_pos_str then
          local current_owner = mod_storage:get_string(stored_bed_pos) or ""
          if current_owner ~= "" and current_owner ~= player_name then
            -- Notify previous owner and transfer ownership
            mod_storage:set_string(current_owner, "")
            mod_storage:set_string(stored_bed_pos, "")
            core.chat_send_player(current_owner, BED_TAKEN_OVER_MESSAGE)
            is_valid_spawn = true
          end
      else
          is_valid_spawn = true
      end

        -- Update storage with new spawn point if valid
        if is_valid_spawn then
          mod_storage:set_string(player_name, current_bed_pos_str)
          mod_storage:set_string(current_bed_pos_str, player_name)
          core.chat_send_player(player_name, SET_SPAWN_MESSAGE)
        end

        -- Call original bed functionality if it exists
        if original_on_right_click then
          original_on_right_click(pos, node, player, itemstack, pointed_thing)
        end
      end,

      after_dig_node = function(pos, old_node, oldmetadata, digger)
        local digger_name = digger:get_player_name()
        local bed_pos_str = core.pos_to_string(pos)
        local current_owner = mod_storage:get_string(bed_pos_str) or ""

        -- Check if the bed is owned by someone else
        if current_owner ~= "" and current_owner ~= digger_name then
          core.chat_send_player(current_owner, BED_TAKEN_OVER_MESSAGE)
        end

        -- Clear storage entries for the bed and owner
        mod_storage:set_string(current_owner, "")
        mod_storage:set_string(bed_pos_str, "")

        -- Call original after_dig_node if it exists
        if original_after_dig_node then
          original_after_dig_node(pos, old_node, oldmetadata, digger)
        end
    end
    }

    -- Apply the updated definition to the bed node
    core.override_item(bed_node, updated_bed_definition)
  end
if not aio_back_to_bed.deathscreen then
    core.show_death_screen = function(player, reason) end
end

  -- Track when a player dies to determine respawn location
  core.register_on_dieplayer(function(player)
    local player_name = player:get_player_name()
    mod_storage:set_string(player_name .. DIED_FLAG_KEY_SUFFIX, "true")
  end)

  -- Handle player respawn to use their last bed spawn point
  core.register_on_respawnplayer(function(player)
    local player_name = player:get_player_name()
    local died_flag = mod_storage:get_string(player_name .. DIED_FLAG_KEY_SUFFIX) or ""
    if died_flag == "true" then
      mod_storage:set_string(player_name .. DIED_FLAG_KEY_SUFFIX, "false") -- Reset flag

      -- Retrieve stored bed position and set player's position
      local bed_position = core.string_to_pos(mod_storage:get_string(player_name))
      if bed_position then
        player:set_pos(bed_position)
        return true -- Indicate custom respawn handled
        end
      end
  end)
end
