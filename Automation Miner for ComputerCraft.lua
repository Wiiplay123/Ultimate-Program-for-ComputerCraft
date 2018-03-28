-- Automation Miner v1.1

local minFuel = 200

function beginning()
	turtle.suckDown()
	turtle.digDown()
	turtle.select(3)
	turtle.drop()
	turtle.select(2)
	turtle.drop()
	turtle.turnLeft()
	turtle.turnLeft()
	turtle.select(1)
end
beginning()

function forward()
	checkFuel()
	return turtle.forward()
end

function back()
	checkFuel()
	return turtle.back()
end

function up()
	checkFuel()
	return turtle.up()
end

function down()
	checkFuel()
	return turtle.down()
end

function returnToChest(mines,height,start)
	if turtle.getItemCount(16) > 0 then
		for i = 1, height do
			repeat
				if turtle.detectUp() then
					turtle.digUp()
				end
			until up()
		end
		turtle.turnLeft()
		turtle.turnLeft()
		for i = 1, mines * 4  do
			repeat
				if turtle.detect() then
					turtle.dig()
				end
			until forward()
		end
		for i = start, 16 do
			turtle.select(i)
			repeat until ({turtle.drop()})[2] == "No items to drop"
		end
		turtle.turnLeft()
		turtle.turnLeft()
		for i = 1, mines * 4  do
			repeat
				if turtle.detect() then
					turtle.dig()
				end
			until forward()
		end
		for i = 1, height do
			repeat
				if turtle.detectDown() then
					turtle.digDown()
				end
			until down()
		end
		turtle.select(1)
	end
end
function checkFuel()
	if turtle.getFuelLevel() < minFuel and turtle.getFuelLevel() ~= "unlimited"  then
		for p = 1, 16 do
			turtle.select(p)
			repeat
			until turtle.getFuelLevel() >= minFuel or not turtle.refuel(64)
			if turtle.getFuelLevel() >= minFuel then
				break
			end
			if p == 16 then
				print("Failed to refuel.")
			end
		end
		turtle.select(1)
	end
end
function verticalMine(mines)
	-- Move back two to get to original position
	-- Move forward four to get to next position
	local i = 0
	while true do
		repeat
			returnToChest(mines,i,1)
		until not turtle.dig()
		if not down() then
			returnToChest(mines,i,1)
			if turtle.digDown() then
				down()
				i = i + 1
			else
				break
			end
		else
			i = i + 1
		end
	end
	-- Mining is done at this point
	for o = 1, 2 do
		repeat
			turtle.dig()
			if forward() then
				break
			end
			if not up() then
				repeat
					turtle.digUp()
				until up()
			end
			i = i - 1
		until forward()
	end
	local r = i + 0
	for o = 1, r do
		if turtle.getItemCount(16) > 0 then
			if not back() then
			turtle.turnLeft()
			turtle.turnLeft()
			for p = 1, 2 do
				if not forward() then
					repeat
						turtle.dig()
					until forward()
				end
			end
			turtle.turnLeft()
			turtle.turnLeft()
			else
				if not back() then
					turtle.turnLeft()
					turtle.turnLeft()
					if not forward() then
						repeat
							turtle.dig()
						until forward()
					end
					turtle.turnLeft()
					turtle.turnLeft()
				end
			end
			returnToChest(mines,(r + 1) - o,1)
			for p = 1, 2 do
				if not forward() then
					repeat
						turtle.dig()
					until forward()
				end
			end
		end
		turtle.dig()
		if not up() then
			repeat
				turtle.digUp()
			until up()
		end
	end
end
local mines = ((#{...} > 0) and tonumber(({...})[1]) or 0)
while true do
	for i = 1, mines * 4 do
		repeat
			if turtle.detect() then
				turtle.dig()
			end
		until forward()
	end
	print("Starting vertical miner")
	verticalMine(mines)
	print("Ending vertical miner")
	turtle.turnLeft()
	turtle.turnLeft()
	for i = 1, ((mines + 1) * 4) - 2 do
		if not forward() then
			repeat
				turtle.dig()
			until forward()
		end
	end
	for i = 1, 16 do
		turtle.select(i)
		repeat until ({turtle.drop()})[2] == "No items to drop"
	end
	turtle.select(1)
	turtle.turnLeft()
	turtle.turnLeft()
	mines = mines + 1
end
