local taxiJob = {
	jobVehicle = nil,
	createdBlips = {},
	inNpcMission = false,
	playerPrice = 0,
	object = nil,
	inTaxiAsPassenger = false,
	movie = nil,
	currentNPC = nil,
	currentCustomerBlip = nil,
	meterRunning = true,
	destinationBlip = nil,
	renderTarget = nil,
	syncPrice = false
}

---Create Blip
---@param coord vector3
---@param id string
function taxiJob:createBlip(coord, id)
    if not id then
        return print('[WARNING] Failed to create a blip. Reason: No blip id passed')
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

	self.createdBlips[id] = blip
end

---Create marker
---@param coord vector3
function taxiJob:createMarker(coord)
    local setting = Config.Marker
    DrawMarker(setting.Type, coord.x, coord.y, coord.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, setting.Size.x, setting.Size.y, setting.Size.z, setting.Color.r, setting.Color.g, setting.Color.b, 200, false, false, 2, setting.Rotate, nil, nil, false)
end

---Handle keypress
---@param cb any
function taxiJob:checkKeyPress(cb)
    if IsControlJustPressed(0, 38) then
        cb()
    end
end

function taxiJob:loadMarkers()
	Wait(1000)
	local drawDist = Config.DrawDistance
	local positions = Config.Positions
	local forceWorkOutfit = Config.ForceWorkoutfit
	local drawingTextUI = false
	while true do
		local sleep = 1500
		if LocalPlayer.state.job.name ~= 'taxi' then break end
		local ped = ESX.PlayerData.ped
		local playerCoords = GetEntityCoords(ped)

		-- Cloakroom
		local cloakroomDistance = #(playerCoords - positions.Cloakroom)
		if cloakroomDistance <= drawDist then
			sleep = 0
			self:createMarker(positions.Cloakroom)
			if cloakroomDistance <= 2.0 then
				if not drawingTextUI then
					drawingTextUI = true
					ESX.TextUI(TranslateCap("Start_textui"), "info")
				end
				self:checkKeyPress(function()
					if not ESX.Game.IsSpawnPointClear(positions.VehicleSpawn.xyz, 5.0) then
						return ESX.ShowNotification(TranslateCap("blocked_spawn"), "error")
					end
					if forceWorkOutfit then
						ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
							if skin.sex == 0 then
								TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
							else
								TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
							end
						end)
					end
					TriggerServerEvent("taxi:startjob")
					ESX.HideUI()
					drawingTextUI = false
				end)
			else
				if drawingTextUI then
					ESX.HideUI()
					drawingTextUI = false
				end
			end
		end

		if self.jobVehicle and DoesEntityExist(self.jobVehicle) then
			local del_dist = #(playerCoords - positions.VehicleSpawn.xyz)
			if del_dist <= drawDist then
				sleep = 0
				self:createMarker(positions.VehicleSpawn.xyz)
				if del_dist <= 2.0 then
					if not drawingTextUI then
						drawingTextUI = true
						ESX.TextUI(TranslateCap("return_textui"), "info")
					end
					self:checkKeyPress(function()
						if forceWorkOutfit then
							ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
								TriggerEvent('skinchanger:loadSkin', skin)
							end)
						end
						NetworkRequestControlOfEntity(self.jobVehicle)
						while not NetworkHasControlOfEntity(self.jobVehicle) do
							Wait(0)
						end
						DeleteEntity(self.jobVehicle)
						TriggerServerEvent("taxi:endjob")
						ESX.HideUI()
						drawingTextUI = false
					end)
				else
					if drawingTextUI then
						ESX.HideUI()
						drawingTextUI = false
					end
				end
			end
		end
		Wait(sleep)
	end
end

---Get player server id from ped
---@param playerPed number
---@return boolean|number
function taxiJob:GetPlayerFromPed(playerPed)
	local player = NetworkGetPlayerIndexFromPed(playerPed)
	return player > 0 and GetPlayerServerId(player) or false
end

---Find a new route
---@return vector3
function taxiJob:FindRoute()
	local nearestRoute = vector3(0, 0, 0)
	local Coords = GetEntityCoords(ESX.PlayerData.ped)
	while #(nearestRoute - Coords) < Config.MinimumDistance do
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
function taxiJob:isPlayerInTaxi(vehicle)
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
function taxiJob:getRandomWalkingNPC(coords)
	if not self.inNpcMission then
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
		ESX.ShowNotification(TranslateCap("customer_unavailable"), "error")
		self.inNpcMission = false
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
			ESX.ShowNotification(TranslateCap("customer_unavailable"), "error")
			self.inNpcMission = false
			return nil
		end
	end
	return npc
