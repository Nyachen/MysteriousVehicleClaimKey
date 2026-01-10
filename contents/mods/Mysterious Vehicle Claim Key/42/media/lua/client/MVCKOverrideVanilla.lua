--[[
	Some codes referenced from
	CarWanna - https://steamcommunity.com/workshop/filedetails/?id=2801264901
	Vehicle Recycling - https://steamcommunity.com/sharedfiles/filedetails/?id=2289429759
	K15's Mods - https://steamcommunity.com/id/KI5/myworkshopfiles/?appid=108600
]]--

if not isClient() and isServer() then
	return
end

require "ISUI/ISModalDialog"
require "luautils"

local function claimVehicle(player, button, vehicle)
    if button.internal == "NO" then return end
    if luautils.walkAdj(player, vehicle:getSquare()) then
        ISTimedActionQueue.add(ISMVCKVehicleClaimAction:new(player, vehicle))
    end
end

local function claimCfmDialog(player, vehicle)
    local message = string.format("Confirm", vehicle:getScript():getName())
    local playerNum = player:getPlayerNum()
    local modal = ISModalDialog:new((getCore():getScreenWidth() / 2) - (300 / 2), (getCore():getScreenHeight() / 2) - (150 / 2), 300, 150, message, true, player, claimVehicle, playerNum, vehicle)
    modal:initialise();
    modal:addToUIManager();
end

local function unclaimVehicle(player, button, vehicle)
    if button.internal == "NO" then return end
    if luautils.walkAdj(player, vehicle:getSquare()) then
        ISTimedActionQueue.add(ISMVCKVehicleUnclaimAction:new(player, vehicle))
    end
end

local function unclaimCfmDialog(player, vehicle)
    local message = string.format("Confirm", vehicle:getScript():getName())
    local playerNum = player:getPlayerNum()
    local modal = ISModalDialog:new((getCore():getScreenWidth() / 2) - (300 / 2), (getCore():getScreenHeight() / 2) - (150 / 2), 300, 150, message, true, player, unclaimVehicle, playerNum, vehicle)
    modal:initialise();
    modal:addToUIManager();
end

