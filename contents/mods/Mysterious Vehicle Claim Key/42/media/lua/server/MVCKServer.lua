--[[
	Some codes referenced from
	CarWanna - https://steamcommunity.com/workshop/filedetails/?id=2801264901
	Vehicle Recycling - https://steamcommunity.com/sharedfiles/filedetails/?id=2289429759
	K15's Mods - https://steamcommunity.com/id/KI5/myworkshopfiles/?appid=108600
--]]

if isClient() and not isServer() then
	return
end
--[[
Global variables that is accessed frequently
sortedPlayerTimeoutClaim is a table sorted in last known logon time timestamp and associoated player id
--]]
MVCK.sortedPlayerTimeoutClaim = nil

-- Common functions
function MVCK.sortCacheNow()
	table.sort(MVCK.sortedPlayerTimeoutClaim, function(a, b) return a.ExpiryTime < b.ExpiryTime end)
end

--[[
The global modData is basically the database for this vehicle claiming mod
This global moddata is actively shared with the clients
The clients will do most of the checking which help keep the server light

There are two ModData which is storing it by Vehicle SQL ID or Player ID
I have both because I want to minimize looping to perform differnt things

ModData AVRByVehicleID is stored like this
<Vehicle SQL ID>
- <OwnerPlayerID>
- <ClaimDateTime>
- <CarModel>
- <LastLocationX>
- <LastLocationY>
- <LastLocationUpdateDateTime>

ModData AVRByPlayerID is stored like this
<OwnerPlayerID>
- <LastKnownLogonTime>
- <Vehicle SQL ID 1>
- <Vehicle SQL ID 2>
and so on
--]]

-- vehicleID is vehicle object ID
function MVCK.claimVehicle(playerObj, vehicleID)
	local vehicleObj = getVehicleById(vehicleID.vehicle)
	vehicleID = MVCK.getVehicleID(vehicleObj)
	-- If no ID, we create one
	if not vehicleID then
		vehicleObj:getModData().SQLID = tonumber(getTimestamp() .. vehicleObj:getSqlId())
		vehicleID = vehicleObj:getModData().SQLID
		sendServerCommand("MVCK", "registerClientVehicleSQLID", {vehicleObj:getId(), vehicleObj:getModData().SQLID})
	end

	-- Make sure is not already claimed
	-- Only SQL ID is persistent, vehicleID is created on runtime
	if MVCK.dbByVehicleSQLID[vehicleID] then
		-- Using vanilla logging function, write to a log with suffix MVCK
		-- Datetime, Unix Time, Warning message, offender username, vehicle full name, coordinate
		-- [26-03-23 22:23:36.671] [1679840616] Warning: Attempting to claim already owned vehicle [Username] [Base.ExtremeCar] [13026,1215]
		if playerObj ~= nil then
			writeLog("MVCK", "[" .. getTimestamp() .. "] Warning: Attempting to claim already owned vehicle [" .. playerObj:getUsername() .. "] [" .. vehicleObj:getScript():getFullName() .. "] [" .. math.floor(vehicleObj:getX()) .. "," .. math.floor(vehicleObj:getY()) .. "]")
			sendServerCommand(playerObj, "MVCK", "forcesyncClientGlobalModData", {})
		end
	else
		MVCK.dbByVehicleSQLID[vehicleID] = {
			OwnerPlayerID = playerObj:getUsername(),
			ClaimDateTime = getTimestamp(),
			CarModel = vehicleObj:getScript():getFullName(),
			LastLocationX = math.floor(vehicleObj:getX()),
			LastLocationY = math.floor(vehicleObj:getY()),
			LastLocationUpdateDateTime = getTimestamp()
		}
		
		-- Minimum data to send to clients
		local tempArr = {
			VehicleID = vehicleID,
			OwnerPlayerID = playerObj:getUsername(),
			ClaimDateTime = getTimestamp(),
			CarModel = vehicleObj:getScript():getFullName(),
			LastLocationX = math.floor(vehicleObj:getX()),
			LastLocationY = math.floor(vehicleObj:getY()),
			LastLocationUpdateDateTime = getTimestamp()
		}
		
		-- Store the updated ModData --
		ModData.add("MVCKByVehicleSQLID", MVCK.dbByVehicleSQLID)
		
		if not MVCK.dbByPlayerID[playerObj:getUsername()] then
			MVCK.dbByPlayerID[playerObj:getUsername()] = {
				[vehicleID] = true,
				LastKnownLogonTime = getTimestamp()
			}

			-- New player, insert it to the cache, theorically should be the latest entry
			table.insert(MVCK.sortedPlayerTimeoutClaim, {ExpiryTime = (MVCK.dbByPlayerID[playerObj:getUsername()].LastKnownLogonTime + (SandboxVars.MVCK.ClaimTimeout * 60 * 60)), OwnerPlayerID = playerObj:getUsername()})
		else
			MVCK.dbByPlayerID[playerObj:getUsername()][vehicleID] = true
			MVCK.dbByPlayerID[playerObj:getUsername()].LastKnownLogonTime = getTimestamp()
		end
		
		-- Store the updated ModData --
		ModData.add("MVCKByPlayerID", MVCK.dbByPlayerID)
		
		--[[ Send the updated ModData to all clients
		ModData.transmit("MVCKByVehicleSQLID")
		ModData.transmit("MVCKByPlayerID")
		You could transmit the entire Global ModData but that can become bandwidth expensive
		So, we will send the bare minimum instead. We hope this won't be desynced
		Clients will always obtain be latest global ModData onConnected
		--]] 
		sendServerCommand("MVCK", "updateClientClaimVehicle", tempArr)
	end
