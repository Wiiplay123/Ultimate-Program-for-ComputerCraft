--[[

INSTRUCTIONS:

Turtle must have pickaxe on right side, and crafting table on left side.
Place single chests in front of and on top of turtle.
Place a single hopper to the left of front chest.
Place a furnace under the turtle.
Place a hopper behind furnace.
Place a single redstone dust in front of the furnace.
Place a single pressure plate in front of the redstone dust.
Add to instructions as more requirements are added.


VALUE DOCUMENTATION:

minFuel (number): Minimum fuel allowed in furnace before refuelling
chests (table): External Chest Cache
turtleInventory (table): Internal Inventory Cache
inventorySize (number): Internal Inventory Size
inv (number): Main Buffer Chest Size
slots (table): List of crafting slots
craftingRecipes (table): List of crafting recipes. Key is item name to be crafted, value is a table of either {itemCount,(1-9 itemName of items to place in crafting grid)} or {itemCount, {Item Names}, {Keys to previous item name table}}.
furnaceRecipes (table): List of furnace recipes. Key is resulting item name, value is item name to be smelted/cooked.
miners (number): Amount of active turtle miners


FUNCTION DOCUMENTATION:

notCrafting(slot: number) (Returns boolean): Returns whether or not (slot) is a crafting slot.
turnAround() (Returns nil): Does turtle.turnLeft() twice.
updateInternalInventory([slot: number]) (Returns nil): Updates internal inventory cache table (turtleInventory) slot (slot), or if (slot) is absent, updates entire table.
checkUp(chestIndex: number, [itemName: string, itemCount: number]) (Returns nil if itemName and itemCount exist, returns table containing chest contents otherwise) return: Updates chests[chestIndex] with the contents of the chest currently above the turtle. If itemName and itemCount are BOTH present, will only update for places that the items could possibly be placed in since the last cache update. (Used IMMEDIATELY after dropping anything into a chest)
itemCount(itemName: string) (Returns number): Returns combined amount of (itemName) in both (turtleInventory) and (chests).
checkIfEmptyInventory() (Returns boolean): Checks if turtle's internal inventory is empty. (not counting crafting slots)
emptyBufferChest() (Returns boolean): Checks if buffer chest is empty.
clearInventory([dontClearOne: boolean]) (Returns nil): Puts entire internal inventory (Unless dontClearOne is true, in which case everything except slot 1) into chests, and changes (turtleInventory) and (chests) contents to match. 
nearestBuffer([itemName: string]) (Returns number): Returns lowest internal inventory slot that can hold (itemName), or the lowest empty slot if itemName is not set.
stockInventory([dontClearOne: boolean]) (Returns nil): Fills inventory with contents of buffer chest. If inventory is full, calls clearInventory([dontClearOne: boolean]) to clear inventory. Repeats until buffer chest is empty.
pullItemFromStorage(itemName: string, itemCount: number) (Returns number): Pulls item from external chest inventory if item is not already in internal inventory. Returns and selects slot number item is in once item is in internal inventory.
checkTotalInventoryCapacity() (Returns number): Returns amount of empty slots left in external chest inventory.
canCraft(itemName: string, itemCount: number) (Returns boolean): Returns whether or not (itemCount) of (itemName) can be crafted using the contents of the internal and external inventories.
minStack(coalAvailable: number, coalInFuelSlot: number) (Returns number): Returns the lowest of (coalAvailable) or (64 - coalInFuelSlot) (The amount of coal that can be placed into the furnace's fuel slot).
mergeStack(itemName: string) (Returns nil): Merges all stacks of (itemName) in internal inventory to the lowest amount of stacks possible.
notInList(list: table, string: string) (Returns boolean): Returns true if (string) is not in (list), false otherwise.
mergeStacks() (Returns nil): Merges all stacks in internal inventory to the lowest amount of stacks possible using mergeStack(itemName: string).
checkFurnaceFuel() (Returns nil): Refuels furnace below turtle if fuel is below (minFuel).
clearCrafting() (Returns nil): Clears crafting slots.
craft(itemName: string, itemCount: number) (Returns boolean): Puts (itemCount) of (itemName) into lowest available slot. If items are already available in internal inventory, will select slot. If not, will use pullItemFromStorage(itemName, itemCount) to pull more items in. If there are not enough items in external inventory, will craft the required items.
pushItemToStorage(slot: number) (Returns nil): Puts items in (slot) into external inventory.
updateAllChests()
digAndUpdate(direction: string) (Returns nil): Direction can be nil, "up", or "down". Digs a block if it exists, and puts it in the inventory cache. Selects previously selected slot afterwards.
makePickaxe(i: number) (Returns nil): Helper function for addNewChest(), crafts pickaxe if one isn't already available and then moves forward.
addNewMiner() (Returns nil): Adds new miner and increments (miners) if successful
addNewChest() (Returns nil): Adds new external chest to external chest inventory and updates (chests) to match.
getItemName() (Returns (string, number) or (string) or (nil)): Returns "exit"
canCraftInstance(itemRecipe: table, itemCount: number) (Returns boolean): Returns whether or not (itemCount) of item with (itemRecipe) recipe can be made. Helper function to canCraft() and craft().
]]
if peripheral == nil then
	error("Program is only designed for ComputerCraft.",0)
end
local cautious = true
local makeMiners = false
local ironChests = true
local checkingFuel = false
local minFuel = 5
local minTurtleFuel = 1600
local inventorySize = 16
--local turtleInventory = {}
turtleInventory = {}
--local chests = {}
chests = {}
local inv = peripheral.call("front","getInventorySize")
if inv == nil then
	repeat
		turtle.turnLeft()
		inv = peripheral.call("front","getInventorySize")
	until inv
end
local slots = {1,2,3,5,6,7,9,10,11}
local craftingRecipes = {
["minecraft:planks"] = {4,"minecraft:log"},
["Natura:planks"] = {4,"Natura:tree"},
["minecraft:stick"] = {4,"minecraft:planks","","","minecraft:planks"},
["IronChest:woodIronUpgrade"] = {{1,{"minecraft:iron_ingot","minecraft:planks"},{1,1,1,1,2,1,1,1,1}},{1,{"minecraft:iron_ingot","Natura:planks"},{1,1,1,1,2,1,1,1,1}}},
["IronChest:ironGoldUpgrade"] = {1,{"minecraft:gold_ingot","minecraft:iron_ingot"},{1,1,1,1,2,1,1,1,1}},
["IronChest:goldDiamondUpgrade"] = {1,{"minecraft:glass","minecraft:diamond","minecraft:gold_ingot"},{1,1,1,2,3,2,1,1,1}},
["minecraft:glass_pane"] = {16,{"minecraft:glass"},{1,1,1,1,1,1}},
["ComputerCraft:CC-Computer"] = {1,{"minecraft:stone","minecraft:redstone","minecraft:glass_pane"},{1,1,1,1,2,1,1,3,1}},
["ComputerCraft:CC-Turtle"] = {1,{"minecraft:iron_ingot","ComputerCraft:CC-Computer","minecraft:chest"},{1,1,1,1,2,1,1,3,1}},
["ComputerCraft:CC-Peripheral"] = {1,{"minecraft:stone","minecraft:redstone"},{1,1,1,1,2,1,1,2,1}},
["minecraft:chest"] = {{1,{"Natura:planks"},{1,1,1,1,0,1,1,1,1}},{1,{"minecraft:planks"},{1,1,1,1,0,1,1,1,1}}},
["minecraft:furnace"] = {1,{"minecraft:cobblestone"},{1,1,1,1,0,1,1,1,1}},
["minecraft:enchanting_table"] = {1,{"minecraft:book","minecraft:diamond","minecraft:obsidian"},{0,1,0,2,3,2,3,3,3}},
["tile.chickenchunkloader|0"] = {1,{"minecraft:ender_pearl","minecraft:gold_ingot","minecraft:enchanting_table"},{0,1,0,2,2,2,2,3,2}},
["tile.chickenchunkloader|1"] = {10,{"minecraft:ender_pearl","tile.chickenchunkloader|0"},{1,1,1,1,2,1,1,1,1}},
["tile.computercraft:wireless_modem"] = {1,{"minecraft:stone","minecraft:ender_pearl"},{1,1,1,1,2,1,1,1,1}},
["PeripheralsPlusPlus:chunkLoaderUpgrade"] = {1,"tile.chickenchunkloader|1","tile.computercraft:wireless_modem"},
["minecraft:diamond_pickaxe"] = {1,{"minecraft:diamond","minecraft:stick"},{1,1,1,0,2,0,0,2}},
["minecraft:iron_pickaxe"] = {1,{"minecraft:iron_ingot","minecraft:stick"},{1,1,1,0,2,0,0,2}},
--["ComputerCraft:CC-TurtleExpanded"] = {1,"minecraft:diamond_pickaxe","ComputerCraft:CC-Turtle","PeripheralsPlusPlus:chunkLoaderUpgrade"},
["ComputerCraft:CC-TurtleExpanded"] = {1,"minecraft:diamond_pickaxe","ComputerCraft:CC-Turtle"},
--["usefulDNS:PStone"] = {1,{"minecraft:redstone","minecraft:glowstone_dust","usefulDNS:DecaNySodiumGem"},{1,2,1,2,3,2,1,2,1}},
--["ProjectE:item.pe_philosophers_stone"] = {1,{"minecraft:redstone","minecraft:glowstone_dust","minecraft:diamond"},{1,2,1,2,3,2,1,2,1}},
--["minecraft:ender_pearl"] = {1,{"usefulDNS:PStone","minecraft:iron_ingot"},{1,2,0,2,2,0,2}},
--["minecraft:diamond"] = {1,{"usefulDNS:PStone","minecraft:gold_ingot"},{1,2,0,2,2,0,2}},
--["minecraft:sand"] = {1,"usefulDNS:PStone","minecraft:cobblestone","","","minecraft:cobblestone"},
["minecraft:stone_slab"] = {6,{"minecraft:stone"},{1,1,1}},
["minecraft:hopper"] = {1,{"minecraft:iron_ingot","minecraft:chest"},{1,0,1,1,2,1,0,1,0}},
["ComputerCraft:pocketComputer"] = {1,{"minecraft:gold_ingot","minecraft:golden_apple","minecraft:glass_pane"},{1,1,1,1,2,1,1,3,1}},
["minecraft:golden_apple"] = {1,{"minecraft:gold_ingot","minecraft:apple"},{1,1,1,1,2,1,1,1,1}},
["OpenPeripheral:pim"] = {1,{"minecraft:obsidian","minecraft:chest","minecraft:redstone"},{1,1,1,2,3,2}}
}
local furnaceRecipes = {
	["minecraft:stone"] = "minecraft:cobblestone",
	["minecraft:iron_ingot"] = "minecraft:iron_ore",
	["minecraft:gold_ingot"] = "minecraft:gold_ore",
	["minecraft:glass"] = "minecraft:sand",
	["minecraft:cooked_chicken"] = "minecraft:chicken",
	["minecraft:cooked_porkchop"] = "minecraft:porkchop",
	["minecraft:cooked_beef"] = "minecraft:beef",
	["minecraft:cooked_fished"] = "minecraft:fish"
}

function notCrafting(s)
	return s > 11 or s == 4 or s == 8
end

function turnAround()
	turtle.turnLeft()
	turtle.turnLeft()
end

function checkFuel()
	if not checkingFuel then
		checkingFuel = true
		local fuel = turtle.getFuelLevel()
		local count = itemCount("minecraft:coal")
		if fuel ~= "unlimited" and fuel < minTurtleFuel and count > 0 then
			local slot = pullItemFromStorage("minecraft:coal",(count >= 64 and 64 or itemCount("minecraft:coal")))
			if slot > 0 then
				if turtle.refuel(64) then
					turtleInventory[slot] = nil
				else
					updateInternalInventory()
				end
			end
		end
		checkingFuel = false
	end
end

function updateInternalInventory(n)
	if n then
		turtleInventory[n] = turtle.getItemDetail(n)
		if turtleInventory[n] then
			turtleInventory[n].maxSize = turtle.getItemSpace(n) + turtleInventory[n].count
		end
	else
		turtleInventory = {}
		for i = 4, inventorySize do
			if notCrafting(i) then
				turtleInventory[i] = turtle.getItemDetail(i)
				if turtleInventory[i] then
					turtleInventory[i].maxSize = turtle.getItemSpace(i) + turtleInventory[i].count
				end
			end
		end
	end
end

function checkUp(ix,id,count)
	if chests and ix and ix <= #chests then
		local oldSize = 0
		if ix and id and chests[ix] and chests[ix]["stacks"] and count then
			oldSize = chests[ix]["size"]
			chests[ix].size = peripheral.call("top","getInventorySize")
		end
		if (oldSize == chests[ix]["size"]) and id and count then
			local cacheCount = 0
			for i = 1, chests[ix]["size"] do
				if not chests[ix]["stacks"][i] or chests[ix]["stacks"][i].id == id then
					local oldSlot = (chests[ix]["stacks"][i] or {id = "", qty = 0})
					chests[ix]["stacks"][i] = peripheral.call("top","getStackInSlot",i)
					if chests[ix]["stacks"][i] and (oldSlot.id == chests[ix]["stacks"][i].id or oldSlot.qty == 0) then
						cacheCount = cacheCount + chests[ix]["stacks"][i].qty - oldSlot.qty
						if cacheCount >= count then
							break
						end
					end
				end
			end
		else
			chests[ix] = checkUp()
		end
	else
		local stacks = {}
		local size = peripheral.call("top","getInventorySize")
		if size then
			for i = 1, size do
				stacks[i] = peripheral.call("top","getStackInSlot",i)
			end
			return {["stacks"] = stacks,["size"] = size}
		else
			return false
		end
	end
end

function itemCount(id)
	local count = 0
	for i = 4, inventorySize do
		if notCrafting(i) then
			local slot = turtleInventory[i]
			if slot and slot.name == id then
				count = count + slot.count
			end
		end
	end
	for i = 1, #chests do
		for o, v in pairs(chests[i]["stacks"]) do
			if v.id == id then
				count = count + v.qty
			end
		end
	end
	return count
end

function checkIfEmptyInventory()
	for i = 1, inventorySize do
		if turtle.getItemCount(i) > 0 then
			return false
		end
	end
	return true
end

function emptyBufferChest()
	for i = 1, inv do
		if peripheral.call("front","getStackInSlot",i) then
			return false
		end
	end
	return true
end

function clearInventory(dontClearOne)
	printTitle("Ultimate Program Running","Clearing Inventory")
	checkFuel()
	local chestz = 0
	local lastSlot = (dontClearOne and 2 or 1)
	if #chests == 1 then
		for i = (dontClearOne and 2 or 1), inventorySize do
			local inspect = turtle.getItemDetail(i)
			if inspect then
				turtle.select(i)
				if not turtle.dropUp() then
					break
				end
				checkUp(1,inspect.name,inspect.count)
			end
		end
	else
		for i = 1, #chests do
			for p = lastSlot, inventorySize do
				local detail = turtle.getItemDetail(p)
				if detail then
					turtle.select(p)
					if not turtle.dropUp() then
						updateInternalInventory()
						lastSlot = p
						chests[i] = checkUp()
						break
					end
					checkUp(i,detail.name,detail.count)
					updateInternalInventory(p)
				end
			end
			if i < #chests and not ((lastSlot == inventorySize) or checkIfEmptyInventory()) then
				if i == 1 then
					turtle.turnRight()
				end
				forward()
				forward()
				chestz = chestz + 1
			end
		end
		for i = 1, chestz do
			chests[chestz + 2 - i] = checkUp()
			repeat until back()
			repeat until back()
		end
		if chestz > 0 then
			turtle.turnLeft()
		end
	end
	updateInternalInventory()
end

function nearestBuffer(id)
	for i = 4, inventorySize do
		if notCrafting(i) and (not turtleInventory[i] or (turtleInventory[i].name == id and turtleInventory[i].count < turtleInventory[i].maxSize)) then
			return i
		end
	end
	return 0
end

function stockInventory(dontClearOne)
	updateInternalInventory()
	local slot = turtle.getSelectedSlot()
	local selecting = false
	repeat
		--printTitle("Ultimate Program Running","Checking front chest")
		local breaking = false
		local s = false
		repeat
			if not emptyBufferChest() then
				turtle.select(1)
				selecting = true
			else
				break
			end
			if not turtle.suck() then
				break
			else
				s = true
			end
		until emptyBufferChest()
		updateInternalInventory()
		if s then clearCrafting() end
		if slotsLeft() < 4 or nearestBuffer() == 0 then
			clearInventory(dontClearOne)
			updateInternalInventory()
		end
	until emptyBufferChest()
	if selecting then
		turtle.select(slot)
	end
end

function pullItemFromStorage(id,count)
	checkFuel()
	local allTotal = 0
	local intoSlot = 0
	for i = 1, inventorySize do
		if notCrafting(i) then
			local tempSlot = turtleInventory[i]
			if tempSlot and tempSlot.name == id then
				if intoSlot == 0 then
					allTotal = allTotal + turtleInventory[i].count
					intoSlot = i
					turtle.select(intoSlot)
				else
					turtle.select(i)
					allTotal = allTotal + turtleInventory[i].count
					turtle.transferTo(intoSlot)
					if turtleInventory[intoSlot].count + turtleInventory[i].count > turtleInventory[intoSlot].maxSize then
						turtleInventory[i].count = turtleInventory[i].count - (turtleInventory[intoSlot].maxSize - turtleInventory[intoSlot].count)
						turtleInventory[intoSlot].count = turtleInventory[intoSlot].maxSize
					else
						turtleInventory[intoSlot].count = turtleInventory[intoSlot].count + turtleInventory[i].count
						turtleInventory[i] = nil
					end
				end
				if allTotal >= count then
					turtle.select(intoSlot)
					return intoSlot
				end
			end
		end
	end
	if intoSlot == 0 then
		repeat
			intoSlot = nearestBuffer(id)
			if intoSlot == 0 then
				stockInventory()
			end
		until intoSlot > 0
	end
	local chestTotal = {}
	local moves = 0
	local needsToMove = false
	for i = 1, #chests do
		chestTotal[i] = 0
		for o, p in pairs(chests[i]["stacks"]) do
			if p.id == id then
				allTotal = allTotal + p.qty
				chestTotal[i] = chestTotal[i] + p.qty
				if i > 1 then
					needsToMove = true
				end
				if allTotal >= count then
					break
				end
			end
		end
	end
	if needsToMove then
		turtle.turnRight()
	end
	turtle.select(intoSlot)
	local done = false
	for i = 1, #chestTotal do
		if chestTotal[i] > 0 then
			for o, p in pairs(chests[i]["stacks"]) do
				local newCount = (turtleInventory[intoSlot] and turtleInventory[intoSlot].count or 0)
				if newCount >= count then
					done = true
					break
				end
				if p.id == id then
					peripheral.call("top","pushItemIntoSlot","down",o,count - newCount,intoSlot)
					updateInternalInventory(intoSlot)
					if p.qty <= count - newCount then
						chests[i] = checkUp()
						done = p.qty == count - newCount
						if done then break end
					else
						chests[i]["stacks"][o].qty = p.qty - count - newCount
						break
					end
				end
			end
		end
		if done then
			break
		elseif needsToMove and i < #chestTotal and not done then
			bulldoze(2)
			moves = moves + 1
		end
	end
	if needsToMove then
		for i = 1, moves do
			repeat until back()
			repeat until back()
		end
		turtle.turnLeft()
	end
	return intoSlot
end

function checkTotalInventoryCapacity()
	local itemsLeft = 0
	for i = 1, #chests do
		itemsLeft = itemsLeft + chests[i]["size"] - #chests[i]["stacks"]
	end
	return itemsLeft
end

function canCraftInstance(v,count)
	local items = {}
	if type(v[2]) == "table" then
		for o = 1, #v[3] do
			if v[3][o] > 0 then
				if items[v[2][v[3][o]]] == nil then
					items[v[2][v[3][o]]] = 0
				end
				items[v[2][v[3][o]]] = items[v[2][v[3][o]]] + (1/v[1])
			end
		end
		for o, p in pairs(items) do
			items[o] = items[o]*math.ceil(count/v[1])*v[1]
		end
	else
		for o = 2, #v do
			if v[o] ~= "" then
				if items[v[o]] == nil then
					items[v[o]] = 0
				end
				items[v[o]] = items[v[o]] + 1
			end
		end
	end
	for o, p in pairs(items) do
		if not canCraft(o,p) then
			return false
		end
	end
	return true
end

function canCraft(id,count)
	local currentCount = 0
	currentCount = currentCount + itemCount(id)
	if currentCount >= count then
		return true
	end
	if furnaceRecipes[id] then
		currentCount = currentCount + itemCount(furnaceRecipes[id])
		if currentCount >= count then
			return true
		end
	end
	if craftingRecipes[id] then
		local v = craftingRecipes[id]
		if type(v[1]) == "table" then
			for first, second in pairs(craftingRecipes[id]) do
				local v = second
				if canCraftInstance(second,count) then
					return true
				else
					print("Could not craft "..count.." of "..id)
					sleep(1)
				end
			end
		else
			if canCraftInstance(v,count) then
				return true
			else
				print("Could not craft "..count.." of "..id)
				sleep(1)
			end
		end
	end
	return currentCount >= count
end
function minStack(id,qty)
	if 64 - qty > id then
		return id
	else
		return 64 - qty
	end
end
function mergeStack(name)
	local intoSlot = 0
	for i = 1, inventorySize do
		if turtleInventory[i] then
			local v = turtleInventory[i]
			if v.name == name then
				if intoSlot == 0 and v.count < v.maxSize then
					intoSlot = i
				else
					if intoSlot ~= 0 and v.count < v.maxSize then
						turtle.select(i)
						if turtle.transferTo(intoSlot) then
							if turtleInventory[intoSlot].count + turtleInventory[i].count > turtleInventory[intoSlot].maxSize then
								turtleInventory[i].count = turtleInventory[i].count - (turtleInventory[intoSlot].maxSize - turtleInventory[intoSlot].count)
								turtleInventory[intoSlot].count = turtleInventory[intoSlot].maxSize
								intoSlot = i
							else
								turtleInventory[intoSlot].count = turtleInventory[intoSlot].count + turtleInventory[i].count
								turtleInventory[i] = nil
							end
						end
					end
				end
			end
		end
	end
end
function notInList(list,str)
	for i, v in pairs(list) do
		if str == v then
			return false
		end
	end
	return true
end
function mergeStacks()
	local names = {}
	for i = 1, inventorySize do
		if turtleInventory[i] then
			if notInList(names,turtleInventory[i].name) then
				table.insert(names,turtleInventory[i].name)
			end
		end
	end
	for i = 1, #names do
		mergeStack(names[i])
	end
end

function rf()
	turtle.turnLeft()
	turtle.turnRight()
end

function checkFurnaceFuel()
	printTitle("Ultimate Program Running","Checking furnace fuel")
	sleep(0.1)
	local originalSlot = turtle.getSelectedSlot()
	rf()
	local fuelSlot = peripheral.call("bottom","getStackInSlot",2)
	if fuelSlot == nil or fuelSlot.qty < minFuel then
		fuelSlot = (fuelSlot and fuelSlot or {["qty"] = 0})
		local coal = itemCount("minecraft:coal")
		if coal - fuelSlot.qty > 0 then
			if minStack(coal,fuelSlot.qty) > 0 then
				local newSlot = pullItemFromStorage("minecraft:coal",minStack(coal,fuelSlot.qty))
				turnAround()
				turtle.drop()
				turnAround()
				turtleInventory[newSlot] = nil
				turtle.select(originalSlot)
				updateInternalInventory(newSlot)
				for i = 1, 50 do
					rf()
					if peripheral.call("bottom","getStackInSlot",2).qty >= minFuel then break end
					sleep(0.1)
				end
			end
		end
	end
end

function clearCrafting()
	if cautious then
		for i = 1, #slots do
			local slot = turtle.getItemDetail(slots[i])
			if slot then
				local buffer = nearestBuffer(slot.name)
				if buffer > 0 then
					turtle.select(i)
					turtle.transferTo(buffer)
					if turtleInventory[buffer] ~= nil and slot.count > turtleInventory[buffer].maxSize - turtleInventory[buffer].count then
						stockInventory()
						clearCrafting()
						break
					else
						if turtleInventory[buffer] ~= nil then
							turtleInventory[buffer].count = turtleInventory[buffer].count + slot.count
						else
							updateInternalInventory(buffer)
						end
					end
				else
					stockInventory()
					clearCrafting()
					break
				end
			end
		end
		updateInternalInventory()
	end
end

function clearFurnaceBufferChest()
	for i = 1, 27 do
		peripheral.call("front","pullItem","down",i)
	end
end

function craft(id,count)
	printTitle("Ultimate Program Running","Making "..count.." "..id)
	-- peripheral.call("top","getInventorySize")
	local itc = itemCount(id)
	local currentCount = itc
	if itc > 0 then
		local b = nearestBuffer(id)
		local c = turtle.getItemCount(b)
		if c >= count and count > 0 then
			turtle.select(b)
			return true
		else
			if itc >= count then
				pullItemFromStorage(id,count)
				return true
			else
				pullItemFromStorage(id,itc)
			end
		end
	end
	if canCraft(id,count) then
		local ready = false
		local furnaceItem = ""
		if furnaceRecipes[id] then
			ready = true
			furnaceItem = furnaceRecipes[id]
			currentCount = currentCount + itemCount(furnaceRecipes[id])
		end
		if ready then
			-- Furnace stuff happens here
			repeat
				checkFurnaceFuel()
				rf()
			until not peripheral.call("bottom","getStackInSlot",1)
			rf()
			local stack = peripheral.call("bottom","getStackInSlot",3)
			if stack then
				if nearestBuffer(stack.id) == 0 then
					stockInventory()
				end
				local bfr = nearestBuffer(stack.id)
				turtle.turnRight()
				back()
				down()
				turtle.suck()
				up()
				forward()
				turtle.turnLeft()
				--peripheral.call("bottom","pushItem",2,3,64,bfr)
				updateInternalInventory(bfr)
			end 
			pullItemFromStorage(furnaceRecipes[id],count)
			turtle.dropDown()
			repeat
				rf()
				checkFurnaceFuel()
			until not peripheral.call("bottom","getStackInSlot",1)
			rf()
			local stack = peripheral.call("bottom","getStackInSlot",3)
			if stack then
				if nearestBuffer(stack.id) == 0 then
					stockInventory()
				end
				local bfr = nearestBuffer(stack.id)
				turtle.turnRight()
				back()
				down()
				turtle.suck()
				up()
				forward()
				turtle.turnLeft()
				--peripheral.call("bottom","pushItem",2,3,64,bfr)
				updateInternalInventory(bfr)
			end
			if itemCount(id) >= count then
				return true
			end
		end 
		if craftingRecipes[id] then
			local v = craftingRecipes[id]
			local items = {}
			if type(v[1]) == "table" then
				for first, second in pairs(craftingRecipes[id]) do
					if canCraftInstance(second,count) then
						v = second
					end
				end
			end
			if type(v[2]) == "table" then
					for o = 1, #v[3] do
						if v[3][o] > 0 then
							if items[v[2][v[3][o]]] == nil then
								items[v[2][v[3][o]]] = 0
							end
							items[v[2][v[3][o]]] = items[v[2][v[3][o]]] + (1/v[1])
						end
					end
				else
					for o = 2, #v do
						if v[o] ~= "" then
							if items[v[o]] == nil then
								items[v[o]] = 0
							end
							items[v[o]] = items[v[o]] + (1/v[1])
						end
					end
				end
			local itemsOld = items
			for o, p in pairs(items) do
				items[o] = items[o]*math.ceil(count/v[1])*v[1]
			end
			for o, p in pairs(items) do
				if not canCraft(o,p) then
					return false
				end
			end
			if not checkIfEmptyInventory() then
				clearInventory()
				clearCrafting()
			end
			for o, p in pairs(items) do
				if itemCount(o) < p then
					if canCraft(o,p) then
						craft(o,p) -- Something goes wrong here
						pushItemToStorage(4)
					else
						return false
					end
				end
			end
			if not checkIfEmptyInventory() then
				clearInventory()
				return craft(id,count)
			end
			for o, p in pairs(items) do
				local item = pullItemFromStorage(o,p)
				if type(v[2]) == "table" then
					for m = 1, #v[3] do
						if v[3][m] > 0 and v[2][v[3][m]] == o  then
							turtle.transferTo(slots[m],math.ceil((1/v[1])*count))
							updateInternalInventory(item)
							updateInternalInventory(slots[m])
						end
					end
				else
					for m = 2, #v do
						if v[m] == o then
							turtle.transferTo(slots[m - 1],math.ceil((1/v[1])*count))
							updateInternalInventory(item)
							updateInternalInventory(slots[m - 1])
						end
					end
				end
			end
			turtle.select(4)
			turtle.craft()
			updateInternalInventory()
			return true
		end
	else
		return false
	end
	return true
end

function pushItemToStorage(slotz)
	local pushChest = 0
	local originalSlot = turtle.getSelectedSlot()
	local slot = (slotz and slotz or originalSlot)
	local currentSlot = turtleInventory[slot]
	if originalSlot ~= slot then
		turtle.select(slot)
	end
	if #chests > 1 then
		turtle.turnRight()
	end
	for i = 1, #chests do
		local oldCount = turtle.getItemCount()
		if turtle.dropUp() then
			if turtle.getItemCount() == 0 then
				checkUp(i,currentSlot.name,oldCount)
				turtleInventory[slot] = nil
				break
			else
				checkUp(i,currentSlot.name,oldCount)
			end
		end
		if #chests > 1 and i < #chests then
			forward()
			forward()
			pushChest = pushChest + 1
		end
	end
	for i = 1, pushChest do
		back()
		back()
	end
	if #chests > 1 then
		turtle.turnLeft()
	end
	turtle.select(originalSlot)
end

function forward()
	return turtle.forward()
end

function back()
	return turtle.back()
end

function up()
	return turtle.up()
end

function down()
	return turtle.down()
end

function updateAllChests()
	checkFuel()
	if #chests > 1 then
		turtle.turnRight()
	end
	for i = 1, #chests do
		chests[i] = checkUp()
		if #chests > 1 and i < #chests then
			bullDoze(2)
		end
	end
	turnAround()
	if #chests > 1 then
		bullDoze((#chests - 1)*2)
	end
	if #chests > 1 then
		turtle.turnRight()
	end
end

function digAndUpdate(dir)
	local slot = turtle.getSelectedSlot()
	local there, inspect = false, {}
	if dir == "up" then
		there, inspect = turtle.inspectUp()
	elseif dir == "down" then
		there, inspect = turtle.inspectDown()
	else
		there, inspect = turtle.inspect()
	end
	if there then
		local bf = 0
		if inspect.name == "minecraft:dirt" then
			bf = nearestBuffer(inspect.name)
		elseif inspect.name == "minecraft:stone" then
			bf = nearestBuffer("minecraft:cobblestone")
		else
			bf = nearestBuffer()
		end
		turtle.select(bf)
		if dir == "up" then
			turtle.digUp()
		elseif dir == "down" then
			turtle.digDown()
		else
			turtle.dig()
		end
		updateInternalInventory(bf)
		mergeStacks()
	end
	turtle.select(slot)
end

function makePickaxe(i)
	if i == #chests then
		if turtle.detect() then
			digAndUpdate()
		end
	end
	forward()
end

function slotsLeft()
	return inventorySize - #turtleInventory - 9
end

local miners = 0

function reduceByOne(slot)
	if turtleInventory[slot].count == 1 then
		turtleInventory[slot] = nil 
	else
		turtleInventory[slot].count = turtleInventory[slot].count - 1
	end
end
function addNewMiner() -- Needs fixing or testing!
	stockInventory()
	--[[
	local list = {"minecraft:hopper","ComputerCraft:CC-TurtleExpanded","ComputerCraft:CC-Peripheral","ComputerCraft:disk"}
	for i, v in pairs(list) do
		print(v..": "..tostring(canCraft(v,1)))
	end
]]
	if canCraft("minecraft:hopper",1) and canCraft("ComputerCraft:CC-TurtleExpanded",1) and canCraft("ComputerCraft:CC-Peripheral",1) and canCraft("ComputerCraft:disk",1) then
		printTitle("Ultimate Program Running","Adding New Miner")
		if slotsLeft() < 4 then
			stockInventory()
		end
		craft("minecraft:hopper",1)
		craft("ComputerCraft:CC-Peripheral",1)
		craft("ComputerCraft:CC-TurtleExpanded",1)
		pullItemFromStorage("ComputerCraft:disk",1)
		local droneSlot = turtle.getSelectedSlot()
		-- nearestBuffer("ComputerCraft:CC-Turtle")
		turtle.turnLeft()
		forward()
		if not turtle.up() then
			digAndUpdate("up")
			turtle.up()
		end
		for i = 1, miners + 1 do
			if math.ceil(i/2) == miners + 1 then
				if turtle.detect() then
					digAndUpdate()
				end
			end
			if not forward() then
				digAndUpdate()
				forward()
			end
		end
		if not down() then
			digAndUpdate("down")
			down()
		end
		pullItemFromStorage("ComputerCraft:CC-Peripheral",1)
		if turtle.placeDown() == false then
			digAndUpdate("down")
			pullItemFromStorage("ComputerCraft:CC-Peripheral",1)
			turtle.placeDown()
		end
		reduceByOne(turtle.getSelectedSlot())
		mergeStacks()
		local t = pullItemFromStorage("ComputerCraft:disk",1)
		turtle.dropDown()
		turtleInventory[t] = nil
		turtle.turnRight()
		local it = pullItemFromStorage("minecraft:hopper",1)
		digAndUpdate()
		forward()
		turtle.turnLeft()
		digAndUpdate()
		forward()
		turnAround()
		turtle.select(it)
		turtle.place()
		reduceByOne(it)
		mergeStacks()
		digAndUpdate("up")
		up()
		digAndUpdate()
		forward()
		turtle.turnRight()
		forward()
		digAndUpdate("up")
		up()
		local tr = pullItemFromStorage("ComputerCraft:CC-TurtleExpanded",1)
		turtle.placeDown()
		turtle.turnRight()
		reduceByOne(tr)
		peripheral.call("bottom","turnOn")
		for i = 1, miners + 1 do
			back()
		end
		down()
		back()
		turtle.turnRight()
		miners = miners + 1
		return true
	end
	return false
end

function bulldoze(i)
	for i = 1, i do
		if not forward() then repeat turtle.dig() until forward() end
	end
end

function addNewChest()
	stockInventory()
	if ironChests then
		local firstChest = 0
		for i = 1, #chests do
			if chests[i].size == 27 and canCraft("IronChest:woodIronUpgrade",1) then
				firstChest = i
				craft("IronChest:woodIronUpgrade",1)
				break
			elseif chests[i].size == 54 and canCraft("IronChest:ironGoldUpgrade",1) then
				firstChest = i
				craft("IronChest:ironGoldUpgrade",1)
				break
			elseif chests[i].size == 81 and canCraft("IronChest:goldDiamondUpgrade",1) then
				firstChest = i
				craft("IronChest:goldDiamondUpgrade",1)
				break
			end
		end
		if firstChest ~= 0 then
			if firstChest > 1 then
				turtle.turnRight()
				bulldoze((firstChest - 1)*2)
			end
			turtle.placeUp()
			chests[firstChest] = checkUp()
			updateInternalInventory()
			if firstChest > 1 then
				turnAround()
				bulldoze((firstChest - 1)*2)
				turtle.turnRight()
			end
			return true
		end
	end
	if canCraft("minecraft:chest",1) then
		craft("minecraft:chest",1)
		turtle.turnRight()
		for i = 1, #chests do
			makePickaxe(i)
			makePickaxe(i)
		end
		digAndUpdate("up")
		local chest = pullItemFromStorage("minecraft:chest",1)
		turtle.placeUp()
		reduceByOne(chest)
		for i = 1, #chests * 2 do
			back()
		end
		chests[#chests + 1] = {stacks = {}, size = 27}
		turtle.turnLeft()
		return true
	end
	return false
end
--[[
for i, v in pairs(chests[1][1]) do
	if v["all"] then
		for o, p in pairs(v.all()) do
			textutils.slowPrint(o..": "..tostring(p))
		end
	end
end

id:
minecraft:log
minecraft:chest
minecraft:planks
minecraft:cobblestone
minecraft:gold_ingot
minecraft:furnace
minecraft:diamond
minecraft:stick
minecraft:diamond_pickaxe
minecraft:chest
minecraft:iron_ingot
minecraft:redstone
minecraft:sand
minecraft:glass
minecraft:glass_pane
minecraft:ender_pearl
IronChest:woodIronUpgrade
IronChest:ironGoldUpgrade
IronChest:goldDiamondUpgrade
raw_name:
tile.ironchest:diamond
tile.ironchest:iron
tile.ironchest:gold
tile.computercraft:advanced_computer
tile.computercraft:computer
tile.computercraft:turtle
]]

--[[
while true do
	print("Ultimate Program Crafter")
	write("Item Name: ")
	local itemName = ""
	itemName = read()
	if not itemName then
		break
	end
	if string.gsub(itemName," ","") == "" then
		break
	end
	write("Item Count: ")
	local itemCount = ""
	itemCount = tonumber(read())
	if not itemCount then
		break
	end
	if craftingRecipes[itemName] or furnaceRecipes[itemName] then
		if itemCount <= 64 then
			craft(itemName,itemCount)
			--stockInventory()
		end
	end
end
]]--
--stockInventory()
function getItemName()
	write("Item Name: ")
	local itemName = ""
	itemName = read()
	if not itemName then
		return nil
	end
	if itemName == "exit" or itemName == "add miner" or itemName == "count" or itemName == "clear" then
		return itemName
	end
	if string.gsub(itemName," ","") == "" then
		return nil
	end
	write("Item Count: ")
	local itemCount2 = ""
	itemCount2 = tonumber(read())
	if not itemCount2 then
		return nil
	end
	return itemName, itemCount2
end
function printCenter(str,line)
	local x, y = term.getSize()
	term.setCursorPos((x/2) - (string.len(str)/2),line)
	term.clearLine()
	term.setCursorPos((x/2) - (string.len(str)/2),line)
	write(str)
end
function printLine()
	write(string.rep("-",({term.getSize()})[1]))
end
function printTitle(...)
	for i = 1, #({...}) do
		printCenter(({...})[i],i)
	end
	term.setCursorPos(1,#({...}) + 1)
	printLine()
end
function getInput()
	turtle.turnRight()
	term.clear()
	printTitle("Ultimate Program Interface", "Type \"exit\" to exit, enter to cancel.","\"add miner\",  \"clear\", \"count\".\"")
	local itemName, itemCount2 = getItemName()
	itemCount2 = tonumber(itemCount2)
	if itemName then
		if string.lower(itemName) == "exit" then
			turtle.turnLeft()
			return false
		elseif string.lower(itemName) == "add miner" then
			print("Attempting to add new miner...")
			turtle.turnLeft()
			addNewMiner()
			return true
		elseif string.lower(itemName) == "clear" then
			turtle.turnLeft()
			print("Clearing inventory...")
			clearCrafting()
			clearInventory()
			return true
		elseif string.lower(itemName) == "count" then
			write("Item name: ")
			local itemName2 = read()
			print(itemCount2)
			print(itemName2)
			print("There are "..itemCount(itemName2).." of "..itemName2.." available.")
			sleep(2)
		else
			if canCraft(itemName,itemCount2) then
				print("Processing...")
				turtle.turnLeft()
				craft(itemName,itemCount2)
				turtle.turnRight()
				turtle.drop(itemCount2)
				updateInternalInventory(turtle.getSelectedSlot())
			else
				print("Cannot craft items.")
				sleep(0.5)
			end
		end
	end
	turtle.turnLeft()
	return true
end
function checkRedstone()
	local e = {"nothing"}
	if not rs.getInput("bottom") then
		os.startTimer(0.1)
		e = {os.pullEvent()}
	end
	if rs.getInput("bottom") or e[1] == "key" or e[1] == "char" then
		if getInput() == false then
			term.clear()
			printTitle("Ultimate Program Closed")
			term.setCursorPos(1,3)
			return true
		else
			term.clear()
			printTitle("Ultimate Program Running")
		end
	end
	return false
end
--[[
while true do
	term.clear()
	printTitle("Ultimate Program Running")
	mergeStacks()
	if checkTotalInventoryCapacity() < inventorySize then
		addNewChest()
	end
	stockInventory()
	addNewMiner()
end]]
term.clear()
printTitle("Ultimate Program Loading","Initializing External Inventory")
chests = {checkUp()}
checkFuel()
turtle.turnRight()
local initChests = 0
repeat
	local breakingForward = false
	repeat 
		if turtle.detect() then
			breakingForward = true 
			break 
		end 
	until forward()
	if breakingForward then break end
	repeat 
		if turtle.detect() then
			breakingForward = true 
			repeat until back()
			break 
		end 
	until forward()
	if breakingForward then break end
	initChests = initChests + 1
	local check = checkUp()
	if check then chests[initChests + 1] = check else break end
until not peripheral.call("top","getInventorySize")
if initChests > 0 then
	for i = 1, initChests*2 do
		if not back() then
			turnAround()
			repeat until not turtle.dig()
			turnAround()
			back()
		end
	end
end
turtle.turnLeft()
printTitle("Ultimate Program Loading","Initializing Internal Inventory")
updateInternalInventory()
stockInventory()
term.clear()
local stop = false
while true do
	mergeStacks()
	if checkTotalInventoryCapacity() < inventorySize*2 then
		repeat
			if checkRedstone() then stop = true; break end
			addNewChest()
		until checkTotalInventoryCapacity() >= inventorySize
		if stop then break end
	end
	stockInventory()
	printTitle("Ultimate Program Running","Idle")
	sleep(0.1)
	mergeStacks()
	if checkRedstone() then break end
	if makeMiners then addNewMiner() end
	printTitle("Ultimate Program Running","Idle")
	sleep(0.1)
	mergeStacks()
	if checkRedstone() then break end
end