-- Copy and override the vanilla menu to add our context menu in
function MVCK.addOptionToMenuOutsideVehicle(player, context, vehicle)
	-- Ignore wrecks
	if string.match(string.lower(vehicle:getScript():getName()), "burnt") or string.match(string.lower(vehicle:getScript():getName()), "smashed") then
		return
	end

	local checkResult = MVCK.checkPermission(player, vehicle)
	local option
	local toolTip
	toolTip = ISToolTip:new()
	toolTip:initialise()
	toolTip:setVisible(false)

	if type(checkResult) == "boolean" then
		if checkResult == true then
			local playerInv = player:getInventory()
			-- Free car
			option = context:addOption(getText("ContextMenu_MVCK_ClaimVehicle"), player, claimCfmDialog, vehicle)
			option.toolTip = toolTip
			if playerInv:getItemCount("Base.MysteriousVehicleClaimKey") < 1 and SandboxVars.MVCK.RequireTicket then
				toolTip.description = getText("Tooltip_MVCK_Needs") .. " <LINE><RGB:1,0.2,0.2>" .. getItemNameFromFullType("Base.MysteriousVehicleClaimKey") .. " " .. playerInv:getItemCount("Base.MysteriousVehicleClaimKey") .. "/1"
				option.notAvailable = true
			else
				if MVCK.checkMaxClaim(player) then
					if SandboxVars.MVCK.RequireTicket then
						toolTip.description = getText("Tooltip_MVCK_Needs") .. " <LINE><RGB:0.2,1,0.2>" .. getItemNameFromFullType("Base.MysteriousVehicleClaimKey") .. " " .. playerInv:getItemCount("Base.MysteriousVehicleClaimKey") .. "/1"
					else
						toolTip.description = getText("Tooltip_MVCK_ClaimVehicle")
					end
					option.notAvailable = false
				else
					toolTip.description = "<RGB:0.2,1,0.2>" .. getText("Tooltip_MVCK_ExceedLimit")
					option.notAvailable = true
				end
			end
		elseif checkResult == false then
			-- Not supported vehicle
			option = context:addOption(getText("ContextMenu_MVCK_UnsupportedVehicle"), player, claimCfmDialog, vehicle)
			option.toolTip = toolTip
			toolTip.description = getText("Tooltip_MVCK_Unsupported")
			option.notAvailable = true
		end
	elseif checkResult.permissions == true then
		-- Owned car
		option = context:addOption(getText("ContextMenu_MVCK_UnclaimVehicle"), player, unclaimCfmDialog, vehicle)
		option.toolTip = toolTip
		toolTip.description = getText("Tooltip_MVCK_Owner") .. ": " .. checkResult.ownerid .. " <LINE>" .. getText("Tooltip_MVCK_Expire") .. ": " .. os.date("%d-%b-%y, %H:%M:%S", (checkResult.LastKnownLogonTime + (SandboxVars.MVCK.ClaimTimeout * 60 * 60)))
		option.notAvailable = false
	elseif checkResult.permissions == false then
		-- Owned car
		option = context:addOption(getText("ContextMenu_MVCK_UnclaimVehicle"), player, unclaimCfmDialog, vehicle)
		option.toolTip = toolTip
		toolTip.description = getText("Tooltip_MVCK_Owner") .. ": " .. checkResult.ownerid .. " <LINE>" .. getText("Tooltip_MVCK_Expire") .. ": " .. os.date("%d-%b-%y, %H:%M:%S", (checkResult.LastKnownLogonTime + (SandboxVars.MVCK.ClaimTimeout * 60 * 60)))
		option.notAvailable = true
	end

	-- Must not be towing or towed
	if vehicle:getVehicleTowedBy() ~= nil or vehicle:getVehicleTowing() ~= nil then
		toolTip.description = getText("Tooltip_MVCK_Towed")
		option.notAvailable = true
	end
end

if not MVCK.oMenuOutsideVehicle then
    MVCK.oMenuOutsideVehicle = ISVehicleMenu.FillMenuOutsideVehicle
end

function ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)
    MVCK.oMenuOutsideVehicle(player, context, vehicle, test)
    MVCK.addOptionToMenuOutsideVehicle(getSpecificPlayer(player), context, vehicle)
end

--[[
Overriding vanilla actions functions by copying the orginal functions then check permissions before calling the original
Avoid overriding isValid as that function is called on every validation which happen on every tick until action is completed
--]]

-- Copy and override the vanilla ISEnterVehicle to block unauthorized users
if not MVCK.oIsEnterVehicle then
    MVCK.oIsEnterVehicle = ISEnterVehicle.new
end

function ISEnterVehicle:new(character, vehicle, seat)
	-- For non-driver seats, driver seat is 0
    if seat ~= 0 then
		if MVCK.getPublicPermission(vehicle, "AllowPassenger") then
			return MVCK.oIsEnterVehicle(self, character, vehicle, seat)
		end
	end

	if seat == 0 then
		if MVCK.getPublicPermission(vehicle, "AllowDrive") then
			return MVCK.oIsEnterVehicle(self, character, vehicle, seat)
		end
	end
	
	local checkResult = MVCK.checkPermission(character, vehicle)
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oIsEnterVehicle(self, character, vehicle, seat)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISSwitchVehicleSeat to block unauthorized users
if not MVCK.oISSwitchVehicleSeat then
    MVCK.oISSwitchVehicleSeat = ISSwitchVehicleSeat.new
end

