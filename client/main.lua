local job_veh = nil
local blips = {}
local NPCMissions = false
local playerprice = 0
local DrawingTextUI = false
local DrawingTextUI2 = false
local Object = nil
local InTaxiAsPassenger = false
CreateThread(function()
	local blip = AddBlipForCoord(Config.Positions.Cloakroom)
	SetBlipSprite(blip, 198)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.5)
	SetBlipColour(blip, 5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName("Taxi Rank")
	EndTextCommandSetBlipName(blip)
	blips.Depo = blip
	while true do
		local Sleep = 1500
		if ESX.PlayerLoaded then
			if ESX.PlayerData.job.name == "taxi" then
				local PlayerCoords = GetEntityCoords(ESX.PlayerData.ped)

				-- Cloakroom
				local cloak_dist = #(PlayerCoords - Config.Positions.Cloakroom)
				if cloak_dist <= Config.DrawDistance then
					local setting = Config.Marker
					Sleep = 0
					DrawMarker(setting.Type, Config.Positions.Cloakroom, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, setting.Size.x, setting.Size.y, setting.Size.z, setting.Color.r, setting.Color.g, setting.Color.b, 200, false, false, 2, setting.Rotate, nil, nil, false)
					if cloak_dist <= 2.0 then
						if not DrawingTextUI then
							DrawingTextUI = true
							ESX.TextUI("[E] - ~g~Start~s~ Job", "info") 
						end
						if IsControlJustPressed(0, 38) then
							ESX.TriggerServerCallback("taxi:CanInteract", function(can)
								if not can then 
									return ESX.ShowNotification("You ~r~Cannot~s~ Perform This Action!")
								end
								if not ESX.Game.IsSpawnPointClear(Config.Positions.VehicleSpawn.xyz, 5.0) then
									return ESX.ShowNotification("Spawnpoint ~r~Blocked~s~.", "error")
								end
								if Config.ForceWorkoutfit then
									ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
										if skin.sex == 0 then
											TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
										else
											TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
										end
									end)
								end
								TriggerServerEvent("taxi:startjob")
							end)
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
					local del_dist = #(PlayerCoords - Config.Positions.VehicleSpawn.xyz)
					if del_dist <= Config.DrawDistance then
						local setting = Config.Marker
						Sleep = 0
						DrawMarker(setting.Type, Config.Positions.VehicleSpawn.xyz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, setting.Size.x, setting.Size.y, setting.Size.z, 200, 50, 50, 200, false, false, 2, setting.Rotate, nil, nil, false)
						if del_dist <= 2.0 then
							if not DrawingTextUI2 then
								DrawingTextUI2 = true
								ESX.TextUI("[E] - ~r~Return~s~ Vehicle", "info") 
							end
							if IsControlJustPressed(0, 38) then
								ESX.TriggerServerCallback("taxi:CanInteract", function(can)
									if not can then 
										return ESX.ShowNotification("You ~r~Cannot~s~ Perform This Action!")
									end
									if Config.ForceWorkoutfit then
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
								end)
							end
						else
							if DrawingTextUI2 then 
								ESX.HideUI()
								DrawingTextUI2 = false
							end
						end
					end
				end
			end
		end
		Wait(Sleep)
	end
end)

function GetPlayerFromPed(Ped)
	local ply = NetworkGetPlayerIndexFromPed(Ped)
	return ply > 0 and GetPlayerServerId(ply) or false
end

local movie = nil
local CurrentNPC = nil
local CurrentCustomerBlip = nil
local meterRunning = true

function FindRoute()
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

function IsPlayerINTaxi(vehicle)
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

