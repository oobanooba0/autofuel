--fuck it, its all under control.

local flib_table = require("__flib__/table")

local autofuel = {}

--- init section
local function make_storage()

  if not storage.burners then
    storage.burners = {} end
  if not storage.burner_from_k then
    storage.burner_from_k = {} end

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

---equipment insert event

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
		autofuel.on_tick()
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
    local burner_list = storage.burners
    local entity = grid.entity_owner
    local inventory
    if entity.type == "spider-vehicle" then
      inventory = entity.get_inventory(defines.inventory.spider_trunk)
    elseif entity.type == "car" then --no idea if this is correct, will probably never check.
      inventory = entity.get_inventory(defines.inventory.car_trunk)
    end
    if not inventory then return end --if we got no inventory on our vehicle, we cant autofuel its grid. so we give up.
    table.insert(burner_list,{--storing this, because tracking it down later would be way more complicated.
      burner = equipment.burner,
      entity = entity,
      inventory = inventory,
    })
  end

  function autofuel.on_tick()
    storage.burner_from_k = flib_table.for_n_of(
		  storage.burners, storage.burner_from_k, 1,
      function(equipment,index)
        autofuel.fuel_burner(equipment,index)
      end
    )
    end

  function autofuel.fuel_burner(equipment,index)
    if not equipment.burner.valid then storage.burners[index] = nil return
      --game.print("remove invalid burner")
    end
    if not equipment.entity.valid then storage.burners[index] = nil return
      --game.print("remove burner from invalid entity")
    end
    local burner = equipment.burner
    local trunk = equipment.inventory
    --refuel the burner
    local burner_input = burner.inventory
    if not burner_input.is_full() then
      local trunk_contents = trunk.get_contents()
      for _,trunk_item in pairs(trunk_contents) do  
        if burner.fuel_categories[prototypes.item[trunk_item.name].fuel_category] then --precaching compatible fuels would probably be faster, but i dont care.
          local item_room = burner_input.get_insertable_count(trunk_item)
          local item_quantity = trunk_item.count
          local transfer_limit = math.min(item_quantity,item_room)
          if transfer_limit > 0 then
            local transfer = {name = trunk_item.name, count = transfer_limit, quality = trunk_item.quality}
            trunk.remove(transfer)
            burner_input.insert(transfer)
          end
        end
      end
    end
    --dump the junk in de trunk
    local burner_output = burner.burnt_result_inventory
    if burner_output then
      local burner_out = burner_output.get_contents()
      for _,burnt_fuel in pairs(burner_out) do
        local item_room = trunk.get_insertable_count(burnt_fuel)
        local item_quantity = burnt_fuel.count
        local transfer_limit = math.min(item_quantity,item_room)
        if transfer_limit > 0 then
          local transfer = {name = burnt_fuel.name, count = transfer_limit, quality = burnt_fuel.quality}
          burner_output.remove(transfer)
          trunk.insert(transfer)
        end
      end
    end
  end

return autofuel