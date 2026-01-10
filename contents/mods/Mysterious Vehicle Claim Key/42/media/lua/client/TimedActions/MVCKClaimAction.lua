require "TimedActions/ISBaseTimedAction"

-- By adding this action, we can utilize the base game log system
ISMVCKVehicleClaimAction = ISBaseTimedAction:derive("ISMVCKVehicleClaimAction")

function ISMVCKVehicleClaimAction:isValid()
    return self.vehicle and not self.vehicle:isRemovedFromWorld()
end

function ISMVCKVehicleClaimAction:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function ISMVCKVehicleClaimAction:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    if not self.character:getEmitter():isPlaying(self.sound) then
        self.sound = self.character:playSound("MVCKClaimSound")
    end
end

function ISMVCKVehicleClaimAction:start()
    self:setActionAnim("VehicleWorkOnMid")
    self.sound = self.character:playSound("MVCKClaimSound")
end

function ISMVCKVehicleClaimAction:stop()
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function ISMVCKVehicleClaimAction:perform()
    if self.sound ~= 0 then
        self.character:getEmitter():stopSound(self.sound)
    end
	
	sendClientCommand(self.character, "MVCK", "claimVehicle", { vehicle = self.vehicle:getId() })
    
    if SandboxVars.MVCK.RequireTicket then
	    local form = self.character:getInventory():getFirstTypeRecurse("MysteriousVehicleClaimKey")
	    form:getContainer():Remove(form)
    end

    if UdderlyVehicleRespawn and SandboxVars.MVCK.UdderlyRespawn then
        UdderlyVehicleRespawn.SpawnRandomVehicleSomewhere()
    end

    ISBaseTimedAction.perform(self)
end

function ISMVCKVehicleClaimAction:new(character, vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.stopOnWalk = true
    o.stopOnRun = true
    o.character = character
    o.vehicle = vehicle
    o.maxTime = 480
    
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end