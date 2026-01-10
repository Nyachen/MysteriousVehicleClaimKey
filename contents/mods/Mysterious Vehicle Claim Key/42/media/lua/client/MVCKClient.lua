--[[
	Some codes referenced from
	CarWanna - https://steamcommunity.com/workshop/filedetails/?id=2801264901
	Vehicle Recycling - https://steamcommunity.com/sharedfiles/filedetails/?id=2289429759
	K15's Mods - https://steamcommunity.com/id/KI5/myworkshopfiles/?appid=108600
--]]

if not isClient() and isServer() then
	return
end

function MVCK.updateClientClaimVehicle(arg)
	-- A desync has occurred, this shouldn't happen
	-- We will request full data from server
	if MVCK.dbByVehicleSQLID == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end

	MVCK.dbByVehicleSQLID[arg.VehicleID] = {
		OwnerPlayerID = arg.OwnerPlayerID,
		ClaimDateTime = arg.ClaimDateTime,
		CarModel = arg.CarModel,
		LastLocationX = arg.LastLocationX,
		LastLocationY = arg.LastLocationY,
		LastLocationUpdateDateTime = arg.LastLocationUpdateDateTime
	}

	if not MVCK.dbByPlayerID[arg.OwnerPlayerID] then
		MVCK.dbByPlayerID[arg.OwnerPlayerID] = {
			[arg.VehicleID] = true,
			LastKnownLogonTime = getTimestamp()
		}
	else
		MVCK.dbByPlayerID[arg.OwnerPlayerID][arg.VehicleID] = true
		MVCK.dbByPlayerID[arg.OwnerPlayerID].LastKnownLogonTime = getTimestamp()
	end
end

function MVCK.updateClientUnclaimVehicle(arg)
	-- A desync has occurred, this shouldn't happen
	-- We will request full data from server
	if MVCK.dbByVehicleSQLID == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end
	
	if MVCK.dbByVehicleSQLID[arg.VehicleID] == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end
	
	MVCK.dbByVehicleSQLID[arg.VehicleID] = nil
	MVCK.dbByPlayerID[arg.OwnerPlayerID][arg.VehicleID] = nil
end

function MVCK.updateClientVehicleCoordinate(arg)
	-- A desync has occurred, this shouldn't happen
	-- We will request full data from server
	if MVCK.dbByVehicleSQLID == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end

	if MVCK.dbByVehicleSQLID[arg.VehicleID] == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end

	MVCK.dbByVehicleSQLID[arg.VehicleID].LastLocationX = arg.LastLocationX
	MVCK.dbByVehicleSQLID[arg.VehicleID].LastLocationY = arg.LastLocationY
	MVCK.dbByVehicleSQLID[arg.VehicleID].LastLocationUpdateDateTime = arg.LastLocationUpdateDateTime
end

function MVCK.updateClientLastLogon(arg)
	if MVCK.dbByPlayerID == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end

	if MVCK.dbByPlayerID[arg.PlayerID] == nil then
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
		return
	end

	MVCK.dbByPlayerID[arg.PlayerID].LastKnownLogonTime = arg.LastKnownLogonTime
end

function MVCK.forcesyncClientGlobalModData()
	ModData.request("MVCKByVehicleSQLID")
	ModData.request("MVCKByPlayerID")
end

function MVCK.updateClientSpecifyVehicleUserPermission(arg)
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
	else
		ModData.request("MVCKByVehicleSQLID")
		ModData.request("MVCKByPlayerID")
	end
end

-- Vehicle ModData does not update immediately, workaround to force sync
function MVCK.registerClientVehicleSQLID(arg)
	local vehicleObj = getVehicleById(arg[1])
	if vehicleObj then
		vehicleObj:getModData().SQLID = arg[2]
	end
end

