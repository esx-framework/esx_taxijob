local Config, job_veh, blips, NPCMissions, playerprice, Object, InTaxiAsPassenger, movie, CurrentNPC, CurrentCustomerBlip, meterRunning, DestinationBlip, SyncPrice = GlobalState.taxijob.Config, nil, {}, false, 0, nil, false, nil, nil, nil, true, nil, false

local function createBlips()
	local blip = AddBlipForCoord(Config.Positions.Cloakroom)
	SetBlipSprite(blip, 198)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.5)
	SetBlipColour(blip, 5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(TranslateCapCap("blip"))
	EndTextCommandSetBlipName(blip)
	blips.station = blip
end

local function loadMarkers()
	Wait(1000)
	local setting = Config.Marker
	local DrawDist = Config.DrawDistance
	local positions = Config.Positions
	local forceWorkOutfit = Config.ForceWorkoutfit
	local DrawingTextUI = false
	local DrawingTextUI2 = false
	while true do
		local Sleep = 1500
		if LocalPlayer.state.job.name ~= 'taxi' then break end
		local ped = ESX.PlayerData.ped
		local PlayerCoords = GetEntityCoords(ped)

		-- Cloakroom
		local cloak_dist = #(PlayerCoords - positions.Cloakroom)
		if cloak_dist <= DrawDist then
			Sleep = 0
			DrawMarker(setting.Type, positions.Cloakroom, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, setting.Size.x, setting.Size.y, setting.Size.z, setting.Color.r, setting.Color.g, setting.Color.b, 200, false, false, 2, setting.Rotate, nil, nil, false)
			if cloak_dist <= 2.0 then
				if not DrawingTextUI then
					DrawingTextUI = true
					ESX.TextUI(TranslateCap("Start_textui"), "info") 
				end
				if IsControlJustPressed(0, 38) then
					if LocalPlayer.state.job.name ~= 'taxi' then 
						return ESX.ShowNotification(TranslateCap("Cannot_Perform"))
					end
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
					DrawingTextUI = false
				end
			else
				if DrawingTextUI then 
					ESX.HideUI()
					DrawingTextUI = false
				end
			end
		end

		-- Vehicle Returning

		if job_veh and DoesEntityExist(job_veh) then
			local del_dist = #(PlayerCoords - positions.VehicleSpawn.xyz)
			if del_dist <= DrawDist then
				Sleep = 0
				DrawMarker(setting.Type, positions.VehicleSpawn.xyz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, setting.Size.x, setting.Size.y, setting.Size.z, 200, 50, 50, 200, false, false, 2, setting.Rotate, nil, nil, false)
				if del_dist <= 2.0 then
					if not DrawingTextUI2 then
						DrawingTextUI2 = true
						ESX.TextUI(TranslateCap("return_textui"), "info") 
					end
					if IsControlJustPressed(0, 38) then
						if LocalPlayer.state.job.name ~= 'taxi' then 
							return ESX.ShowNotification(TranslateCap("Cannot_Perform"))
						end
						if forceWorkOutfit then
							ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
								TriggerEvent('skinchanger:loadSkin', skin)
							end)
						end
						NetworkRequestControlOfEntity(job_veh)
						while not NetworkHasControlOfEntity(job_veh) do
							Wait(0)
						end
						DeleteEntity(job_veh)
						TriggerServerEvent("taxi:endjob")
						ESX.HideUI()
						DrawingTextUI2 = false
					end
				else
					if DrawingTextUI2 then 
						ESX.HideUI()
						DrawingTextUI2 = false
					end
				end
			end
		end
		Wait(Sleep)
	end
end

CreateThread(function()
	createBlips()
	loadMarkers()
end)

AddEventHandler('esx:setJob', loadMarkers)

local function GetPlayerFromPed(Ped)
	local ply = NetworkGetPlayerIndexFromPed(Ped)
	return ply > 0 and GetPlayerServerId(ply) or false
end

