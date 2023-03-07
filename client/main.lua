local inNpcMission = false
local createdBlips = {}

---Create Blip
---@param coord vector3
---@param id string
local function createBlip(coord, id)
    if not id then
        return print('No id')
    end
    local blip = AddBlipForCoord(coord.x, coord.y, coord.z)
	SetBlipSprite(blip, Config.Blips[id].sprite or 0)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.5)
	SetBlipColour(blip, Config.Blips[id].colour or 0)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(Config.Blips[id].text or 'no label')
	EndTextCommandSetBlipName(blip)

	createdBlips[id] = blip
end

---I dont know what is this does
---@param movie number
---@param settings table
local function addDestination(movie, settings)
	BeginScaleformMovieMethod(movie, "ADD_TAXI_DESTINATION")
	ScaleformMovieMethodAddParamInt(0) -- Index
	ScaleformMovieMethodAddParamInt(settings.sprite) -- sprite
	ScaleformMovieMethodAddParamInt(settings.colour.r) -- r
	ScaleformMovieMethodAddParamInt(settings.colour.g) -- g
	ScaleformMovieMethodAddParamInt(settings.colour.b) -- b
	BeginTextCommandScaleformString("STRING")
	AddTextComponentSubstringPlayerName(settings.label) -- label
	EndTextCommandScaleformString()
	BeginTextCommandScaleformString("STRING")
	AddTextComponentSubstringPlayerName(settings.zone) -- 1st line
	EndTextCommandScaleformString()
	BeginTextCommandScaleformString("STRING")
	AddTextComponentSubstringPlayerName(settings.street) -- 2nd line
	EndTextCommandScaleformString()
	EndScaleformMovieMethod()
	BeginScaleformMovieMethod(movie, "SHOW_TAXI_DESTINATION") -- show index
	EndScaleformMovieMethod()
	BeginScaleformMovieMethod(movie, "HIGHLIGHT_DESTINATION")
	ScaleformMovieMethodAddParamInt(0) -- highlight added index
	EndScaleformMovieMethod()
end

---CreateMaker
---@param coord vector3
local function createMarker(coord)
    local setting = Config.Marker
    DrawMarker(setting.Type, coord.x, coord.y, coord.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, setting.Size.x, setting.Size.y, setting.Size.z, setting.Color.r, setting.Color.g, setting.Color.b, 200, false, false, 2, setting.Rotate, nil, nil, false)
end

---Handle keypress
---@param cb any
local function checkKeyPress(cb)
    if ESX.PlayerData.job.name == 'taxi' then
        if IsControlJustPressed(0, 38) then
            cb()
        end
    end
end

---Check if any close in DrawDistance
---@return table|boolean
local function checkDistance()
    local playerCoord = GetEntityCoords(ESX.PlayerData.ped)

    local closestZones = {}
    for id, coords in pairs(Config.Positions) do
        local distance = #(vec(coords.x, coords.y, coords.z) - playerCoord)
        if distance <= Config.DrawDistance then
            closestZones[#closestZones+1] = {id, coords, distance}
        end
    end

    if next(closestZones) then
        return closestZones
    end

    return false
end

---Get player server id from ped
---@param playerPed number
---@return boolean|number
local function getPlayerFromPed(playerPed)
    local player = NetworkGetPlayerIndexFromPed(playerPed)
    return player > 0 and GetPlayerServerId(player) or false
end

---Find a new route
---@return vector3
local function findRoute()
    local nearestRoute = vector3(0, 0, 0)
	local playerCoord = GetEntityCoords(ESX.PlayerData.ped)
	while #(nearestRoute - playerCoord) < Config.MinimumDistance do
		nearestRoute = Config.DropOffLocations[math.random(#Config.DropOffLocations)]
	end

	if nearestRoute == vector3(0, 0, 0) then
		nearestRoute = Config.DropOffLocations[math.random(#Config.DropOffLocations)]
	end
	return nearestRoute
end

---Check if player is in the taxi
---@param vehicle number
---@return boolean
---@return integer
local function isPlayerInTaxi(vehicle)
	local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
	for i = maxSeats - 1, 0, -1 do
		if not IsVehicleSeatFree(vehicle, i) then
			local pedInSeat = GetPedInVehicleSeat(vehicle, i)
			if IsPedAPlayer(pedInSeat) then
				return true, i
			end
		end
	end
	return false, 0
end


---Get random npc
---@param coords vector3
---@return nil|number
local function getRandomWalkingNPC(coords)
	if not inNpcMission then
		return nil
	end
	local search = {}
	local peds = GetGamePool("CPed")

	for i = 1, #peds, 1 do
		if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
			search[#search +1] = peds[i]
		end
	end

	if #search == 0 then
		ESX.ShowNotification(Translate("customer_unavailable"), "error")
		inNpcMission = false
		return nil
	end

	local npc = search[math.random(#search)]
	local distance = #(GetEntityCoords(npc) - coords)
	local tries = 0
	while distance < Config.MinimumNpcDistance do 
		Wait(0)
		npc = search[math.random(#search)]
		distance = #(GetEntityCoords(npc) - coords)
		tries += 1
		if tries > 25 then
			ESX.ShowNotification(Translate("customer_unavailable"), "error")
			inNpcMission = false
			return nil
		end
	end
	return npc
end