--[[

INSTRUCTIONS:

Place single chests in front of and on top of robot.
Place a single hopper to the left of front chest.
Place a furnace under the robot.
Add to instructions are more requirements are added.


VALUE DOCUMENTATION:

minFuel (number): Minimum fuel allowed in furnace before refuelling
chests (table): External Chest Cache
robotInventory (table): Internal Inventory Cache
inventorySize (number): Internal Inventory Size
inv (number): Buffer Chest Size
slots (table): List of crafting slots
craftingRecipes (table): List of crafting recipes. Key is item name to be crafted, value is a table of either {itemCount,(1-9 itemName of items to place in crafting grid)} or {itemCount, {Item Names}, {Keys to previous item name table}}.
furnaceRecipes (table): List of furnace recipes. Key is resulting item name, value is item name to be smelted/cooked.
miners (number): Amount of active turtle miners


FUNCTION DOCUMENTATION:

notCrafting(slot: number) (Returns boolean): Returns whether or not (slot) is a crafting slot.
updateInternalInventory([slot: number]) (Returns nil): Updates internal inventory cache table (robotInventory) slot (slot), or if (slot) is absent, updates entire table.
checkUp(chestIndex: number, [itemName: string, itemCount: number]) (Returns nil if itemName and itemCount exist, returns table containing chest contents otherwise) return: Updates chests[chestIndex] with the contents of the chest currently above the robot. If itemName and itemCount are BOTH present, will only update for places that the items could possibly be placed in since the last cache update. (Used IMMEDIATELY after dropping anything into a chest)
itemCount(itemName: string) (Returns number): Returns combined amount of (itemName) in both (robotInventory) and (chests).
checkIfEmptyInventory() (Returns boolean): Checks if robot's internal inventory is empty. (not counting crafting slots)
emptyBufferChest() (Returns boolean): Checks if buffer chest is empty.
clearInventory([dontClearOne: boolean]) (Returns nil): Puts entire internal inventory (Unless dontClearOne is true, in which case everything except slot 1) into chests, and changes (robotInventory) and (chests) contents to match. 
nearestBuffer([itemName: string]) (Returns number): Returns lowest internal inventory slot that can hold (itemName), or the lowest empty slot if itemName is not set.
stockInventory([dontClearOne: boolean]) (Returns nil): Fills inventory with contents of buffer chest. If inventory is full, calls clearInventory([dontClearOne: boolean]) to clear inventory. Repeats until buffer chest is empty.
pullItemFromStorage(itemName: string, itemCount: number) (Returns number): Pulls item from external chest inventory if item is not already in internal inventory. Returns and selects slot number item is in once item is in internal inventory.
checkTotalInventoryCapacity() (Returns number): Returns amount of empty slots left in external chest inventory.
canCraft(itemName: string, itemCount: number) (Returns boolean): Returns whether or not (itemCount) of (itemName) can be crafted using the contents of the internal and external inventories.
minStack(coalAvailable: number, coalInFuelSlot: number) (Returns number): Returns the lowest of (coalAvailable) or (64 - coalInFuelSlot) (The amount of coal that can be placed into the furnace's fuel slot).
mergeStack(itemName: string) (Returns nil): Merges all stacks of (itemName) in internal inventory to the lowest amount of stacks possible.
notInList(list: table, string: string) (Returns boolean): Returns true if (string) is not in (list), false otherwise.
mergeStacks() (Returns nil): Merges all stacks in internal inventory to the lowest amount of stacks possible using mergeStack(itemName: string).
checkFurnaceFuel() (Returns nil): Refuels furnace below robot if fuel is below (minFuel).
clearCrafting() (Returns nil): Clears crafting slots.
craft(itemName: string, itemCount: number) (Returns boolean): Puts (itemCount) of (itemName) into lowest available slot. If items are already available in internal inventory, will select slot. If not, will use pullItemFromStorage(itemName, itemCount) to pull more items in. If there are not enough items in external inventory, will craft the required items.
pushItemToStorage(slot: number) (Returns nil): Puts items in (slot) into external inventory.
updateAllChests()
makePickaxe(i: number) (Returns nil): Helper function for addNewChest(), crafts pickaxe if one isn't already available and then moves forward.
addNewMiner() (Returns nil): Adds new miner and increments (miners) if successful
addNewChest() (Returns nil): Adds new external chest to external chest inventory and updates (chests) to match.
getItemName() (Returns (string, number) or (string) or (nil)): Returns "exit" 
]]
if peripheral == nil then
	error("Program is only designed for ComputerCraft.",0)
end
local cautious = true
local component = require("component")
local sides = require("sides")
local term = require("term")
local ic = component.inventory_controller
local robot = require("robot")
local cr = component.crafting
local minFuel = 64
local inventorySize = 16
local furnacePresent = false
local robotInventory = {}
local chests = {}
local inv = peripheral.call("front","getInventorySize")
local slots = {1,2,3,5,6,7,9,10,11}
local craftingRecipes = {
["minecraft:planks"] = {4,"minecraft:log"},
["minecraft:stick"] = {4,"minecraft:planks","","","minecraft:planks"},
["IronChest:woodIronUpgrade"] = {1,{"minecraft:iron_ingot","minecraft:planks"},{1,1,1,1,2,1,1,1,1}},
["IronChest:ironGoldUpgrade"] = {1,{"minecraft:gold_ingot","minecraft:iron_ingot"},{1,1,1,1,2,1,1,1,1}},
["IronChest:goldDiamondUpgrade"] = {1,{"minecraft:glass","minecraft:diamond","minecraft:gold_ingot"},{1,1,1,2,3,2,1,1,1}},
["minecraft:glass_pane"] = {16,{"minecraft:glass"},{1,1,1,1,1,1}},
["ComputerCraft:CC-Computer"] = {1,{"minecraft:stone","minecraft:redstone","minecraft:glass_pane"},{1,1,1,1,2,1,1,3,1}},
["ComputerCraft:CC-Turtle"] = {1,{"minecraft:iron_ingot","ComputerCraft:CC-Computer","minecraft:chest"},{1,1,1,1,2,1,1,3,1}},
["ComputerCraft:CC-Peripheral"] = {1,{"minecraft:stone","minecraft:redstone"},{1,1,1,1,2,1,1,2,1}},
["minecraft:chest"] = {1,{"minecraft:planks"},{1,1,1,1,0,1,1,1,1}},
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
["minecraft:hopper"] = {1,{"minecraft:iron_ingot","minecraft:chest"},{1,0,1,1,2,1,0,1,0}}
}
local furnaceRecipes = {
	["minecraft:stone"] = "minecraft:cobblestone",
	["minecraft:iron_ingot"] = "minecraft:iron_ore",
	["minecraft:gold_ingot"] = "minecraft:gold_ore",
	["minecraft:glass"] = "minecraft:sand"
}

function notCrafting(s)
	return s > 11 or s == 4 or s == 8
end

function updateInternalInventory(n)
	if n then
		robotInventory[n] = turtle.getItemDetail(n)
		robotInventory[n].maxSize = turtle.getItemSpace(n) - robotInventory[n].count
	else
		robotInventory = {}
		for i = 4, inventorySize do
			if notCrafting(i) then
				robotInventory[i] = turtle.getItemDetail(i)
				robotInventory[i].maxSize = turtle.getItemSpace(i) - robotInventory[i].count
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
				if not chests[ix]["stacks"][i] or chests[ix]["stacks"][i].name == id then
					local oldSlot = (chests[ix]["stacks"][i] or {name = "", size = 0})
					chests[ix]["stacks"][i] = peripheral.call("top","getStackInSlot",i)
					if chests[ix]["stacks"][i] and (oldSlot.name == chests[ix]["stacks"][i].name or oldSlot.qty == 0) then
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
		for i = 1, size do
			stacks[i] = peripheral.call("top","getStackInSlot",i)
		end
		return {["stacks"] = stacks,["size"] = size}
	end
end
-- Converted to here
function itemCount(id)
	local count = 0
	for i = 4, inventorySize do
		if notCrafting(i) then
			local slot = robotInventory[i]
			if slot and slot.id == id then
				count = count + slot.count
			end
		end
	end
	for i = 1, #chests do
		for o, v in pairs(chests[i]["stacks"]) do
			if v.name == id then
				count = count + v.qty
			end
		end
	end
	return count
end

function checkIfEmptyInventory()
	for i = 1, inventorySize do
		if robot.count(i) > 0 then
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
	local chestz = 0
	local lastSlot = (dontClearOne and 2 or 1)
	if #chests == 1 then
		for i = (dontClearOne and 2 or 1), inventorySize do
			if robotInventory[i] then
				robot.select(i)
				if not robot.dropUp() then
					break
				end
				checkUp(1,robotInventory[i].id,robotInventory[i].count)
			end
		end
	else
		for i = 1, #chests do
			for p = lastSlot, inventorySize do
				if robotInventory[p] then
					robot.select(p)
					if not robot.dropUp() then
						lastSlot = p
						break
					end
					checkUp(i,robotInventory[p].id,robotInventory[p].count)
				end
			end
			if i < #chests and not ((lastSlot == inventorySize) or checkIfEmptyInventory()) then
				if i == 1 then
					robot.turnRight()
				end
				forward()
				forward()
				chestz = chestz + 1
			end
		end --[[
		for i = 1, chestz do
			chests[chestz + 1 - i] = checkUp()
			back()
			back()
		end ]]
		if chestz > 0 then
			robot.turnLeft()
		end
	end
	robotInventory = {}
end

function nearestBuffer(id)
	for i = 4, inventorySize do
		if notCrafting(i) and (not robotInventory[i] or (robotInventory[i].id == id and robotInventory[i].count < robotInventory[i].maxSize)) then
			return i
		end
	end
	return 0
end

function stockInventory(dontClearOne)
	repeat
	for i = 1, inv do
		local breaking = false
		repeat
			local sl = peripheral.call("front","getStackInSlot",i)
			if sl then
				print(i)
				local bu = nearestBuffer(sl.name)
				if bu == 0 or not bu then
					breaking = true
					break
				end
				robot.select(bu)
				if ic.suckFromSlot(sides.front,i,(robotInventory[bu] and (robotInventory[bu].maxSize - robotInventory[bu].count) or sl.qty)) == false then
					breaking = true
				end
				robotInventory[bu] = ic.getStackInInternalSlot(bu)
			end
		until breaking or not sl
	end
	if slotsLeft() < 4 or nearestBuffer() == 0 then
		clearInventory(dontClearOne)
	end
	until emptyBufferChest()
end
function pullItemFromStorage(id,count)
	local allTotal = 0
	local intoSlot = 0
	for i = 1, inventorySize do
		if notCrafting(i) then
			local tempSlot = robotInventory[i]
			if tempSlot and tempSlot.id == id then
				if intoSlot == 0 then
					allTotal = allTotal + robotInventory[i].count
					intoSlot = i
					robot.select(intoSlot)
				else
					robot.select(i)
					allTotal = allTotal + robotInventory[i].count
					robot.transferTo(intoSlot)
					if robotInventory[intoSlot].count + robotInventory[i].count > robotInventory[intoSlot].maxSize then
						robotInventory[i].count = robotInventory[i].count - (robotInventory[intoSlot].maxSize - robotInventory[intoSlot].count)
						robotInventory[intoSlot].count = robotInventory[intoSlot].maxSize
					else
						robotInventory[intoSlot].count = robotInventory[intoSlot].count + robotInventory[i].count
						robotInventory[i] = nil
					end
				end
				if allTotal >= count then
					robot.select(intoSlot)
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
			if p.name == id then
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
		robot.turnRight()
	end
	robot.select(intoSlot)
	local done = false
	for i = 1, #chestTotal do
		if chestTotal[i] > 0 then
			for o, p in pairs(chests[i]["stacks"]) do
				if p.name == id then
					local newCount = (robotInventory[intoSlot] and robotInventory[intoSlot].count or 0)
					if newCount >= count then
						done = true
						break
					end
					ic.suckFromSlot(sides.up,o,count - newCount)
					updateInternalInventory(intoSlot)
					if p.qty <= count - newCount then
						chests[i]["stacks"][o] = nil
					else
						chests[i]["stacks"][o].qty = p.qty - count - newCount
					end
				end
			end
		end
		if needsToMove and i < #chestTotal and not done then
			forward()
			forward()
			moves = moves + 1
		end
		if done then
			break
		end
	end
	if needsToMove then
		for i = 1, moves do
			back()
			back()
		end
		robot.turnLeft()
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
				items[o] = math.ceil(items[o]*(count - currentCount))
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
		if robotInventory[i] then
			local v = robotInventory[i]
			if v.id == name then
				if intoSlot == 0 and v.count < v.maxSize then
					intoSlot = i
				else
					if intoSlot ~= 0 and v.count < v.maxSize then
						robot.select(i)
						if robot.transferTo(intoSlot) then
							if robotInventory[intoSlot].count + robotInventory[i].count > robotInventory[intoSlot].maxSize then
								robotInventory[i].count = robotInventory[i].count - (robotInventory[intoSlot].maxSize - robotInventory[intoSlot].count)
								robotInventory[intoSlot].count = robotInventory[intoSlot].maxSize
								intoSlot = i
							else
								robotInventory[intoSlot].count = robotInventory[intoSlot].count + robotInventory[i].count
								robotInventory[i] = nil
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
		if robotInventory[i] then
			if notInList(names,robotInventory[i].id) then
				table.insert(names,robotInventory[i].id)
			end
		end
	end
	for i = 1, #names do
		mergeStack(names[i])
	end
end
function checkFurnaceFuel()
	local originalSlot = robot.select()
	local fuelSlot = ic.getStackInSlot(sides.down,2)
	if fuelSlot == nil or fuelSlot.qty < minFuel then
		fuelSlot = (fuelSlot and fuelSlot or {["qty"] = 0})
		local coal = itemCount("minecraft:coal")
		if coal - fuelSlot.qty > 0 then
			if minStack(coal,fuelSlot.qty) > 0 then
				local newSlot = pullItemFromStorage("minecraft:coal",minStack(coal,fuelSlot.qty))
				ic.dropIntoSlot(sides.down,2)
				robotInventory[newSlot] = nil
				robot.select(originalSlot)
			end
		end
	end
end

function clearCrafting()
	if cautious then
		for i = 1, #slots do
			local slot = turtle.getItemDetail(slots[i])
			if slot then
				local buffer = nearestBuffer(slot.id)
				if buffer > 0 then
					robot.select(i)
					robot.transferTo(buffer)
					if slot.count > robotInventory[buffer].maxSize - robotInventory[buffer].count then
						stockInventory()
						clearCrafting()
						break
					else
						robotInventory[buffer].count = robotInventory[buffer].count + slot.count
					end
				else
					stockInventory()
					clearCrafting()
					break
				end
			end
		end
	end
end

--[[
function lowFuel()
	if computer.energy() < computer.maxEnergy()/2 then
	
	end
end]]

function craft(id,count)
	local itc = itemCount(id)
	local currentCount = 0
	currentCount = currentCount + itc
	if itc > 0 then
		local b = nearestBuffer(id)
		local c = robot.count(b)
		if c > count and count > 0 then
			robot.select(b)
			return true
		else
			if itc >= count then
				pullItemFromStorage(id,count - c)
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
			local hasFurnace = true
			if furnacePresent or ic.getInventorySize(sides.down) == 3 then
				furnacePresent = true
				repeat
					checkFurnaceFuel()
				until not ic.getStackInSlot(sides.down,1)
				local stack = ic.getStackInSlot(sides.down,3)
				if stack then
					if nearestBuffer(stack.name) == 0 then
						stockInventory()
					end
					local bfr = nearestBuffer(stack.name)
					ic.select(bfr)
					ic.suckFromSlot(sides.down,3)
					robotInventory[bfr] = stack
				end
				pullItemFromStorage(furnaceRecipes[id],count - itc)
				ic.dropIntoSlot(sides.down,1)
				repeat
					checkFurnaceFuel()
				until not ic.getStackInSlot(sides.down,1)
				local stack = ic.getStackInSlot(sides.down,3)
				if stack then
					if nearestBuffer(stack.name) == 0 then
						stockInventory()
					end
					local bfr = nearestBuffer(stack.name)
					robot.select(bfr)
					ic.suckFromSlot(sides.down,3)
					robotInventory[bfr] = stack
				end
			else
				error("FURNACE MISSING",0)
			end
			if itemCount(id) >= count then
				return true
			end
		end
		if craftingRecipes[id] then
			local v = craftingRecipes[id]
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
			for o, p in pairs(items) do
				items[o] = math.ceil(items[o]*(count - currentCount))
			end
			for o, p in pairs(items) do
				if not canCraft(o,p) then
					return false
				end
			end
			clearCrafting()
			for o, p in pairs(items) do
				if itemCount(o) < p then
					if canCraft(o,p) then
						craft(o,p)
					else
						return false
					end
				end
			end
			for o, p in pairs(items) do
				local item = pullItemFromStorage(o,p) -- fix?
				if type(v[2]) == "table" then
					for m = 1, #v[3] do
						if v[3][m] > 0 and v[2][v[3][m]] == o  then
							robot.transferTo(slots[m],math.ceil((1/v[1])*(count - currentCount)))
							if math.ceil((1/v[1])*(count - currentCount)) >= (robotInventory[item] and robotInventory[item].count or 0) then
								robotInventory[item] = nil
							else
								robotInventory[item].count = robotInventory[item].count - math.ceil((1/v[1])*(count - currentCount))
							end
						end
					end
				else
					for m = 2, #v do
						if v[m] == o then
							robot.transferTo(slots[m - 1],math.ceil((1/v[1])*(count - currentCount)))
							if math.ceil((1/v[1])*(count - currentCount)) >= robotInventory[item].count then
								robotInventory[item] = nil
							else
								robotInventory[item].count = robotInventory[item].count - math.ceil((1/v[1])*(count - currentCount))
							end
						end
					end
				end
				
			end
			local buffer = nearestBuffer(id)
			if buffer == 0 then
				robot.select(1)
				cr.craft()
				stockInventory(true)
				robot.transferTo(4)
				updateInternalInventory(4)
				robot.select(4)
			else
				robot.select(buffer)
				cr.craft()
				updateInternalInventory(buffer)
			end
			return true
		end
	end
	return true
end
function pushItemToStorage(slot)
	local pushChest = 0
	local originalSlot = robot.select()
	local currentSlot = robotInventory[slot]
	robot.select(slot)
	if #chests > 1 then
		robot.turnRight()
	end
	for i = 1, #chests do
		local oldCount = robot.count()
		local drop = robot.dropUp()
		if drop and robot.count() == 0 then
			checkUp(i,currentSlot.id,oldCount)
			robotInventory[slot] = nil
			break
		elseif drop then
			checkUp(i,currentSlot.id,oldCount)
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
	robot.turnLeft()
	robot.select(originalSlot)
end
function forward()
	return robot.forward()
end
function back()
	return robot.back()
end
function up()
	return robot.up()
end
function down()
	return robot.down()
end
function updateAllChests()
	if #chests > 1 then
		robot.turnRight()
	end
	for i = 1, #chests do
		chests[i] = checkUp()
		if #chests > 1 and i < #chests then
			forward()
			forward()
		end
	end
	if #chests > 1 then
		for i = 1, #chests - 1 do
			back()
			back()
		end
	end
	if #chests > 1 then
		robot.turnLeft()
	end
end
function makePickaxe(i)
	if i == #chests then
		if robot.detect() then
			local bf = nearestBuffer()
			robot.select(bf)
			if robot.swing(sides.front) == false then
				for o = 1, i - 1 do
					back()
					back()
				end
				craft("minecraft:iron_pickaxe",1)
				craft("minecraft:chest",1)
				ic.equip()
				for o = 1, i - 1 do
					forward()
					forward()
				end
				bf = nearestBuffer()
				robot.select(bf)
				robot.swing(sides.front)
			end
			updateInternalInventory(bf)
			mergeStacks()
		end
	end
	forward()
end
function slotsLeft()
	return inventorySize - #robotInventory - 9
end
local miners = 0
function addNewMiner()
	printTitle("Ultimate Program Running","Adding New Miner")
	stockInventory()
	--[[
	local list = {"minecraft:hopper","ComputerCraft:CC-TurtleExpanded","ComputerCraft:CC-Peripheral","ComputerCraft:disk"}
	for i, v in pairs(list) do
		print(v..": "..tostring(canCraft(v,1)))
	end
]]
	if canCraft("minecraft:hopper",1) and canCraft("ComputerCraft:CC-TurtleExpanded",1) and canCraft("ComputerCraft:CC-Peripheral",1) and canCraft("ComputerCraft:disk",1) then
		
		if slotsLeft() < 3 then
			stockInventory()
		end
		craft("minecraft:hopper",1)
		craft("ComputerCraft:CC-Peripheral",1)
		craft("ComputerCraft:CC-TurtleExpanded",1)
		pullItemFromStorage("ComputerCraft:disk",1)
		local droneSlot = robot.select()
		-- nearestBuffer("ComputerCraft:CC-Turtle")
		robot.turnLeft()
		robot.forward()
		if robot.up() == nil then
			local br = nearestBuffer()
			robot.select(br)
			if robot.swingUp(sides.up) == false then
				back()
				craft("minecraft:iron_pickaxe",1)
				ic.equip()
				forward()
				robot.select(br)
				robot.swingUp(sides.up)
			end
			updateInternalInventory(br)
			mergeStacks()
			robot.up()
		end
		for i = 1, miners + 1 do
			if math.ceil(i/2) == miners + 1 then
				if robot.detect() then
					if robot.durability() == nil then
						for o = 1, i - 1 do
							back()
						end
						craft("minecraft:iron_pickaxe",1)
						ic.equip()
						for o = 1, i - 1 do
							forward()
						end
					end
					local br = nearestBuffer()
					robot.select(br)
					robot.swing(sides.front)
					updateInternalInventory(br)
					mergeStacks()
				end
			end
			forward()
		end
		if robot.down() == nil then
			local bf = nearestBuffer()
			robot.select(bf)
			if robot.swingDown(sides.down) == false then
				for i = 1, miners + 1 do
					back()
				end
				down()
				back()
				craft("minecraft:iron_pickaxe",1)
				ic.equip()
				forward()
				up()
				for i = 1, miners + 1 do
					forward()
				end
				robot.select(bf)
				robot.swingDown(sides.down)
			end
			updateInternalInventory(bf)
			mergeStacks()
			robot.down()
		end
		pullItemFromStorage("ComputerCraft:CC-Peripheral",1)
		if robot.placeDown() == false then
			local bf = nearestBuffer()
			robot.select(bf)
			if robot.swingDown(sides.down) == false then
				up()
				for i = 1, miners + 1 do
					back()
				end
				craft("minecraft:iron_pickaxe",1)
				ic.equip()
				for i = 1, miners + 1 do
					forward()
				end
				up()
				bf = nearestBuffer()
				robot.select(bf)
				robot.swingDown(sides.down)
			end
			updateInternalInventory(bf)
			mergeStacks()
			pullItemFromStorage("ComputerCraft:CC-Peripheral",1)
			robot.placeDown()
		end
		updateInternalInventory(robot.select())
		mergeStacks()
		local t = pullItemFromStorage("ComputerCraft:disk",1)
		robot.dropDown()
		robotInventory[t] = nil
		robot.turnRight()
		local it = pullItemFromStorage("minecraft:hopper",1)
		if robot.place(sides.right) == false then
			local bf = nearestBuffer()
			robot.select(bf)
			if robot.swing() == false then
				up()
				robot.turnLeft()
				for o = 1, miners + 1 do
					back()
				end
				craft("minecraft:iron_pickaxe",1)
				ic.equip()
				for o = 1, miners + 1 do
					forward()
				end
				robot.turnRight()
				down()
				bf = nearestBuffer()
				robot.select(bf)
				robot.swing(sides.front)
				updateInternalInventory(bf)
				mergeStacks()
			end
			pullItemFromStorage("minecraft:hopper",1)
			robot.place(sides.right)
		else
			updateInternalInventory(it)
		end
		mergeStacks()
		-- Also put disk into drive
		up()
		robot.turnLeft()
		local tr = pullItemFromStorage("ComputerCraft:CC-TurtleExpanded",1)
		robot.placeDown(sides.right)
		if robotInventory[tr].count == 1 then
			robotInventory[tr] = nil
		else
			robotInventory[tr].count = robotInventory[tr].count - 1
		end
		robot.useDown()
		for i = 1, miners + 1 do
			back()
		end
		robot.down()
		robot.back()
		robot.turnRight()
		miners = miners + 1
		return true
	end
	return false
end
function addNewChest()
	stockInventory()
	craft("minecraft:chest",1)
	robot.select(nearestBuffer("minecraft:chest"))
	robot.turnRight()
	local dur = {robot.durability()}
	if not dur[1] and dur[2] == "no tool equipped" then
		craft("minecraft:iron_pickaxe",1)
		ic.equip()
	end
	for i = 1, #chests do
		makePickaxe(i)
		makePickaxe(i)
	end
	if robot.detectUp() then
		if robot.durability() == nil then
			for o = 1, i - 1 do
				back()
				back()
			end
			robot.turnRight()
			craft("minecraft:chest",1)
			craft("minecraft:iron_pickaxe",1)
			ic.equip()
			robot.turnLeft()
			for o = 1, i - 1 do
				forward()
				forward()
			end
			robot.select(nearestBuffer())
			robot.swingUp(sides.up)
		end
	end
	local chest = pullItemFromStorage("minecraft:chest",1)
	robot.placeUp()
	robotInventory[chest].count = robotInventory[chest].count - 1
	if robotInventory[chest].count == 0 then
		robotInventory[chest] = nil
	end
	for i = 1, #chests * 2 do
		back()
	end
	chests[#chests + 1] = {stacks = {}, size = 27}
	robot.turnLeft()
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
	io.write("Item Name: ")
	local itemName = ""
	itemName = io.read()
	if not itemName then
		break
	end
	if string.gsub(itemName," ","") == "" then
		break
	end
	io.write("Item Count: ")
	local itemCount = ""
	itemCount = tonumber(io.read())
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
	io.write("Item Name: ")
	local itemName = ""
	itemName = io.read()
	if not itemName then
		return nil
	end
	if itemName == "exit" then
		return itemName
	end
	if string.gsub(itemName," ","") == "" then
		return nil
	end
	io.write("Item Count: ")
	local itemCount = ""
	itemCount = tonumber(io.read())
	if not itemCount then
		return nil
	end
	return itemName, itemCount
end
function getScreenSize()
	if term.getViewport then
		return term.getViewport()
	else
		return component.gpu.getResolution()
	end
end
function printCenter(str,line)
	local x, y = getScreenSize()
	term.setCursor((x/2) - (string.len(str)/2),line)
	term.clearLine()
	term.setCursor((x/2) - (string.len(str)/2),line)
	term.write(str)
end
function printLine()
	term.write(string.rep("-",({getScreenSize()})[1]))
end
function printTitle(...)
	for i = 1, #({...}) do
		printCenter(({...})[i],i)
	end
	term.setCursor(1,#({...}) + 1)
	printLine()
end
function getInput()
	robot.turnAround()
	term.clear()
	printTitle("Ultimate Program Crafting Terminal", "Type \"exit\" to exit, or press enter to cancel.")
	local itemName, itemCount = getItemName()
	if itemName then
		if itemName == "exit" then
			robot.turnAround()
			return false
		else
			if canCraft(itemName,itemCount) then
				print("Processing...")
				robot.turnAround()
				craft(itemName,itemCount)
				robot.turnAround()
				robot.drop(itemCount)
				updateInternalInventory(robot.select())
			else
				print("Cannot craft items.")
			end
		end
	end
	robot.turnAround()
	return true
end
function checkRedstone()
	if component.redstone.getInput(sides.back) > 0 then
		if getInput() == false then
			term.clear()
			printTitle("Ultimate Program Closed")
			term.setCursor(1,3)
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
printTitle("Ultimate Program Loading","Checking External Inventory")
chests = {checkUp()}
printTitle("Ultimate Program Loading","Checking Internal Inventory")
updateInternalInventory()
printTitle("Ultimate Program Loading","Stocking Inventory")
stockInventory()
term.clear()
printTitle("Ultimate Program Running","Idle")
local stop = false
while true do
	mergeStacks()
	stockInventory()--[[
	if checkTotalInventoryCapacity() < inventorySize then
		repeat
			if checkRedstone() then stop = true; break end
			addNewChest()
		until checkTotalInventoryCapacity() >= inventorySize
		if stop then break end
	end
	mergeStacks()]]
	if checkRedstone() then break end
	addNewMiner()
	mergeStacks()
	if checkRedstone() then break end
end