end

-- vehicleID is SQL ID
function MVCK.unclaimVehicle(playerObj, vehicleID)
	if MVCK.dbByVehicleSQLID[vehicleID] then
		local ownerPlayerID = MVCK.dbByVehicleSQLID[vehicleID].OwnerPlayerID
		MVCK.dbByVehicleSQLID[vehicleID] = nil
		
		-- Store the updated ModData --
		ModData.add("MVCKByVehicleSQLID", MVCK.dbByVehicleSQLID)
		
		if MVCK.dbByPlayerID[ownerPlayerID][vehicleID] then
			MVCK.dbByPlayerID[ownerPlayerID][vehicleID] = nil
		end

		-- If the player has 0 vehicle, remove it completely
		local tempCount = 0
		for k, v in pairs(MVCK.dbByPlayerID[ownerPlayerID]) do
			if k ~= "LastKnownLogonTime" then
				tempCount = tempCount + 1
			end
			if tempCount >= 1 then
				break
			end
		end
		
		if tempCount == 0 then
			MVCK.dbByPlayerID[ownerPlayerID] = nil
		end

		-- Store the updated ModData --
		ModData.add("MVCKByPlayerID", MVCK.dbByPlayerID)
		
		-- Case sensitive
		local tempArr = {
			VehicleID = vehicleID,
			OwnerPlayerID = ownerPlayerID
		}
		
		--[[ Send the updated ModData to all clients
		ModData.transmit("MVCKByVehicleSQLID")
		ModData.transmit("MVCKByPlayerID")
		You could transmit the entire Global ModData but that can become bandwidth expensive
		So, we will send the bare minimum instead. We hope this won't be desynced
		Clients will always obtain be latest global ModData onConnected
		--]]
		
		sendServerCommand("MVCK", "updateClientUnclaimVehicle", tempArr)
	else
		if playerObj ~= nil then
			sendServerCommand(playerObj, "MVCK", "forcesyncClientGlobalModData", {})
		end
	end
end