end

function taxiJob:OpenMenu()
	if self.inTaxiAsPassenger then return end
	if LocalPlayer.state.job.name ~= "taxi" then return end
	local playerInTaxi, seatIndex = self:isPlayerInTaxi(self.jobVehicle)
	local elements = {
		{
			title = TranslateCap("menu_title"),
			icon = "fas fa-taxi",
			unselectable = true
		},
		{
			title = TranslateCap("menu_start"),
			icon = "fas fa-phone",
			value = "toggle_npc",
			disabled = self.inNpcMission,
			description = TranslateCap(self.inNpcMission and ("Unavailable") or "menu_start_desc")
		},
		{
			title = TranslateCap("menu_reset"),
			icon = "fas fa-tachometer-alt",
			value = "reset_value",
			disabled = self.inNpcMission,
			description = TranslateCap(self.inNpcMission and ("Unavailable") or "menu_reset_desc")
		},
		{
			title = TranslateCap("menu_toggle"),
			icon = "fas fa-power-off",
			value = "toggle_meter",
			description = ("Currently: %s"):format(TranslateCap(self.meterRunning and "running" or "paused"))
		},
		{
			title = TranslateCap("menu_bill"),
			icon = "fas fa-money-bill-alt",
			value = "bill_player",
			description = TranslateCap(playerInTaxi and "menu_bill_desc" or "Unavailable"),
			disabled = not playerInTaxi
		},
		{
			title = TranslateCap("menu_close"),
			icon = "fas fa-times",
			value = "close",
			description = TranslateCap("menu_close_desc")
		}
	}
	ESX.OpenContext("right", elements, function(menu, element)
		if element.value == "toggle_npc" then
			self.inNpcMission = not self.inNpcMission
			if self.inNpcMission then
				self.currentNPC = self:getRandomWalkingNPC(GetEntityCoords(ESX.PlayerData.ped))
			end
		elseif element.value == "reset_value" then
			self.playerPrice = 0
			BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
			ScaleformMovieMethodAddParamInt(self.playerPrice)
			EndScaleformMovieMethod()

			if not playerInTaxi then return end
			local pSeatIndex = GetPlayerFromPed(GetPedInVehicleSeat(self.jobVehicle, seatIndex))
			if pSeatIndex then
				TriggerServerEvent("taxi:self.syncPrice", pSeatIndex, self.playerPrice)
			end
		elseif element.value == "toggle_meter" then
			self.meterRunning = not self.meterRunning
		elseif element.value == "bill_player" then
			if not playerInTaxi then return end
			local pSeatIndex = GetPlayerFromPed(GetPedInVehicleSeat(self.jobVehicle, seatIndex))
			if pSeatIndex then
				TriggerServerEvent('esx_billing:sendBill', pSeatIndex, nil, TranslateCap("bill_reason"), self.playerPrice)
				ESX.ShowNotification(TranslateCap("bill_sent", self.playerPrice), "success")
			end
			ESX.CloseContext()
		else
			return ESX.CloseContext()
		end
		OpenMenu()
	end)
end

ESX.RegisterInput("taxi:menu", TranslateCap("keybind_desc"), "keyboard", "f6", OpenMenu)

---Update taxi meter destination
---@param movie number
---@param settings table
function taxiJob:addDestination(movie, settings)
	BeginScaleformMovieMethod(movie, "ADD_TAXI_DESTINATION")
	ScaleformMovieMethodAddParamInt(0)
	ScaleformMovieMethodAddParamInt(settings.sprite)
	ScaleformMovieMethodAddParamInt(settings.colour.r)
	ScaleformMovieMethodAddParamInt(settings.colour.g)
	ScaleformMovieMethodAddParamInt(settings.colour.b)
	BeginTextCommandScaleformString("STRING")
	AddTextComponentSubstringPlayerName(settings.label)
	EndTextCommandScaleformString()
	BeginTextCommandScaleformString("STRING")
	AddTextComponentSubstringPlayerName(settings.zone)
	EndTextCommandScaleformString()
	BeginTextCommandScaleformString("STRING")
	AddTextComponentSubstringPlayerName(settings.street)
	EndTextCommandScaleformString()
	EndScaleformMovieMethod()
	BeginScaleformMovieMethod(movie, "SHOW_TAXI_DESTINATION")
	EndScaleformMovieMethod()
	BeginScaleformMovieMethod(movie, "HIGHLIGHT_DESTINATION")
	ScaleformMovieMethodAddParamInt(0)
	EndScaleformMovieMethod()
