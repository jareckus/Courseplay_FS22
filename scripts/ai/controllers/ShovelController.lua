---@class ShovelController : ImplementController
ShovelController = CpObject(ImplementController)

ShovelController.POSITIONS = {
    DEACTIVATED = 0, 
    LOADING = 1,
    TRANSPORT = 2,
    PRE_UNLOADING = 3,
    UNLOADING = 4,
}

function ShovelController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.shovelSpec = self.implement.spec_shovel
    self.shovelNode = self.shovelSpec.shovelNodes[1]
end

function ShovelController:update()
	
end

function ShovelController:getShovelNode()
	return self.shovelNode.node
end

function ShovelController:isFull()
    return self:getFillLevelPercentage() >= 0.98
end

function ShovelController:isEmpty()
    return self:getFillLevelPercentage() <= 0.01
end

function ShovelController:getFillLevelPercentage()
    return self.implement:getFillUnitFillLevelPercentage(self.shovelNode.fillUnitIndex) * 100
end

function ShovelController:isTiltedForUnloading()
    return self.implement:getShovelTipFactor() >= 0
end

function ShovelController:isUnloading()
    return self:isTiltedForUnloading() and self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

--- Gets current loading fill type.
function ShovelController:getShovelFillType()
    return self.shovelSpec.loadingFillType
end

function ShovelController:getDischargeFillType()
    return self.implement:getDischargeFillType(self:getDischargeNode())
end

function ShovelController:getDischargeNode()
    return self.implement:getCurrentDischargeNode()
end

function ShovelController:isReadyToLoad()
    return self:getShovelFillType() == FillType.UNKNOWN and self:getFillLevelPercentage() < 0.5 
end

--- Is the shovel node over the trailer?
---@param trailer table
---@param margin number|nil
---@return boolean
function ShovelController:isShovelOverTrailer(trailer, margin)
    local node = self:getShovelNode()
    local x, y, z = localToLocal(trailer.rootNode, node, 0, 0, 0)
    margin = margin or 0
    return z < margin
end

function ShovelController:moveShovelToLoadingPosition()
    return self:moveShovelToPosition(self.POSITIONS.LOADING)
end

function ShovelController:moveShovelToTransportPosition()
    return self:moveShovelToPosition(self.POSITIONS.TRANSPORT)
end

function ShovelController:moveShovelToPreUnloadPosition()
    return self:moveShovelToPosition(self.POSITIONS.PRE_UNLOADING)
end

function ShovelController:moveShovelToUnloadPosition()
    return self:moveShovelToPosition(self.POSITIONS.UNLOADING)
end

function ShovelController:onFinished()
    self:deactivateShovelPositions()
end

---@param pos number shovel position 1-4
---@return boolean reached? 
function ShovelController:moveShovelToPosition(pos)
    return true
end

function ShovelController:deactivateShovelPositions()
    
end