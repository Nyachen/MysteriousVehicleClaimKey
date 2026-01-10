--[[
MVCK Generic functions
All are local functions thus to use this, you must require this lua
TODO: Not utilized, WIP
--]]

-- Ingame debugger is unreliable but this does work
local function MVCKgetMulePart(vehicleObj)
    if vehicleObj then
        -- Split by ";"
        for s in string.gmatch(SandboxVars.MVCK.MuleParts, "([^;]+)") do
            -- Trim leading and trailing white spaces
            local tempPart = vehicleObj:getPartById(s:match("^%s*(.-)%s*$"))
            if tempPart then
                return tempPart
            end
        end
        return nil
    else
        return nil
    end
end

local function MVCKgetVehicleID(muleObj)
    if muleObj then
        return muleObj:getModData().SQLID
    else
        return nil
    end
end

-- Returns boolean for set status
-- You have to do transmitPartModData if needed
local function MVCKsetVehicleID(muleObj, arg)
    if muleObj and isServer() and type(arg) == "number" then
        muleObj:getModData().SQLID = arg
        return true
    else
        return false
    end
end

local function MVCKhasVehicleID(vehicleID)
    if type(vehicleID) == "number" then
        if MVCK.dbByVehicleSQLID[vehicleID] then
            return true
        else
            return false
        end
    else
        return false
    end
end

local function MVCKgetVehicleOwnerID(vehicleID)
    if vehicleID then
        if type(vehicleID) == "number" then
            return MVCK.dbByVehicleSQLID[vehicleID].OwnerPlayerID
        else
            return nil
        end
    else
        return nil
    end
end

local function MVCKgetVehicleLocation(vehicleID)
    if vehicleID then
        if type(vehicleID) == "number" then
            return {X = MVCK.dbByVehicleSQLID[vehicleID].LastLocationX, Y = MVCK.dbByVehicleSQLID[vehicleID].LastLocationY}
        else
            return nil
        end
    else
        return nil
    end
end

-- Returns boolean for set status
local function MVCKsetVehicleLocation(vehicleID, x, y)
    if vehicleID then
        if type(vehicleID) == "number" and type(x) == "number" and type(y) == "number" then
            MVCK.dbByVehicleSQLID[vehicleID].LastLocationX = x
            MVCK.dbByVehicleSQLID[vehicleID].LastLocationY = y
            return true
        else
            return false
        end
    else
        return false
    end
end

local function MVCKgetUserLogonTime(username)
    if username then
        if MVCK.dbByPlayerID[username] then
            return MVCK.dbByPlayerID[username].LastKnownLogonTime
        else
            return nil
        end
    else
        return nil
    end
end

local function MVCKsetUserLogonTime(username, arg)
    if username then
        if MVCK.dbByPlayerID[username] then
            MVCK.dbByPlayerID[username].LastKnownLogonTime = arg
        else
            return false
        end
    else
        return false
    end
end