end

function taxiJob:createTaxiMeterScaleform()
	self.movie = RequestScaleformMovie("TAXI_DISPLAY")
	while not HasScaleformMovieLoaded(self.movie) do
		Wait(0)
	end
	RequestModel(joaat("prop_taxi_meter_2"))
	while not HasModelLoaded(joaat("prop_taxi_meter_2")) do
		Wait(0)
	end
	self.object = CreateObjectNoOffset(joaat("prop_taxi_meter_2"), GetEntityCoords(self.jobVehicle), true, true, false)
	AttachEntityToEntity(self.object, self.jobVehicle, GetEntityBoneIndexByName(self.jobVehicle, "Chassis"), vector3(-0.05, 0.78, 0.39), vector3(-6.0, 0.0, -10.0), false, false, false, false, 2, true, 0)
	if not IsNamedRendertargetRegistered("taxi") then
		RegisterNamedRendertarget("taxi", false)
		if not IsNamedRendertargetLinked(GetEntityModel(self.object)) then
			LinkNamedRendertarget(GetEntityModel(self.object))
		end
		self.renderTarget = GetNamedRendertargetRenderId("taxi")
	end
	BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
	ScaleformMovieMethodAddParamInt(0)
	EndScaleformMovieMethod()
end

function taxiJob:deleteTaxiMeter()
	DeleteObject(self.object)
	SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
	SetScaleformMovieAsNoLongerNeeded(self.movie)
	ReleaseNamedRendertarget("taxi")
end

