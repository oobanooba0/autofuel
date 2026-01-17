--fuck it, its all under control.

local flib_table = require("__flib__/table")

local autofuel = {}

--- init section
local function make_storage()
  if not storage.burners then
    storage.burners = {} end
  if not storage.burner_from_k then
    storage.burner_from_k = {} end
  if not storage.player_grids then
    storage.player_grids = {} end
end

script.on_init(function()
  make_storage()
end)

script.on_configuration_changed(function()
  make_storage()
end)

---on build event
local filters = {{filter = "vehicle", mode = "or"}}


script.on_event(
  defines.events.on_built_entity,
  function(event)
    autofuel.scan_grid(event.entity)
  end,filters
)

script.on_event(
  defines.events.on_robot_built_entity,
  function(event)
    autofuel.scan_grid(event.entity)
  end,filters
)

script.on_event(
  defines.events.on_space_platform_built_entity,
  function(event)
    autofuel.scan_grid(event.entity)
  end,filters
)

script.on_event(
  defines.events.script_raised_built,
  function(event)
    autofuel.scan_grid(event.entity)
  end,filters
)

script.on_event(
  defines.events.script_raised_revive,
  function(event)
    autofuel.scan_grid(event.entity)
  end,filters
)

script.on_event(
  defines.events.on_entity_cloned,
  function(event)
    autofuel.scan_grid(event.entity)
  end,filters
)

--equipment management
script.on_event(defines.events.on_equipment_inserted,
	function(event)
		autofuel.equipment_inserted(event)
	end
)

--- on tick
script.on_event(
	defines.events.on_tick,
	function(event)
		autofuel.on_tick(event.tick)
	end
)

----the part where the mod does something

--equipment add/remove events
  --this happens when any vehicle entity is placed
  function autofuel.scan_grid(entity) --in the event that a vehicle is placed with burner generators in its inventory, we have to check.
    if not entity.valid or not entity.grid or not entity.grid.valid then return end
    local grid = entity.grid
    for _,equipment in pairs(grid.equipment) do
      if equipment.burner then
        local fake_event = {
          grid = grid,
          equipment = equipment
        }
        autofuel.equipment_inserted(fake_event) --sketchy as hell to do this, but it works and saves me from having the same code twice
      end
    end
  end

  function autofuel.equipment_inserted(event)
    --gather basic information
    local equipment = event.equipment
    local grid = event.grid
    if not grid.valid or not equipment.valid or not equipment.burner then return end
    --handle our autofuel list
    if not storage.burners then storage.burners = {} end
    local entity = grid.entity_owner
    if not entity then return end
    local inventory
    if entity.type == "spider-vehicle" then
      inventory = entity.get_inventory(defines.inventory.spider_trunk)
    elseif entity.type == "car" then --no idea if this is correct, will probably never check.
      inventory = entity.get_inventory(defines.inventory.car_trunk)
    end
    if not inventory then return end --if we got no inventory on our vehicle, we cant autofuel its grid. so we give up.
    --add our equipment to the list of equipments we shall check
    local burner_list = storage.burners
    table.insert(burner_list,{--storing this, because tracking it down later would be way more complicated.
      burner = equipment.burner,
      entity = entity,
      inventory = inventory,
    })
  end

  function autofuel.on_tick(tick)
    --do vehicles
    storage.burner_from_k = flib_table.for_n_of(
		  storage.burners, storage.burner_from_k, 1,
      function(equipment,index)
        autofuel.vehichle_burner(equipment,index)
      end
    )
    --do players
    local players = game.connected_players
    if #players == 0 then return end --in case no players are in the game.
    local player_index = math.fmod(tick,#players)+1 --basically, a dumbass way to sequentially pick one of the connected players to do a check on
    local player = game.connected_players[player_index]
    autofuel.fuel_player(player)
  end

  function autofuel.vehichle_burner(equipment,index)
    if not equipment.burner.valid then storage.burners[index] = nil return
      --game.print("remove invalid burner")
    end
    if not equipment.entity.valid then storage.burners[index] = nil return
      --game.print("remove burner from invalid entity")
    end
    autofuel.fuel_burner(equipment.burner,equipment.inventory)
  end

  function autofuel.fuel_player(player)
    local armor_slot = player.get_inventory(defines.inventory.character_armor)
    if not armor_slot or not armor_slot[1] or not armor_slot[1].valid_for_read or not armor_slot[1].grid then return end
    local grid = armor_slot[1].grid
    local inventory = player.get_inventory(defines.inventory.character_main)
    for _,equipment in pairs(grid.equipment) do
      if equipment.burner then
        if autofuel.fuel_burner(equipment.burner,inventory) then return end
      end
    end
  end

  function autofuel.fuel_burner(burner,trunk)
    --refuel the burner
    local burner_input = burner.inventory
    local took_action = false
    if not burner_input.is_full() then
      if autofuel.transfer(trunk,burner_input) then
        took_action = true
      elseif burner_input.find_empty_stack() then--in case the transfer moved no items, we need to know if its because the slots were occupied by items that it cant stack onto, or if its actually empty.
        took_action = true
      end

    end
    --dump the junk in de trunk
    local burner_output = burner.burnt_result_inventory
    if burner_output and not burner_output.is_empty() then
      if autofuel.transfer(burner_output,trunk) then
        took_action = true
      end
    end
    return took_action end

  function autofuel.transfer(source,destination)--transfers items into an inventory like shift clicking, the first successful attempt quick ends the script.
    --script from nbcss, then modified beyond recognition
    local v,empty_stack = source.find_empty_stack() --finds the slot number of the first empty, unfiltered slot. This will be the highest slot number we check.
    for i = 1, empty_stack or #source do
      local source_stack = source[i]
      if source_stack.valid_for_read and source_stack.type == "item" then
        local transfered = destination.insert(source_stack)
        source_stack.count = source_stack.count - transfered
        if transfered > 0 then return true end --if we move any items at all, just quit the script. This will make it so that this function finishes early if it successfully moves any items.
      end
    end
  end

return autofuel