-- Update Player Logon Time
function MVCK.updateLastKnownLogonTime(playerObj)
	if MVCK.dbByPlayerID[playerObj:getUsername()] ~= nil then
		MVCK.dbByPlayerID[playerObj:getUsername()].LastKnownLogonTime = getTimestamp()

		local tempArr = {
			PlayerID = playerObj:getUsername(),
			LastKnownLogonTime = MVCK.dbByPlayerID[playerObj:getUsername()].LastKnownLogonTime,
		}
		sendServerCommand("MVCK", "updateClientLastLogon", tempArr)
		ModData.add("MVCKByPlayerID", MVCK.dbByPlayerID)
	end
end

function MVCK.updateSpecifyVehicleUserPermission(arg)

	if MVCK.dbByVehicleSQLID[arg.VehicleID] then
		for k, v in pairs(arg) do
			if k ~= "VehicleID" then
				if v then
					MVCK.dbByVehicleSQLID[arg.VehicleID][k] = v
				else
					MVCK.dbByVehicleSQLID[arg.VehicleID][k] = nil
				end
			end
		end
		ModData.add("MVCKByVehicleSQLID", MVCK.dbByVehicleSQLID)
		sendServerCommand("MVCK", "updateClientSpecifyVehicleUserPermission", arg)
	end
end

-- Database might become inconsistent with one another due to whatever reasons
-- Using MVCKByVehicleSQLID as base, we will rebuild the Database on server start
function MVCK.rebuildDB()
	local tempDB = {}
	for k, v in pairs(MVCK.dbByVehicleSQLID) do
		if not tempDB[v.OwnerPlayerID] then
			tempDB[v.OwnerPlayerID] = {}
		end

		tempDB[v.OwnerPlayerID][k] = true
		if MVCK.dbByPlayerID[v.OwnerPlayerID].LastKnownLogonTime then
			tempDB[v.OwnerPlayerID].LastKnownLogonTime = MVCK.dbByPlayerID[v.OwnerPlayerID].LastKnownLogonTime
		else
			tempDB[v.OwnerPlayerID].LastKnownLogonTime = getTimestamp()
		end
	end

	MVCK.dbByPlayerID = tempDB
	ModData.add("MVCKByPlayerID", MVCK.dbByPlayerID)
end

