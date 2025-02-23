
--[[
    These markers can be added to a vehicle:
        - front marker node:
            - moved all the way to the front of the vehicle or the front most attached implement.
        - back marker node:
            - moved all the way to the back of the vehicle or the rear most attached implement.

        - front marker offset:
            - distance between the vehicle root node and the front maker node (positive)
        - back marker offset:
            - distance between the vehicle root node and the back maker node (negative)

        - front marker node inverted:
            - front marker node, but rotated by 180 degrees
        - back marker node inverted:
            - back marker node, but rotated by 180 degrees
        
]]

Markers = {}

-- a global table with the vehicle as the key to persist the marker nodes we don't want to leak through jobs
-- and also don't want to deal with keeping track when to delete them
g_vehicleMarkers = {}

local function createMarkerIfDoesNotExist(vehicle, name, referenceNode)
    if not g_vehicleMarkers[vehicle] then
        g_vehicleMarkers[vehicle] = {}
    end
    if not g_vehicleMarkers[vehicle][name] then
        g_vehicleMarkers[vehicle][name] = CpUtil.createNode(name, 0, 0, 0, referenceNode)
    end
end

-- Put a node on the back of the vehicle for easy distance checks use this instead of the root/direction node
local function setBackMarkerNode(vehicle, measuredBackDistance)
    local backMarkerOffset = 0
    local referenceNode
    local reverserNode, debugText = AIUtil.getReverserNode(vehicle)
    if AIUtil.hasImplementsOnTheBack(vehicle) then
        local lastImplement
        lastImplement, backMarkerOffset = AIUtil.getLastAttachedImplement(vehicle)
        referenceNode = vehicle.rootNode
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Using the last implement\'s rear distance for the back marker node, %d m from root node', backMarkerOffset)
    elseif measuredBackDistance then
        referenceNode = vehicle.rootNode
        backMarkerOffset = -measuredBackDistance
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'back marker node on measured back distance %.1f', measuredBackDistance)
    elseif reverserNode then
        -- if there is a reverser node, use that, mainly because that most likely will turn with an implement
        -- or with the back component of an articulated vehicle. Just need to find out the distance correctly
        local dx, _, dz = localToLocal(reverserNode, vehicle.rootNode, 0, 0, 0)
        local dBetweenRootAndReverserNode = MathUtil.vector2Length(dx, dz)
        backMarkerOffset = dBetweenRootAndReverserNode - vehicle.size.length / 2 - vehicle.size.lengthOffset
        referenceNode = reverserNode
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Using the %s node for the back marker node %d m from root node (%d m between root and reverser)',
                debugText, backMarkerOffset, dBetweenRootAndReverserNode)
    else
        referenceNode = vehicle.rootNode
        backMarkerOffset = - vehicle.size.length / 2 + vehicle.size.lengthOffset
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Using the vehicle\'s root node for the back marker node, %d m from root node', backMarkerOffset)
    end

    createMarkerIfDoesNotExist(vehicle, 'backMarkerNode', referenceNode)
    -- relink to current reference node (in case of implement change for example
    unlink(g_vehicleMarkers[vehicle].backMarkerNode)
    link(referenceNode, g_vehicleMarkers[vehicle].backMarkerNode)
    setTranslation(g_vehicleMarkers[vehicle].backMarkerNode, 0, 0, backMarkerOffset)
    g_vehicleMarkers[vehicle].backMarkerOffset = backMarkerOffset
    --- Create inverted node for vehicles with a turned cabin.
    createMarkerIfDoesNotExist(vehicle, 'backMarkerNodeInverted', referenceNode)
    setTranslation(g_vehicleMarkers[vehicle].backMarkerNodeInverted, 0, 0, backMarkerOffset)
    setRotation(g_vehicleMarkers[vehicle].backMarkerNodeInverted, 0, math.pi, 0)
end

-- Put a node on the front of the vehicle for easy distance checks use this instead of the root/direction node
local function setFrontMarkerNode(vehicle)
    local firstImplement, frontMarkerOffset = AIUtil.getFirstAttachedImplement(vehicle)
    CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Using the %s\'s root node for the front marker node, %d m from root node',
            CpUtil.getName(firstImplement), frontMarkerOffset)

    createMarkerIfDoesNotExist(vehicle, 'frontMarkerNode', vehicle.rootNode)
    -- relink to current reference node (in case of implement change for example
    unlink(g_vehicleMarkers[vehicle].frontMarkerNode)
    link(vehicle.rootNode, g_vehicleMarkers[vehicle].frontMarkerNode)
    setTranslation(g_vehicleMarkers[vehicle].frontMarkerNode, 0, 0, frontMarkerOffset)
    g_vehicleMarkers[vehicle].frontMarkerOffset = frontMarkerOffset
    --- Create inverted node for vehicles with a turned cabin.
    createMarkerIfDoesNotExist(vehicle, 'frontMarkerNodeInverted', vehicle.rootNode)
    setTranslation(g_vehicleMarkers[vehicle].frontMarkerNodeInverted, 0, 0, frontMarkerOffset)
    setRotation(g_vehicleMarkers[vehicle].frontMarkerNodeInverted, 0, math.pi, 0)
end

--- Create two nodes, one on the front and one on the back of the vehicle (including implements). The front node
--- is just in front of any attached implements, the back node is just behind all attached implements.
--- These nodes can be used for distance measurements or to link proximity sensors to them
---@param vehicle table
---@param measuredBackDistance number|nil optional distance between the root node of the vehicle and the back of the vehicle if known
function Markers.setMarkerNodes(vehicle, measuredBackDistance)
    setBackMarkerNode(vehicle, measuredBackDistance)
    setFrontMarkerNode(vehicle)
end

--- Get the front marker node and offset
---@param vehicle table
---@return number, number the front marker node, distance of front marker node from the vehicle's root node
function Markers.getFrontMarkerNode(vehicle)
    if not g_vehicleMarkers[vehicle] or not g_vehicleMarkers[vehicle].frontMarkerNode then
        setFrontMarkerNode(vehicle)
    end
    return g_vehicleMarkers[vehicle].frontMarkerNode, g_vehicleMarkers[vehicle].frontMarkerOffset
end

--- Get the back marker node and offset
---@param vehicle table
---@return number, number the back marker node, distance of back marker node from the vehicle's root node, most likely
--- negative, as it will be behind the root node...
function Markers.getBackMarkerNode(vehicle)
    if not g_vehicleMarkers[vehicle] or not g_vehicleMarkers[vehicle].backMarkerNode then
        setBackMarkerNode(vehicle)
    end
    return g_vehicleMarkers[vehicle].backMarkerNode, g_vehicleMarkers[vehicle].backMarkerOffset
end

---@param vehicle table
---@return number front marker
---@return number back marker
function Markers.getMarkerNodes(vehicle)
    local frontMarker = Markers.getFrontMarkerNode(vehicle)
    local backMarker = Markers.getBackMarkerNode(vehicle)
    return frontMarker, backMarker
end

--- Gets the front/back marker relative to the ai direction.
--- For vehicles with a turned cabin the markers are switched. 
--- The front and back marker offset also get inverted and switched.
---@param vehicle table
---@return number front marker
---@return number back marker
---@return number front offset
---@return number back offset
function Markers.getMarkerNodesRelativeToDirectionNode(vehicle)
    local frontMarker, backMarker = Markers.getMarkerNodes(vehicle)
    local _, _, z = localToLocal(backMarker, vehicle:getAIDirectionNode(), 0, 0, 0)
    if z > 0 then 
        --- The vehicle is turned around, so the use the inverted nodes and switch the offsets.
        return g_vehicleMarkers[vehicle].backMarkerNodeInverted, g_vehicleMarkers[vehicle].frontMarkerNodeInverted,
            -g_vehicleMarkers[vehicle].backMarkerOffset, -g_vehicleMarkers[vehicle].frontMarkerOffset
    end
    return frontMarker, backMarker, g_vehicleMarkers[vehicle].frontMarkerOffset, g_vehicleMarkers[vehicle].backMarkerOffset
end

function Markers.delete()
    for i, vehicle in pairs(g_vehicleMarkers) do 
        for j, marker in pairs(vehicle) do 
            CpUtil.destroyNode(marker)
        end
    end
end