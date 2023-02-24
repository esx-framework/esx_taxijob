RegisterNetEvent("taxi:startjob", function() 
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then 
        return
    end
    if xPlayer.job.name ~= "taxi" then 
        return
    end
    xPlayer.showNotification("Started Job!", "success")
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

if Config.ShowPriceToPassengers then
    RegisterNetEvent("taxi:syncprice", function(player, price)
        TriggerClientEvent("taxi:c:syncprice", player, price)
    end)
end

ESX.RegisterServerCallback("taxi:CanInteract", function(src, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    cb(xPlayer.job.name == "taxi")
end)

RegisterNetEvent("taxi:endjob", function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name ~= "taxi" then
        return
    end
    xPlayer.showNotification("Vehicle Returned!", "success")
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
    if not xPlayer then 
        return
    end
    if xPlayer.job.name ~= "taxi" then 
        return
    end
    if not IsValidRoute(route) then 
        return 
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - route) <= 6.0 then
        xPlayer.addMoney(price)
        xPlayer.showNotification(("Recieved ~g~$%s~s~ From Drop off!"):format(price), "success")
        xPlayer.showNotification(("Use The ~b~Options Menu~s~ to start new mission."), "info")
   end
end)