function ISSwitchVehicleSeat:new(character, seatTo)
	if not character:getVehicle() then
		return MVCK.oISSwitchVehicleSeat(self, character, seatTo)
	end

	-- For non-driver seats, driver seat is 0
    if seatTo ~= 0 then
		if MVCK.getPublicPermission(character:getVehicle(), "AllowPassenger") then
			return MVCK.oISSwitchVehicleSeat(self, character, seatTo)
		end
	end

	if seatTo == 0 then
		if MVCK.getPublicPermission(character:getVehicle(), "AllowDrive") then
			return MVCK.oISSwitchVehicleSeat(self, character, seatTo)
		end
	end

	local checkResult = MVCK.checkPermission(character, character:getVehicle())
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISSwitchVehicleSeat(self, character, seatTo)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISAttachTrailerToVehicle to block unauthorized users
if not MVCK.oISAttachTrailerToVehicle then
    MVCK.oISAttachTrailerToVehicle = ISAttachTrailerToVehicle.new
end

function ISAttachTrailerToVehicle:new(character, vehicleA, vehicleB, attachmentA, attachmentB)
	local checkResultA = MVCK.getPublicPermission(vehicleA, "AllowAttachVehicle")
	local checkResultB = MVCK.getPublicPermission(vehicleB, "AllowAttachVehicle")

	if checkResultA and checkResultB then
		return MVCK.oISAttachTrailerToVehicle(self, character, vehicleA, vehicleB, attachmentA, attachmentB)
	end

	checkResultA = MVCK.checkPermission(character, vehicleA)
	checkResultB = MVCK.checkPermission(character, vehicleB)
	checkResultA = MVCK.getSimpleBooleanPermission(checkResultA)
	checkResultB = MVCK.getSimpleBooleanPermission(checkResultB)

	if checkResultA and checkResultB then
		return MVCK.oISAttachTrailerToVehicle(self, character, vehicleA, vehicleB, attachmentA, attachmentB)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISDetachTrailerFromVehicle to block unauthorized users
if not MVCK.oISDetachTrailerFromVehicle then
    MVCK.oISDetachTrailerFromVehicle = ISDetachTrailerFromVehicle.new
end

function ISDetachTrailerFromVehicle:new(character, vehicle, attachment)
	local checkResult = MVCK.getPublicPermission(vehicle, "AllowDetechVehicle")

	if checkResult then
		return MVCK.oISDetachTrailerFromVehicle(self, character, vehicle, attachment)
	end

	checkResult = MVCK.checkPermission(character, vehicle)
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISDetachTrailerFromVehicle(self, character, vehicle, attachment)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISUninstallVehiclePart to block unauthorized users
if not MVCK.oISUninstallVehiclePart then
    MVCK.oISUninstallVehiclePart = ISUninstallVehiclePart.new
end

function ISUninstallVehiclePart:new(character, part, time)
	local checkResult = MVCK.getPublicPermission(part:getVehicle(), "AllowUninstallParts")

	if checkResult then
		return MVCK.oISUninstallVehiclePart(self, character, part, time)
	end

	checkResult = MVCK.checkPermission(character, part:getVehicle())
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISUninstallVehiclePart(self, character, part, time)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISTakeGasolineFromVehicle to block unauthorized users
if not MVCK.oISTakeGasolineFromVehicle then
    MVCK.oISTakeGasolineFromVehicle = ISTakeGasolineFromVehicle.new
end

function ISTakeGasolineFromVehicle:new(character, part, item, time)
	local checkResult = MVCK.getPublicPermission(part:getVehicle(), "AllowSiphonFuel")

	if checkResult then
		return MVCK.oISTakeGasolineFromVehicle(self, character, part, item, time)
	end

	checkResult = MVCK.checkPermission(character, part:getVehicle())
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISTakeGasolineFromVehicle(self, character, part, item, time)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISTakeEngineParts to block unauthorized users
if not MVCK.oISTakeEngineParts then
    MVCK.oISTakeEngineParts = ISTakeEngineParts.new
end

