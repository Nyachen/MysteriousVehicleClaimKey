--[[
	Some codes referenced from
	CarWanna - https://steamcommunity.com/workshop/filedetails/?id=2801264901
	Vehicle Recycling - https://steamcommunity.com/sharedfiles/filedetails/?id=2289429759
	K15's Mods - https://steamcommunity.com/id/KI5/myworkshopfiles/?appid=108600
--]]

-- Generic Functions that can be used by either client or server
MVCK = MVCK or {}
MVCK.UI = MVCK.UI or {}

--[[
Global variables that is accessed frequently
Both client-side and server-side have this same name variables
Important to initialise these variables accordingly in both side
dbByVehicleSQLID store the ModData AVRByVehicleID
dbMVCKByPlayerID store the ModData AVRByPlayerID
]]
MVCK.dbByVehicleSQLID = nil
MVCK.dbByPlayerID = nil

-- Ordered list of parts that cannot be removed by typical means
-- We will store server-side SQL ID in one of those
--[[
MVCK.muleParts = MVCK.muleParts or {
	"GloveBox",
	"TruckBed",
	"TruckBedOpen",
	"TrailerTrunk",
	"M101A3Trunk", -- K15 Vehicles
	"Engine"
}
--]]
-- Ingame debugger is unreliable but this does work
function MVCK.getMulePart(vehicleObj)
	local tempPart = false
	-- Split by ";"
	for s in string.gmatch(SandboxVars.MVCK.MuleParts, "([^;]+)") do
		-- Trim leading and trailing white spaces
		tempPart = vehicleObj:getPartById(s:match("^%s*(.-)%s*$"))
		if tempPart then
			return tempPart
		end
	end
	return tempPart
end

function MVCK.matchTrunkPart(strTrunk)
	if strTrunk == nil then
		return false
	end

	if type(strTrunk) == "string" and string.len(strTrunk) > 0 then
		for s in string.gmatch(SandboxVars.MVCK.TrunkParts, "([^;]+)") do
			if string.lower(s:match("^%s*(.-)%s*$")) == string.lower(strTrunk) then
				return true
			end
		end
	end
	return false
end

function MVCK.getVehicleID(vehicleObj)
	if vehicleObj:getModData().SQLID then
		return vehicleObj:getModData().SQLID
	else
		local tempPart = MVCK.getMulePart(vehicleObj)
		if tempPart then
			if tempPart:getModData().SQLID then
				if not isClient() and isServer() then
					vehicleObj:getModData().SQLID = tempPart:getModData().SQLID
					tempPart:getModData().SQLID = nil
					-- Vehicle ModData does not update immediately thus we need to force this for same cell players
					sendServerCommand("MVCK", "registerClientVehicleSQLID", {vehicleObj:getId(), vehicleObj:getModData().SQLID})
					return vehicleObj:getModData().SQLID
				else
					local tempID = tempPart:getModData().SQLID
					-- Vehicle ModData does not update immediately thus we need to use server to force this for same cell players
					sendClientCommand("MVCK", "relayClientUpdateVehicleSQLID", {vehicleObj:getId()})
					return tempID -- Workaround to resolve delay between server and client which resulted in "Claim Vehicle" label not reflecting correctly
				end
			end
		end
	end
	-- If no SQL ID
	return nil
end

function MVCK.checkMaxClaim(playerObj)
	-- Privileged users has no limit
	local playerAccessLevel = string.lower(playerObj:getAccessLevel())

	if playerAccessLevel == "admin" or playerAccessLevel == "moderator" or playerAccessLevel == "gm" then
		return true
	end

	if MVCK.dbByPlayerID[playerObj:getUsername()] == nil then return true end

	-- No easy way to get size other than count one by one, for key-value pair table
	local tempSize = 0
	for k, v in pairs(MVCK.dbByPlayerID[playerObj:getUsername()]) do
		tempSize = tempSize + 1
	end

	if tempSize - 1 >= SandboxVars.MVCK.MaxVehicle then
		return false
	else
		return true
	end
end

function MVCK.getPublicPermission(vehicleObj, permissionType)
	
	-- Get early the vehicle ID
	local vehicleSQL = vehicleObj:getModData().SQLID

	if vehicleSQL then
		local data = MVCK.dbByVehicleSQLID[vehicleSQL]

		if MVCK.dbByVehicleSQLID[vehicleSQL] then
			local data = MVCK.dbByVehicleSQLID[vehicleSQL][permissionType]

			if not data then
				return false
			else
				return data
			end
		else
			return true
		end
	else
		return true
	end
end

