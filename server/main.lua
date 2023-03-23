local Config = GlobalState.taxijob.Config

RegisterNetEvent("taxi:startjob", function() 
    local source = source

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    if Player(source).state.job.name ~= "taxi" then return end

    xPlayer.showNotification(Translate("start_notify"), "success")

    ESX.OneSync.SpawnVehicle("taxi", Config.Positions.VehicleSpawn.xyz, Config.Positions.VehicleSpawn.w, Config.PlateText ~= "" and {plate = Config.PlateText} or {}, function(netId)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        while not DoesEntityExist(vehicle) do
            Wait(0)
        end
        if Config.PlateText ~= "" then
            while GetVehicleNumberPlateText(vehicle) ~= Config.PlateText do
                Wait(0)
            end
        end
        Wait(200)
        TriggerClientEvent('taxi:start', source, netId)
    end)
end)

RegisterNetEvent("taxi:sync", function(player)
   TriggerClientEvent("taxi:c:sync", player)
end)

RegisterNetEvent("taxi:syncprice", function(player, price)
    if not Config.ShowPriceToPassengers then return end
    TriggerClientEvent("taxi:c:syncprice", player, price)
end)

RegisterNetEvent("taxi:endjob", function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    if Player(source).state.job.name ~= "taxi" then return end

    xPlayer.showNotification(Translate("return_notify"), "success")
end)

function IsValidRoute(route)
    for i=1, #(Config.DropOffLocations) do
        if Config.DropOffLocations[i] == route then 
            return true
        end
    end
    return false
end

RegisterNetEvent("taxi:finish", function(price, route)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    if Player(source).state.job.name ~= "taxi" then return end
    if not IsValidRoute(route) then return end

    if #(GetEntityCoords(GetPlayerPed(source)) - route) <= 6.0 then
        xPlayer.addMoney(price)
        xPlayer.showNotification(Translate("customer_dropoff", price), "success")
        xPlayer.showNotification(Translate("new_mission_notify"), "info")
    end
end)
