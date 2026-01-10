require "TimedActions/ISBaseTimedAction"

-- By adding this action, we can utilize the base game log system
ISMVCKVehicleUnclaimAction = ISBaseTimedAction:derive("ISMVCKVehicleUnclaimAction")

function ISMVCKVehicleUnclaimAction:isValid()
    return self.vehicle and not self.vehicle:isRemovedFromWorld()
end

function ISMVCKVehicleUnclaimAction:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function ISMVCKVehicleUnclaimAction:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    if not self.character:getEmitter():isPlaying(self.sound) then
        self.sound = self.character:playSound("MVCKClaimSound")
    end
end

function ISMVCKVehicleUnclaimAction:start()
    self:setActionAnim("VehicleWorkOnMid")
    self.sound = self.character:playSound("MVCKClaimSound")
end

function ISMVCKVehicleUnclaimAction:stop()
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function ISMVCKVehicleUnclaimAction:perform()
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end

    if SandboxVars.MVCK.ReturnTicket and SandboxVars.MVCK.RequireTicket then
        self.character:getInventory():AddItem("Base.MysteriousVehicleClaimKey")
    end

	sendClientCommand(self.character, "MVCK", "unclaimVehicle", { MVCK.getVehicleID(self.vehicle) })

    if UdderlyVehicleRespawn and SandboxVars.MVCK.UdderlyRespawn then
        UdderlyVehicleRespawn.SpawnRandomVehicleSomewhere()
    end

    ISBaseTimedAction.perform(self)
end

function ISMVCKVehicleUnclaimAction:new(character, vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.stopOnWalk = true
    o.stopOnRun = true
    o.character = character
    o.vehicle = vehicle
    o.maxTime = 250
    
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end