MVCK.onClientCommand = function(moduleName, command, playerObj, arg)
	if moduleName == "MVCK" and command == "claimVehicle" then
		MVCK.claimVehicle(playerObj, arg)
	elseif moduleName == "MVCK" and command == "unclaimVehicle" then
		-- Game send everything as table...
		-- So we do arg[1] to get SQL ID
		if SandboxVars.MVCK.ServerSideChecking then
			local checkResult = MVCK.checkPermission(playerObj, arg[1])

			if type(checkResult) == "boolean" then
				if checkResult == false then
					-- Using vanilla logging function, write to a log with suffix MVCK
					-- Datetime, Unix Time, Warning message, offender username, vehicle full name, coordinate
					-- [26-03-23 22:23:36.671] [1679840616] Warning: Attempting to unclaim without permission [Username] [Base.ExtremeCar] [13026,1215]
					writeLog("MVCK", "[" .. getTimestamp() .. "] Warning: Attempting to unclaim without permission [" .. playerObj:getUsername() .. "] [" .. MVCK.dbByVehicleSQLID[arg[1]].CarModel .. "] [" .. MVCK.dbByVehicleSQLID[arg[1]].LastLocationX .. "," .. MVCK.dbByVehicleSQLID[arg[1]].LastLocationY .. "]")

					-- Possible desync has occurred, force sync the user
					sendServerCommand(playerObj, "MVCK", "forcesyncClientGlobalModData", {})
					return
				end
			elseif checkResult.permissions == false then
				-- Using vanilla logging function, write to a log with suffix MVCK
				-- Datetime, Unix Time, Warning message, offender username, vehicle full name, coordinate
				-- [26-03-23 22:23:36.671] [1679840616] Warning: Attempting to unclaim without permission [Username] [Base.ExtremeCar] [13026,1215]
				writeLog("MVCK", "[" .. getTimestamp() .. "] Warning: Attempting to unclaim without permission [" .. playerObj:getUsername() .. "] [" .. MVCK.dbByVehicleSQLID[arg[1]].CarModel .. "] [" .. MVCK.dbByVehicleSQLID[arg[1]].LastLocationX .. "," .. MVCK.dbByVehicleSQLID[arg[1]].LastLocationY .. "]")

				-- Possible desync has occurred, force sync the user
				sendServerCommand(playerObj, "MVCK", "forcesyncClientGlobalModData", {})
				return
			end
		end
		MVCK.unclaimVehicle(playerObj, arg[1])
	elseif moduleName == "MVCK" and command == "updateLastKnownLogonTime" then
		MVCK.updateLastKnownLogonTime(playerObj)
	elseif moduleName == "MVCK" and command == "updateSpecifyVehicleUserPermission" then
		-- arg should be table of a lot of things
		-- VehicleID
		-- Permission types like AllowDrive, AllowPassenger
		if SandboxVars.MVCK.ServerSideChecking then
			local checkResult = MVCK.checkPermission(playerObj, arg.VehicleID)

			if type(checkResult) == "boolean" then
				if checkResult == false then
					-- Using vanilla logging function, write to a log with suffix MVCK
					-- Datetime, Unix Time, Warning message, offender username, vehicle full name, coordinate
					-- [26-03-23 22:23:36.671] [1679840616] Warning: Attempting to unclaim without permission [Username] [Base.ExtremeCar] [13026,1215]
					writeLog("MVCK", "[" .. getTimestamp() .. "] Warning: Attempting to modify specific vehicle permissions without permission [" .. playerObj:getUsername() .. "] [" .. MVCK.dbByVehicleSQLID[arg.VehicleID].CarModel .. "]")

					-- Possible desync has occurred, force sync the user
					sendServerCommand(playerObj, "MVCK", "forcesyncClientGlobalModData", {})
					return
				end
			elseif checkResult.permissions == false then
				-- Using vanilla logging function, write to a log with suffix MVCK
				-- Datetime, Unix Time, Warning message, offender username, vehicle full name, coordinate
				-- [26-03-23 22:23:36.671] [1679840616] Warning: Attempting to unclaim without permission [Username] [Base.ExtremeCar] [13026,1215]
				writeLog("MVCK", "[" .. getTimestamp() .. "] Warning: Attempting to modify specific vehicle permissions without permission [" .. playerObj:getUsername() .. "] [" .. MVCK.dbByVehicleSQLID[arg.VehicleID].CarModel .. "]")

				-- Possible desync has occurred, force sync the user
				sendServerCommand(playerObj, "MVCK", "forcesyncClientGlobalModData", {})
				return
			end
		end
		MVCK.updateSpecifyVehicleUserPermission(arg)
	elseif moduleName == "MVCK" and command == "rebuildDB" then
		if playerObj:getAccessLevel() == "admin" then
			MVCK.rebuildDB()
		end
	elseif moduleName == "MVCK" and command == "relayClientUpdateVehicleSQLID" then
		-- Transition from Mule Part SQLID to Vehicle SQLID
		-- Relay ModData changes
		local vehicleObj = getVehicleById(arg[1])
		if vehicleObj then
			-- We removing at server-side because client-side takes time to be updated to the server
			-- Client-side mod data changes can unfortunately be lost if server shutdown at this very moment
			-- It just bad game design thus we doing it at server-side in hope that the changes is saved if that happens
			local tempPart = MVCK.getMulePart(vehicleObj)
			vehicleObj:getModData().SQLID = tempPart:getModData().SQLID
			tempPart:getModData().SQLID = nil
			sendServerCommand("MVCK", "registerClientVehicleSQLID", {vehicleObj:getId(), vehicleObj:getModData().SQLID})
		end
	end