function OpenMenu()
	if InTaxiAsPassenger then 
		return 
	end
	if ESX.PlayerData.job.name ~= "taxi" or not ESX.PlayerLoaded then
		return
	end
	local PlayerInTaxi, SeatIndex = IsPlayerINTaxi(job_veh)
	local elements = {
		{
			title = "Taxi Options",
			icon = "fas fa-taxi",
			unselectable = true
		},
		{
			title = "Start NPC Mission",
			icon = "fas fa-phone",
			value = "toggle_npc",
			disabled = NPCMissions,
			description = NPCMissions and "Currently Unavailable" or ""
		},
		{
			title = "Reset Meter",
			icon = "fas fa-tachometer-alt",
			value = "reset_value",
			disabled = NPCMissions,
			description = NPCMissions and "Currently Unavailable" or "Reset Meter To 0"
		},
		{
			title = "Toggle Meter",
			icon = "fas fa-power-off",
			value = "toggle_meter",
			description = ("Currently: %s"):format(meterRunning and "Running" or "Paused")
		},
		{
			title = "Bill Passenger",
			icon = "fas fa-money-bill-alt",
			value = "bill_player",
			description = PlayerInTaxi and "Create a bill for the current passenger" or "Currently Unavailable",
			disabled = not PlayerInTaxi
		},
		{
			title = "Close",
			icon = "fas fa-times",
			value = "close",
			description = "Close Menu"
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

			if Config.ShowPriceToPassengers then 
				if not PlayerInTaxi then return end
				local pindex = GetPlayerFromPed(GetPedInVehicleSeat(job_veh, SeatIndex))
				if pindex then 
					TriggerServerEvent("taxi:syncprice", pindex, playerprice)
				end
			end
		elseif element.value == "toggle_meter" then
			meterRunning = not meterRunning
		elseif element.value == "bill_player" then
			if not PlayerInTaxi then return end
			local pindex = GetPlayerFromPed(GetPedInVehicleSeat(job_veh, SeatIndex))
			if pindex then 
				TriggerServerEvent('esx_billing:sendBill', pindex, nil, 'Taxi Ride', playerprice)
				ESX.ShowNotification("Sent Bill For ~g~£".. playerprice, "success")
			end
			ESX.CloseContext()
		else
			return ESX.CloseContext()
		end
		OpenMenu()
	end)
end

ESX.RegisterInput("taxi:menu", "[Taxi] Open Menu", "keyboard", "f5", OpenMenu)

function AddDestination(movie, settings)
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

local DestinationBlip = nil
RegisterNetEvent("taxi:start", function(netId)
	Wait(200)
	job_veh = NetworkGetEntityFromNetworkId(netId)
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
	AttachEntityToEntity(Object, job_veh, GetEntityBoneIndexByName(job_veh, "Chassis"), vector3(-0.05, 0.78, 0.39),
		vector3(-6.0, 0.0, -10.0), false, false, false, false, 2, true, 0)
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
	CreateThread(function()
		local foundroute = false
		local CustomerInVehicle = false
		local route = nil
		local oldcoords = vector3(0, 0, 0)
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
								ESX.ShowNotification("New Customer!", "info")
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
										ESX.ShowNotification("Customer Lost.", "error")
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
										if Config.ShowPriceToPassengers and pindex then 
											TriggerServerEvent("taxi:syncprice", pindex, playerprice)
										end
									end
								end
							end
						end
							if ESX.PlayerData.job.name ~= "taxi" then
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
			end
			Wait(Sleep)
		end
	end)
end)

function GetRandomWalkingNPC(Coords)
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
		ESX.ShowNotification("No Customers Available, Please try again.", "error")
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
		if tries > 15 then
			ESX.ShowNotification("No Customers Available, Please try again.", "error")
			NPCMissions = false
			return nil
		end
	end
	return npc
end

AddEventHandler("onResourceStop", function()
	DeleteObject(Object)
	SetModelAsNoLongerNeeded(joaat("prop_taxi_meter_2"))
	SetScaleformMovieAsNoLongerNeeded(movie)
	ReleaseNamedRendertarget("taxi")
	if CurrentNPC then
		NPCMissions = false
		SetPedAsNoLongerNeeded(CurrentNPC)
		CurrentNPC = nil
	end
end)

local SyncPrice = false
RegisterNetEvent("taxi:c:sync", function()
	InTaxiAsPassenger = true
end)

RegisterNetEvent("taxi:c:syncprice", function(price)
	SyncPrice = price
end)

CreateThread(function()
	local route = nil
	local RenderTarget = nil
	while true do
		local Sleep = 1000
		if InTaxiAsPassenger then
			Sleep = 0
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
			SetTextRenderId(GetDefaultScriptRendertargetRenderId()) -- Reset Render ID
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
		end
		Wait(Sleep)
	end
end)