function taxiJob:taxiMeterScaleform()
	self:createTaxiMeterScaleform()
	local foundRoute, customerInVehicle, route, oldCoords, price = false, false, nil, vector3(0, 0, 0), 0
	self.destinationBlip = nil
	while true do
		local sleep = 500
		local inTaxi = IsPedInVehicle(ESX.PlayerData.ped, self.jobVehicle, false)
		if DoesEntityExist(self.jobVehicle) then
			local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
			if inTaxi then
				sleep = 0

				SetTextRenderId(self.renderTarget)
				SetScriptGfxDrawOrder(4)
				SetTaxiLights(self.jobVehicle, false)
				DrawScaleformMovie(self.movie, 0.201, 0.351, 0.4, 0.6, 0, 0, 0, 255, 0)
				SetTextRenderId(GetDefaultScriptRendertargetRenderId()) -- Reset Render ID

				-- NPC Missions
				if self.currentNPC and DoesEntityExist(self.currentNPC) then
					local customerCoords = GetEntityCoords(self.currentNPC)
					if not DoesBlipExist(self.currentCustomerBlip) and not customerInVehicle then
						self.currentCustomerBlip = AddBlipForEntity(self.currentNPC)
						SetBlipAsFriendly(self.currentCustomerBlip, true)
						SetBlipSprite(self.currentCustomerBlip, 480)
						SetBlipColour(self.currentCustomerBlip, 2)
						SetBlipCategory(self.currentCustomerBlip, 3)
						SetBlipRoute(self.currentCustomerBlip, true)
						SetEntityAsMissionEntity(self.currentNPC, true, true)
						SetBlockingOfNonTemporaryEvents(self.currentNPC, true)
						ClearPedTasksImmediately(self.currentNPC)
						local zone = GetLabelText(GetNameOfZone(customerCoords.x, customerCoords.y, customerCoords.z))
						local street = (GetStreetNameAtCoord(customerCoords.x, customerCoords.y, customerCoords.z))
						local streetname = GetStreetNameFromHashKey(street)
						ESX.ShowNotification(TranslateCap("customer_new"), "info")
						self:addDestination(self.movie, {
							sprite = 480,
							colour = {r = 50, g = 250, b = 50},
							label = "Pick up",
							zone = zone,
							street = streetname
						})
					end
					if #(playerCoords - customerCoords) <= 10.0 then
						if IsVehicleSeatFree(self.jobVehicle, 1) and not customerInVehicle then
							BringVehicleToHalt(self.jobVehicle, 5.0, 4, false)
							TaskEnterVehicle(self.currentNPC, self.jobVehicle, -1, 2, 1.0, 1, 0)
							customerInVehicle = true
						end
						if IsPedInVehicle(self.currentNPC, self.jobVehicle, true) then
							if not foundRoute then
								RemoveBlip(self.currentCustomerBlip)
								self.currentCustomerBlip = nil
								foundRoute = true
								route = FindRoute()

								self.destinationBlip = taxiJob:createBlip(route, 'waypoint')
								SetBlipRoute(self.destinationBlip, true)

								price = math.floor((#(playerCoords - route) * Config.PricePerUnit) / 20)
								BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
								ScaleformMovieMethodAddParamInt(price)
								EndScaleformMovieMethod()
								SetEntityAsMissionEntity(self.currentNPC)
								SetBlockingOfNonTemporaryEvents(self.currentNPC, true)

								local blipCoords = GetBlipCoords(self.destinationBlip)
								local zone = GetLabelText(GetNameOfZone(blipCoords.x, blipCoords.y, blipCoords.z))
								local street = (GetStreetNameAtCoord(blipCoords.x, blipCoords.y, blipCoords.z))
								local streetname = GetStreetNameFromHashKey(street)
								self:addDestination(self.movie, {
									sprite = 8,
									colour = {r = 250, g = 250, b = 10},
									label = "Drop Off",
									zone = zone,
									street = streetname
								})
							end
							if IsEntityDead(self.currentNPC) then
								ESX.ShowNotification(TranslateCap("customer_lost"), "error")
								RemoveBlip(self.destinationBlip)
								SetEntityAsNoLongerNeeded(self.currentNPC)
								self.currentNPC = nil
								self.destinationBlip = nil
								foundRoute, customerInVehicle, route = false, false, nil
								BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
								ScaleformMovieMethodAddParamInt(0) -- reset prce
								EndScaleformMovieMethod()
								self.inNpcMission = false
							end
							if foundRoute then -- reached end of route
								if #(playerCoords - route) <= 6.0 then
									BringVehicleToHalt(self.jobVehicle, 3.5, -1, false)
									TaskLeaveVehicle(self.currentNPC, self.jobVehicle, 1)
									RemoveBlip(self.destinationBlip)
									SetTimeout(1200, function()
										TaskWanderStandard(self.currentNPC, 10.0, 10)
										SetPedKeepTask(self.currentNPC, true)
										SetEntityAsNoLongerNeeded(self.currentNPC)
										StopBringVehicleToHalt(self.jobVehicle)
										TriggerServerEvent("taxi:finish", price, route)
										self.currentNPC = nil
										self.destinationBlip = nil
										self.currentCustomerBlip = nil
										foundRoute, customerInVehicle, route = false, false, nil
										customerCoords = nil
										self.inNpcMission = false
										price = 0
										BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
										ScaleformMovieMethodAddParamInt(0) -- reset price
										EndScaleformMovieMethod()
									end)
								end
							end
						end
					end
				end

				-- player Missions
				local playerInTaxi, seatIndex = IsPlayerINTaxi(self.jobVehicle)

				if playerInTaxi then
					self.inNpcMission = false
					SetUseWaypointAsDestination(true)
					local waypoint = GetWaypointBlipEnumId()
					self.destinationBlip = GetFirstBlipInfoId(waypoint)
					local blipCoords = GetBlipCoords(self.destinationBlip)
					if (blipCoords ~= vector3(0,0,0)) and not route or route ~= blipCoords then
						route = blipCoords
						local zone = GetLabelText(GetNameOfZone(blipCoords.x, blipCoords.y, blipCoords.z))
						local street = (GetStreetNameAtCoord(blipCoords.x, blipCoords.y, blipCoords.z))
						local streetname = GetStreetNameFromHashKey(street)
						self:addDestination(self.movie, {
							sprite = 8,
							colour = {r = 250, g = 250, b = 10},
							label = "Drop Off",
							zone = zone,
							street = streetname
						})
						local pSeatIndex = GetPlayerFromPed(GetPedInVehicleSeat(self.jobVehicle, seatIndex))
						if pSeatIndex then
							TriggerServerEvent("taxi:sync", pSeatIndex)
						end
					end
					if route then
						if #(oldCoords - playerCoords) > Config.DistancePerDollar then
							oldCoords = playerCoords
							if self.meterRunning then
								self.playerPrice += 1
								BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
								ScaleformMovieMethodAddParamInt(self.playerPrice)
								EndScaleformMovieMethod()
								local pSeatIndex = GetPlayerFromPed(GetPedInVehicleSeat(self.jobVehicle, seatIndex))
								if pSeatIndex then
									TriggerServerEvent("taxi:self.syncPrice", pSeatIndex, self.playerPrice)
								end
							end
						end
					end
				end
				if LocalPlayer.state.job.name ~= "taxi" then
					self:deleteTaxiMeter()
					SetVehicleDoorsLocked(self.jobVehicle, 2)
					SetVehicleUndriveable(self.jobVehicle, true)
					SetVehicleAsNoLongerNeeded(self.jobVehicle)
					if self.currentNPC then
						self.inNpcMission = false
						SetPedAsNoLongerNeeded(self.currentNPC)
						self.currentNPC = nil
					end
					if Config.ForceWorkoutfit then
						ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
							TriggerEvent('skinchanger:loadSkin', skin)
						end)
					end
					break
				end
			end
		else
			self:deleteTaxiMeter()
			if self.currentNPC then
				self.inNpcMission = false
				SetPedAsNoLongerNeeded(self.currentNPC)
				self.currentNPC = nil
			end
			break
		end
		Wait(sleep)
	end
end

function taxiJob:syncTaxiMeterPrice()
	if not self.syncPrice then return end
	BeginScaleformMovieMethod(self.movie, "SET_TAXI_PRICE")
	ScaleformMovieMethodAddParamInt(self.syncPrice)
	EndScaleformMovieMethod()
	self.syncPrice = false
end

function taxiJob:taxiMeterSync()
	local route = nil
	local renderTarget = nil
	while true do
		local sleep = 0
		if not self.inTaxiAsPassenger then break end
		local inVeh = IsPedInAnyVehicle(ESX.PlayerData.ped, false)
		if not inVeh then
			SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
			SetScaleformMovieAsNoLongerNeeded(self.movie)
			ReleaseNamedRendertarget("taxi")
			self.inTaxiAsPassenger = false
			route, renderTarget, self.movie = nil, nil, nil
		end
		if not renderTarget then
			self.movie = RequestScaleformMovie("TAXI_DISPLAY")
			while not HasScaleformMovieLoaded(self.movie) do
				Wait(0)
			end
			if not IsNamedRendertargetRegistered("taxi") then
				RegisterNamedRendertarget("taxi", false)
				if not IsNamedRendertargetLinked(joaat("prop_taxi_meter_2")) then
					LinkNamedRendertarget(joaat("prop_taxi_meter_2"))
				end
				renderTarget = GetNamedRendertargetRenderId("taxi")
				SetTextRenderId(renderTarget)
			end
		end
		SetScriptGfxDrawOrder(4)
		DrawScaleformMovie(self.movie, 0.201, 0.351, 0.4, 0.6, 0, 0, 0, 255, 0)
		SetTextRenderId(GetDefaultScriptRendertargetRenderId())
		local waypoint = GetWaypointBlipEnumId()
		self.destinationBlip = GetFirstBlipInfoId(waypoint)
		local blipCoords = GetBlipCoords(self.destinationBlip)
		if (blipCoords ~= vector3(0,0,0)) and not route or route ~= blipCoords then
			route = blipCoords
			local zone = GetLabelText(GetNameOfZone(blipCoords.x, blipCoords.y, blipCoords.z))
			local street = (GetStreetNameAtCoord(blipCoords.x, blipCoords.y, blipCoords.z))
			local streetname = GetStreetNameFromHashKey(street)
			self:addDestination(self.movie, {
				sprite = 8,
				colour = {r = 250, g = 250, b = 10},
				label = "Drop Off",
				zone = zone,
				street = streetname
			})
		end
		self:syncTaxiMeterPrice()
		Wait(sleep)
	end
end

function taxiJob:initialize()
	self:createBlip(Config.Position.Cloakroom, 'depo')

	if LocalPlayer.state.job.name == 'taxi' then
		self:loadMarkers()
	end

	RegisterNetEvent("taxi:start", function(netId)
		self.jobVehicle = NetworkGetEntityFromNetworkId(netId)
		CreateThread(function()
			self:taxiMeterScaleform()
		end)
	end)
	
	AddEventHandler("onResourceStop", function()
		self:deleteTaxiMeter()
	
		for _, v in pairs(self.createdBlips) do
			RemoveBlip(v)
		end
	
		if self.currentNPC then
			self.inNpcMission = false
			SetPedAsNoLongerNeeded(self.currentNPC)
			self.currentNPC = nil
		end
	end)

	RegisterNetEvent("taxi:c:sync", function()
		self.inTaxiAsPassenger = true
		self:taxiMeterSync()
	end)
	
	RegisterNetEvent("taxi:c:self.syncPrice", function(price)
		self.self.syncPrice = price
	end)

	AddEventHandler('esx:setJob', function(job)
		if job ~= 'taxi' then
			self:loadMarkers()
		end
	end)
end

CreateThread(function()
	taxiJob:initialize()
end)