function MVCK.checkPermission(playerObj, vehicleObj)
	local vehicleSQL = nil
	if type(vehicleObj) ~= "number" then
		vehicleSQL = vehicleObj:getModData().SQLID
	else
		vehicleSQL = vehicleObj
	end

	-- If doesn't contain server-side SQL ID ModData,  it means yet to be imprinted therefore naturally unclaimed
	if vehicleSQL == nil then
		return true
	end

	-- Ownerless
	local ownerData = MVCK.dbByVehicleSQLID[vehicleSQL]

	if not ownerData then
		return true
	end
	
	-- Privileged users
	local playerAccessLevel = string.lower(playerObj:getAccessLevel())

	if playerAccessLevel == "admin" or playerAccessLevel == "moderator" or playerAccessLevel == "gm" then
		local details = {
			permissions = true,
			ownerid = MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID,
			LastKnownLogonTime = MVCK.dbByPlayerID[MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID].LastKnownLogonTime
		}
		return details
	end

	-- Owner
	if MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID == playerObj:getUsername() then
		local details = {
			permissions = true,
			ownerid = playerObj:getUsername(),
			LastKnownLogonTime = MVCK.dbByPlayerID[playerObj:getUsername()].LastKnownLogonTime
		}
		return details
	end
	
	-- Faction Members
	if SandboxVars.MVCK.AllowFaction then
		local factionObj = Faction.getPlayerFaction(MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID)
		if factionObj then
			if factionObj:getOwner() == playerObj:getUsername() then
				local details = {
					permissions = true,
					ownerid = MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID,
					LastKnownLogonTime = MVCK.dbByPlayerID[MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID].LastKnownLogonTime
				}
				return details
			end

			local tempPlayers = factionObj:getPlayers()
			for i = 0, tempPlayers:size() - 1 do
				if tempPlayers:get(i) == playerObj:getUsername() then
					local details = {
						permissions = true,
						ownerid = MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID,
						LastKnownLogonTime = MVCK.dbByPlayerID[MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID].LastKnownLogonTime
					}
					return details
				end
			end
		end
	end
	
	-- Safehouse Members
	if SandboxVars.MVCK.AllowSafehouse then
		local safehouseObj = SafeHouse.hasSafehouse(MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID)
		if safehouseObj then
			local tempPlayers = safehouseObj:getPlayers()
			for i = 0, tempPlayers:size() - 1 do
				if tempPlayers:get(i) == playerObj:getUsername() then
					local details = {
						permissions = true,
						ownerid = MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID,
						LastKnownLogonTime = MVCK.dbByPlayerID[MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID].LastKnownLogonTime
					}
					return details
				end
			end
		end
	end
	
	-- No permission
	local details = {
		permissions = false,
		ownerid = MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID,
		LastKnownLogonTime = MVCK.dbByPlayerID[MVCK.dbByVehicleSQLID[vehicleSQL].OwnerPlayerID].LastKnownLogonTime
	}
	return details
end

-- Simple function to convert detailed result of checkPermission into simple true or false
-- Mainly used by override functions to check basic access to vehicle
-- false which is to indicate unsupported vehicle is always returned as true in this case
function MVCK.getSimpleBooleanPermission(details)
	if type(details) == "boolean" then
		if details == false then
			details = true
		end
	end
	if type(details) ~= "boolean" then
		if details.permissions == true then
			return true
		else
			return false
		end
	end
	return details
end

function MVCK.updateVehicleCoordinate(vehicleObj)
	-- Server call, must be extreme efficient as this is called extreme frequently
	-- Do not use loop here
	if isServer() and not isClient() then
		local vehicleID = MVCK.getVehicleID(vehicleObj)
		if not vehicleID then return end
		if MVCK.dbByVehicleSQLID[vehicleID] ~= nil then
			if MVCK.dbByVehicleSQLID[vehicleID].LastLocationX ~= math.floor(vehicleObj:getX()) or MVCK.dbByVehicleSQLID[vehicleID].LastLocationY ~= math.floor(vehicleObj:getY()) then
				MVCK.dbByVehicleSQLID[vehicleID].LastLocationX = math.floor(vehicleObj:getX())
				MVCK.dbByVehicleSQLID[vehicleID].LastLocationY = math.floor(vehicleObj:getY())
				MVCK.dbByVehicleSQLID[vehicleID].LastLocationUpdateDateTime = getTimestamp()
				ModData.add("MVCKByVehicleSQLID", MVCK.dbByVehicleSQLID)
				local tempArr = {
					VehicleID = vehicleID,
					LastLocationX = math.floor(vehicleObj:getX()),
					LastLocationY = math.floor(vehicleObj:getY()),
					LastLocationUpdateDateTime = getTimestamp()
				}
				sendServerCommand("MVCK", "updateClientVehicleCoordinate", tempArr)
			end
		end
	-- Client call
	-- No plan to do client call as server seems sufficient for now
	else
	end
end

function MVCK.getUIFontScale()
	-- Size 1 is 100% aka default
	-- Size 2 is 125% aka 1x
	-- Size 3 is 150% aka 2x
	-- Size 4 is 175% aka 3x
	-- Size 5 is 200% aka 4x
	return 1 + (getCore():getOptionFontSize() - 1) / 4
end