local function FindRoute()
	local NearestRoute = vector3(0, 0, 0)
	local Coords = GetEntityCoords(ESX.PlayerData.ped)
	while #(NearestRoute - Coords) < Config.MinimumDistance do
		NearestRoute = Config.DropOffLocations[math.random(#Config.DropOffLocations)]
	end

	if NearestRoute == vector3(0, 0, 0) then
		NearestRoute = Config.DropOffLocations[math.random(#Config.DropOffLocations)]
	end
	return NearestRoute
end

local function IsPlayerINTaxi(vehicle)
	local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
	for i = maxSeats - 1, 0, -1 do
		if not IsVehicleSeatFree(vehicle, i) then
			local PedInSeat = GetPedInVehicleSeat(vehicle, i)
			if IsPedAPlayer(PedInSeat) then
				return true, i
			end
		end
	end
	return false
end

local function GetRandomWalkingNPC(Coords)
	if not NPCMissions then
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
		NPCMissions = false
		return nil
	end

	local npc = search[math.random(#search)]
	local Dist = #(GetEntityCoords(npc) - Coords)
	local tries = 0
	while Dist < Config.MinimumNpcDistance do 
		Wait(0)
		npc = search[math.random(#search)]
		Dist = #(GetEntityCoords(npc) - Coords)
		tries += 1
		if tries > 25 then
			ESX.ShowNotification(TranslateCap("customer_unavailable"), "error")
			NPCMissions = false
			return nil
		end
	end
	return npc
end

local function OpenMenu()
	if InTaxiAsPassenger then return end
	if LocalPlayer.state.job.name ~= "taxi" then return end
	local PlayerInTaxi, SeatIndex = IsPlayerINTaxi(job_veh)
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
			disabled = NPCMissions,
			description = TranslateCap(NPCMissions and ("Unavailable") or "menu_start_desc")
		},
		{
			title = TranslateCap("menu_reset"),
			icon = "fas fa-tachometer-alt",
			value = "reset_value",
			disabled = NPCMissions,
			description = TranslateCap(NPCMissions and ("Unavailable") or "menu_reset_desc")
		},
		{
			title = TranslateCap("menu_toggle"),
			icon = "fas fa-power-off",
			value = "toggle_meter",
			description = ("Currently: %s"):format(TranslateCap(meterRunning and "running" or "paused"))
		},
		{
			title = TranslateCap("menu_bill"),
			icon = "fas fa-money-bill-alt",
			value = "bill_player",
			description = TranslateCap(PlayerInTaxi and "menu_bill_desc" or "Unavailable"),
			disabled = not PlayerInTaxi
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
			NPCMissions = not NPCMissions
			if NPCMissions then
				CurrentNPC = GetRandomWalkingNPC(GetEntityCoords(ESX.PlayerData.ped))
			end
		elseif element.value == "reset_value" then
			playerprice = 0
			BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
			ScaleformMovieMethodAddParamInt(playerprice)
			EndScaleformMovieMethod()

			if not PlayerInTaxi then return end
			local pindex = GetPlayerFromPed(GetPedInVehicleSeat(job_veh, SeatIndex))
			if pindex then 
				TriggerServerEvent("taxi:syncprice", pindex, playerprice)
			end
		elseif element.value == "toggle_meter" then
			meterRunning = not meterRunning
		elseif element.value == "bill_player" then
			if not PlayerInTaxi then return end
			local pindex = GetPlayerFromPed(GetPedInVehicleSeat(job_veh, SeatIndex))
			if pindex then 
				TriggerServerEvent('esx_billing:sendBill', pindex, nil, TranslateCap("bill_reason"), playerprice)
				ESX.ShowNotification(TranslateCap("bill_sent", playerprice), "success")
			end
			ESX.CloseContext()
		else
			return ESX.CloseContext()
		end
		OpenMenu()
	end)
end

ESX.RegisterInput("taxi:menu", TranslateCap("keybind_desc"), "keyboard", "f6", OpenMenu)

local function AddDestination(movie, settings)
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

local function TaxiMeterScaleform()
	movie = RequestScaleformMovie("TAXI_DISPLAY")
	local RenderTarget = nil
	while not HasScaleformMovieLoaded(movie) do
		Wait(0)
	end
	RequestModel(joaat("prop_taxi_meter_2"))
	while not HasModelLoaded(joaat("prop_taxi_meter_2")) do
		Wait(0)
	end
	Object = CreateObjectNoOffset(joaat("prop_taxi_meter_2"), GetEntityCoords(job_veh), true, true, false)
	AttachEntityToEntity(Object, job_veh, GetEntityBoneIndexByName(job_veh, "Chassis"), vector3(-0.05, 0.78, 0.39), vector3(-6.0, 0.0, -10.0), false, false, false, false, 2, true, 0)
	if not IsNamedRendertargetRegistered("taxi") then
		RegisterNamedRendertarget("taxi", false)
		if not IsNamedRendertargetLinked(GetEntityModel(Object)) then
			LinkNamedRendertarget(GetEntityModel(Object))
		end
		RenderTarget = GetNamedRendertargetRenderId("taxi")
	end
	BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
	ScaleformMovieMethodAddParamInt(0) -- set default price
	EndScaleformMovieMethod()
	local foundroute, CustomerInVehicle, route, oldcoords = false, false, nil, vector3(0, 0, 0)
	DestinationBlip = nil
	while true do
		local Sleep = 500
		local InTaxi = IsPedInVehicle(ESX.PlayerData.ped, job_veh, false)
		if DoesEntityExist(job_veh) then
			local PlyCoords = GetEntityCoords(ESX.PlayerData.ped)
			if InTaxi then
				Sleep = 0

				SetTextRenderId(RenderTarget)
				SetScriptGfxDrawOrder(4)
				SetTaxiLights(job_veh, false)
				DrawScaleformMovie(movie, 0.201, 0.351, 0.4, 0.6, 0, 0, 0, 255, 0)
				SetTextRenderId(GetDefaultScriptRendertargetRenderId()) -- Reset Render ID

				-- NPC Missions
				if CurrentNPC and DoesEntityExist(CurrentNPC) then
					local CustomerCoords = GetEntityCoords(CurrentNPC)
					if not DoesBlipExist(CurrentCustomerBlip) and not CustomerInVehicle then
						CurrentCustomerBlip = AddBlipForEntity(CurrentNPC)
						SetBlipAsFriendly(CurrentCustomerBlip, true)
						SetBlipSprite(CurrentCustomerBlip, 480)
						SetBlipColour(CurrentCustomerBlip, 2)
						SetBlipCategory(CurrentCustomerBlip, 3)
						SetBlipRoute(CurrentCustomerBlip, true)
						SetEntityAsMissionEntity(CurrentNPC, true, true)
						SetBlockingOfNonTemporaryEvents(CurrentNPC, true)
						ClearPedTasksImmediately(CurrentNPC)
						local zone = GetLabelText(GetNameOfZone(CustomerCoords))
						local street = (GetStreetNameAtCoord(CustomerCoords.x, CustomerCoords.y, CustomerCoords.z))
						local streetname = GetStreetNameFromHashKey(street)
						ESX.ShowNotification(TranslateCap("customer_new"), "info")
						AddDestination(movie, {
							sprite = 480,
							colour = {r = 50, g = 250, b = 50},
							label = "Pick up",
							zone = zone,
							street = streetname
						})
					end
					if #(PlyCoords - CustomerCoords) <= 10.0 then
						if IsVehicleSeatFree(job_veh, 1) and not CustomerInVehicle then
							BringVehicleToHalt(job_veh, 5.0, 4, false)
							TaskEnterVehicle(CurrentNPC, job_veh, -1, 2, 1.0, 1, 0)
							CustomerInVehicle = true
						end
						if IsPedInVehicle(CurrentNPC, job_veh, true) then
							if not foundroute then
								RemoveBlip(CurrentCustomerBlip)
								CurrentCustomerBlip = nil
								foundroute = true
								route = FindRoute()

								DestinationBlip = AddBlipForCoord(route)
								SetBlipSprite(DestinationBlip, 8)
								SetBlipColour(DestinationBlip, 33)
								SetBlipCategory(DestinationBlip, 3)
								SetBlipRoute(DestinationBlip, true)

								Price = math.floor((#(PlyCoords - route) * Config.PricePerUnit) / 20)
								BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
								ScaleformMovieMethodAddParamInt(Price)
								EndScaleformMovieMethod()
								SetEntityAsMissionEntity(CurrentNPC)
								SetBlockingOfNonTemporaryEvents(CurrentNPC, true)

								local BlipCoords = GetBlipCoords(DestinationBlip)
								local zone = GetLabelText(GetNameOfZone(BlipCoords))
								local street = (GetStreetNameAtCoord(BlipCoords.x, BlipCoords.y, BlipCoords.z))
								local streetname = GetStreetNameFromHashKey(street)
								AddDestination(movie, {
									sprite = 8,
									colour = {r = 250, g = 250, b = 10},
									label = "Drop Off",
									zone = zone,
									street = streetname
								})
							end
							if IsEntityDead(CurrentNPC) then
								ESX.ShowNotification(TranslateCap("customer_lost"), "error")
								RemoveBlip(DestinationBlip)
								SetEntityAsNoLongerNeeded(CurrentNPC)
								CurrentNPC = nil
								DestinationBlip = nil
								foundroute, CustomerInVehicle, route = false, false, nil
								BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
								ScaleformMovieMethodAddParamInt(0) -- reset prce
								EndScaleformMovieMethod()
								NPCMissions = false
							end
							if foundroute then -- reached end of route
								if #(PlyCoords - route) <= 6.0 then
									BringVehicleToHalt(job_veh, 3.5, -1, false)
									TaskLeaveVehicle(CurrentNPC, job_veh, 1)
									RemoveBlip(DestinationBlip)
									SetTimeout(1200, function()
										TaskWanderStandard(CurrentNPC, 10.0, 10)
										SetPedKeepTask(CurrentNPC, true)
										SetEntityAsNoLongerNeeded(CurrentNPC)
										StopBringVehicleToHalt(job_veh)
										TriggerServerEvent("taxi:finish", Price, route)
										CurrentNPC = nil
										DestinationBlip = nil
										CurrentCustomerBlip = nil
										foundroute, CustomerInVehicle, route = false, false, nil
										CustomerCoords = nil
										NPCMissions = false
										Price = 0
										BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
										ScaleformMovieMethodAddParamInt(0) -- reset price
										EndScaleformMovieMethod()													
									end)
								end
							end
						end
					end
				end

				-- player Missions
				local PlayerInTaxi, SeatIndex = IsPlayerINTaxi(job_veh)

				if PlayerInTaxi then
					NPCMissions = false
					SetUseWaypointAsDestination(true)
					local waypoint = GetWaypointBlipEnumId()
					DestinationBlip = GetFirstBlipInfoId(waypoint)
					local BlipCoords = GetBlipCoords(DestinationBlip)
					if (BlipCoords ~= vector3(0,0,0)) and not route or route ~= BlipCoords then
						route = BlipCoords
						local zone = GetLabelText(GetNameOfZone(BlipCoords))
						local street = (GetStreetNameAtCoord(BlipCoords.x, BlipCoords.y, BlipCoords.z))
						local streetname = GetStreetNameFromHashKey(street)
						AddDestination(movie, {
							sprite = 8,
							colour = {r = 250, g = 250, b = 10},
							label = "Drop Off",
							zone = zone,
							street = streetname
						})
						local pindex = GetPlayerFromPed(GetPedInVehicleSeat(job_veh, SeatIndex))
						if pindex then
							TriggerServerEvent("taxi:sync", pindex)
						end
					end
					if route then
						if #(oldcoords - PlyCoords) > Config.DistancePerDollar then
							oldcoords = PlyCoords
							if meterRunning then
								playerprice += 1
								BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
								ScaleformMovieMethodAddParamInt(playerprice)
								EndScaleformMovieMethod()
								local pindex = GetPlayerFromPed(GetPedInVehicleSeat(job_veh, SeatIndex))
								if pindex then 
									TriggerServerEvent("taxi:syncprice", pindex, playerprice)
								end
							end
						end
					end
				end
				if LocalPlayer.state.job.name ~= "taxi" then
					DeleteObject(Object)
					SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
					SetScaleformMovieAsNoLongerNeeded(movie)
					SetVehicleDoorsLocked(job_veh, 2)
					SetVehicleUndriveable(job_veh, true)
					SetVehicleAsNoLongerNeeded(job_veh)
					ReleaseNamedRendertarget("taxi")
					if CurrentNPC then
						NPCMissions = false
						SetPedAsNoLongerNeeded(CurrentNPC)
						CurrentNPC = nil
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
			DeleteObject(Object)
			SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
			SetScaleformMovieAsNoLongerNeeded(movie)
			ReleaseNamedRendertarget("taxi")
			if CurrentNPC then
				NPCMissions = false
				SetPedAsNoLongerNeeded(CurrentNPC)
				CurrentNPC = nil
			end
			break
		end
		Wait(Sleep)
	end
end

RegisterNetEvent("taxi:start", function(netId)
	job_veh = NetworkGetEntityFromNetworkId(netId)
	CreateThread(TaxiMeterScaleform)
end)

AddEventHandler("onResourceStop", function()
	DeleteObject(Object)
	SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
	SetScaleformMovieAsNoLongerNeeded(movie)
	ReleaseNamedRendertarget("taxi")

	for k, v in pairs(blips) do
		RemoveBlip(v)
	end

	if not CurrentNPC then return end
	NPCMissions = false
	SetPedAsNoLongerNeeded(CurrentNPC)
	CurrentNPC = nil
end)

local function TaxiMeterSync()
	local route = nil
	local RenderTarget = nil
	while true do
		local Sleep = 0
		if not InTaxiAsPassenger then break end
		local inveh = IsPedInAnyVehicle(ESX.PlayerData.ped, false)
		if not inveh then
			SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
			SetScaleformMovieAsNoLongerNeeded(movie)
			ReleaseNamedRendertarget("taxi")
			InTaxiAsPassenger = false
			route, RenderTarget, movie = nil, nil, nil
		end
		if not RenderTarget then
			movie = RequestScaleformMovie("TAXI_DISPLAY")
			while not HasScaleformMovieLoaded(movie) do
				Wait(0)
			end
			if not IsNamedRendertargetRegistered("taxi") then
				RegisterNamedRendertarget("taxi", false)
				if not IsNamedRendertargetLinked(joaat("prop_taxi_meter_2")) then
					LinkNamedRendertarget(joaat("prop_taxi_meter_2"))
				end
				RenderTarget = GetNamedRendertargetRenderId("taxi")
			end
		end
		SetTextRenderId(RenderTarget)
		SetScriptGfxDrawOrder(4)
		DrawScaleformMovie(movie, 0.201, 0.351, 0.4, 0.6, 0, 0, 0, 255, 0)
		SetTextRenderId(GetDefaultScriptRendertargetRenderId())
		local waypoint = GetWaypointBlipEnumId()
		DestinationBlip = GetFirstBlipInfoId(waypoint)
		local BlipCoords = GetBlipCoords(DestinationBlip)
		if (BlipCoords ~= vector3(0,0,0)) and not route or route ~= BlipCoords then
			route = BlipCoords
			local zone = GetLabelText(GetNameOfZone(BlipCoords))
			local street = (GetStreetNameAtCoord(BlipCoords.x, BlipCoords.y, BlipCoords.z))
			local streetname = GetStreetNameFromHashKey(street)
			AddDestination(movie, {
				sprite = 8,
				colour = {r = 250, g = 250, b = 10},
				label = "Drop Off",
				zone = zone,
				street = streetname
			})
		end
		if SyncPrice then 
			BeginScaleformMovieMethod(movie, "SET_TAXI_PRICE")
			ScaleformMovieMethodAddParamInt(SyncPrice)
			EndScaleformMovieMethod()
			SyncPrice = false
		end
		Wait(Sleep)
	end
end

RegisterNetEvent("taxi:c:sync", function()
	InTaxiAsPassenger = true
	TaxiMeterSync()
end)

RegisterNetEvent("taxi:c:syncprice", function(price)
	SyncPrice = price
end)