MVCK.OnServerCommand = function(moduleName, command, arg)
	if moduleName == "MVCK" and command == "updateClientClaimVehicle" then
		MVCK.updateClientClaimVehicle(arg)
	elseif moduleName == "MVCK" and command == "updateClientUnclaimVehicle" then
		MVCK.updateClientUnclaimVehicle(arg)
	elseif moduleName == "MVCK" and command == "updateClientVehicleCoordinate" then
		MVCK.updateClientVehicleCoordinate(arg)
	elseif moduleName == "MVCK" and command == "updateClientLastLogon" then
		MVCK.updateClientLastLogon(arg)
	elseif moduleName == "MVCK" and command == "forcesyncClientGlobalModData" then
		MVCK.forcesyncClientGlobalModData()
	elseif moduleName == "MVCK" and command == "updateClientSpecifyVehicleUserPermission" then
		MVCK.updateClientSpecifyVehicleUserPermission(arg)
	elseif moduleName == "MVCK" and command == "registerClientVehicleSQLID" then
		MVCK.registerClientVehicleSQLID(arg)
	end
end

local function openClientUserManager()
	if MVCK.UI.UserInstance ~= nil then
		MVCK.UI.UserInstance:close()
	end

	local width = math.floor(650 * MVCK.getUIFontScale())
    local height = math.floor(350 * MVCK.getUIFontScale())

    local x = getCore():getScreenWidth() / 2 - (width / 2)
    local y = getCore():getScreenHeight() / 2 - (height / 2)

    MVCK.UI.UserInstance = MVCK.UI.UserManagerMain:new(x, y, width, height)
    MVCK.UI.UserInstance:initialise()
    MVCK.UI.UserInstance:addToUIManager()
    MVCK.UI.UserInstance:setVisible(true)
end

local function openClientAdminManager()
	if MVCK.UI.AdminInstance ~= nil then
		MVCK.UI.AdminInstance:close()
	end

	local width = math.floor(955 * MVCK.getUIFontScale())
    local height = math.floor(500 * MVCK.getUIFontScale())

    local x = getCore():getScreenWidth() / 2 - (width / 2)
    local y = getCore():getScreenHeight() / 2 - (height / 2)

    MVCK.UI.AdminInstance = MVCK.UI.AdminManagerMain:new(x, y, width, height)
    MVCK.UI.AdminInstance:initialise()
    MVCK.UI.AdminInstance:addToUIManager()
    MVCK.UI.AdminInstance:setVisible(true)
end

function MVCK.ClientOnPreFillWorldObjectContextMenu(player, context, worldObjects, test)
    context:addOption(getText("ContextMenu_MVCK_ClientUserUI"), worldObjects, openClientUserManager, nil)

	-- Check if user is administrative level
	local playerAccessLevel = string.lower(getPlayer():getAccessLevel())

	if (playerAccessLevel == "admin" or playerAccessLevel == "moderator" or playerAccessLevel == "gm") or (not isClient() and not isServer()) then
		context:addOption(getText("ContextMenu_MVCK_AdminUserUI"), worldObjects, openClientAdminManager, nil)
	end
end

function MVCK.ClientOnReceiveGlobalModData(key, modData)
	if key == "MVCKByVehicleSQLID" then
		MVCK.dbByVehicleSQLID = modData
	end
	if key == "MVCKByPlayerID" then
		MVCK.dbByPlayerID = modData
	end
end

function MVCK.ClientEveryHours()
	if MVCK.dbByPlayerID[getPlayer():getUsername()] ~= nil then
		sendClientCommand(getPlayer(), "MVCK", "updateLastKnownLogonTime", nil)
	end
end

function MVCK.AfterGameStart()
	ModData.request("MVCKByVehicleSQLID")
	ModData.request("MVCKByPlayerID")
	sendClientCommand(getPlayer(), "MVCK", "updateLastKnownLogonTime", nil)
	Events.OnServerCommand.Add(MVCK.OnServerCommand)
	Events.OnTick.Remove(MVCK.AfterGameStart)
end

Events.OnReceiveGlobalModData.Add(MVCK.ClientOnReceiveGlobalModData)
Events.OnTick.Add(MVCK.AfterGameStart)
Events.OnPreFillWorldObjectContextMenu.Add(MVCK.ClientOnPreFillWorldObjectContextMenu)
Events.EveryHours.Add(MVCK.ClientEveryHours)