end

-- Remove given player ID from DBs completely
-- This hopefully thororughly remove the player from server-side Global ModData
-- We don't really need to care about client-side MVCKByPlayerID Global ModData as client will always get new fresh set onConnected
-- We do need to care about server-side as we don't want the MVCKByPlayerID to be bloated which will slow down other functions
function MVCK.removePlayerCompletely(playerID)
	if MVCK.dbByPlayerID[playerID] ~= nil then
		for k, v in pairs(MVCK.dbByPlayerID[playerID]) do
			if k ~= "LastKnownLogonTime" then
				MVCK.unclaimVehicle(nil, k)
			end
		end
	end
end

--[[
Transform dbMVCKByPlayerID into array of {LastKnownLogonTime, OwnerPlayerID}
--]]
local function createSortedPlayerTimeoutClaim()
	local temp = {}
	for k, v in pairs(MVCK.dbByPlayerID) do
		table.insert(temp, {ExpiryTime = (v.LastKnownLogonTime + (SandboxVars.MVCK.ClaimTimeout * 60 * 60)), OwnerPlayerID = k})
	end

	MVCK.sortedPlayerTimeoutClaim = temp
	MVCK.sortCacheNow()
end

function MVCK.doClaimTimeout()
	local varIndex = 1
	local needSort = false
	-- As we dealing with indexes, we want to control the index value as we increment to avoid removing wrong index
	while varIndex <= #MVCK.sortedPlayerTimeoutClaim do
		if getTimestamp() > MVCK.sortedPlayerTimeoutClaim[varIndex].ExpiryTime then
			if MVCK.dbByPlayerID[MVCK.sortedPlayerTimeoutClaim[varIndex].OwnerPlayerID] ~= nil then
				-- Cache is not always up-to-date, validate the actual
				if getTimestamp() > (MVCK.dbByPlayerID[MVCK.sortedPlayerTimeoutClaim[varIndex].OwnerPlayerID].LastKnownLogonTime + (SandboxVars.MVCK.ClaimTimeout * 60 * 60)) then
					MVCK.removePlayerCompletely(MVCK.sortedPlayerTimeoutClaim[varIndex].OwnerPlayerID)
					table.remove(MVCK.sortedPlayerTimeoutClaim, varIndex)
				else
					-- Update the expiry time
					MVCK.sortedPlayerTimeoutClaim[varIndex].ExpiryTime = (MVCK.dbByPlayerID[MVCK.sortedPlayerTimeoutClaim[varIndex].OwnerPlayerID].LastKnownLogonTime + (SandboxVars.MVCK.ClaimTimeout * 60 * 60))
					needSort = true
					varIndex = varIndex + 1
				end
			else
				-- User no longer exist, remove from index
				table.remove(MVCK.sortedPlayerTimeoutClaim, varIndex)
			end
		else
			-- Since sorted, assume everybody else has not expired
			break
		end
	end

	if needSort then
		MVCK.sortCacheNow()
	end
end

local function OnInitGlobalModData(isNewGame)
	-- When Mod first added to server
	if not ModData.exists("MVCKByVehicleSQLID") then ModData.create("MVCKByVehicleSQLID") end
	if not ModData.exists("MVCKByPlayerID") then ModData.create("MVCKByPlayerID") end

	-- Set global variable as this is frequently accessed
	MVCK.dbByVehicleSQLID = ModData.get("MVCKByVehicleSQLID")
	MVCK.dbByPlayerID = ModData.get("MVCKByPlayerID")

	if SandboxVars.MVCK.RebuildDB then
		MVCK.rebuildDB()
	end

	createSortedPlayerTimeoutClaim()
end

Events.OnInitGlobalModData.Add(OnInitGlobalModData)
Events.EveryTenMinutes.Add(MVCK.doClaimTimeout)
Events.OnClientCommand.Add(MVCK.onClientCommand)