function ISTakeEngineParts:new(character, part, item, time)	
	local checkResult = MVCK.getPublicPermission(part:getVehicle(), "AllowTakeEngineParts")

	if checkResult then
		return MVCK.oISTakeEngineParts(self, character, part, item, time)
	end

	checkResult = MVCK.checkPermission(character, part:getVehicle())
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISTakeEngineParts(self, character, part, item, time)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISDeflateTire to block unauthorized users
if not MVCK.oISInflateTire then
    MVCK.oISInflateTire = ISInflateTire.new
end

function ISInflateTire:new(character, part, item, psiTarget)	
	local checkResult = MVCK.getPublicPermission(part:getVehicle(), "AllowInflatTires")

	if checkResult then
		return MVCK.oISInflateTire(self, character, part, item, psiTarget)
	end

	checkResult = MVCK.checkPermission(character, part:getVehicle())

	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISInflateTire(self, character, part, item, psiTarget)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISDeflateTire to block unauthorized users
if not MVCK.oISDeflateTire then
    MVCK.oISDeflateTire = ISDeflateTire.new
end

function ISDeflateTire:new(character, part, psiTarget)	
	local checkResult = MVCK.getPublicPermission(part:getVehicle(), "AllowDeflatTires")

	if checkResult then
		return MVCK.oISDeflateTire(self, character, part, psiTarget)
	end

	checkResult = MVCK.checkPermission(character, part:getVehicle())

	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISDeflateTire(self, character, part, psiTarget)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISSmashVehicleWindow to block unauthorized users
if not MVCK.oISSmashVehicleWindow then
    MVCK.oISSmashVehicleWindow = ISSmashVehicleWindow.new
end

function ISSmashVehicleWindow:new(character, part, open)
	local checkResult = MVCK.checkPermission(character, part:getVehicle())
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISSmashVehicleWindow(self, character, part, open)
	else
		character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
		local temp = {
			ignoreAction = true
		}
		return temp
	end
end

-- Copy and override the vanilla ISOpenVehicleDoor to block unauthorized users
if not MVCK.oISOpenVehicleDoor then
	MVCK.oISOpenVehicleDoor = ISOpenVehicleDoor.new
end

function ISOpenVehicleDoor:new(character, vehicle, part)
	
	-- Exiting from seat
	if part:getId() == "number" then
		return MVCK.oISOpenVehicleDoor(self, character, vehicle, part)
	end

	-- Opening from outside
	local tempID = string.lower(part:getId())
	if not MVCK.matchTrunkPart(tempID) then
		return MVCK.oISOpenVehicleDoor(self, character, vehicle, part)
	end

	local checkResult = MVCK.getPublicPermission(vehicle, "AllowOpeningTrunk")

	if checkResult then
		return MVCK.oISOpenVehicleDoor(self, character, vehicle, part)
	end

	checkResult = MVCK.checkPermission(character, vehicle)
	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISOpenVehicleDoor(self, character, vehicle, part)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end

-- Copy and override the vanilla ISSmashWindow to block unauthorized users
-- ISSmashWindow is used for vehicles and others windows
if not MVCK.oISSmashWindow then
    MVCK.oISSmashWindow = ISSmashWindow.new
end

function ISSmashWindow:new(character, window, vehiclePart)
	-- validate if vehicle windows
	if not vehiclePart then
		return MVCK.oISSmashWindow(self, character, window, vehiclePart)
	end

	local checkResult = MVCK.getPublicPermission(vehiclePart:getVehicle(), "AllowSmashVehicleWindow")

	if checkResult then
		return MVCK.oISSmashWindow(self, character, window, vehiclePart)
	end

	checkResult = MVCK.checkPermission(character, vehiclePart:getVehicle())

	checkResult = MVCK.getSimpleBooleanPermission(checkResult)

	if checkResult then
		return MVCK.oISSmashWindow(self, character, window, vehiclePart)
	end

	character:setHaloNote(getText("IGUI_MVCK_Vehicle_No_Permission"), 250, 250, 250, 300)
	local temp = {
		ignoreAction = true
	}
	return temp
end