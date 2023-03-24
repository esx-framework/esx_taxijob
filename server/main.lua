local taxiJob = {}

---Check is route valid
---@param route vector3
---@return boolean
function taxiJob:IsValidRoute(route)
    for i=1, #(Config.DropOffLocations) do
        if Config.DropOffLocations[i] == route then 
            return true
        end
    end
    return false
end

function taxiJob:initialize()
    RegisterNetEvent("taxi:startjob", function() 
        local source = source
    
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
    
        if xPlayer.job.name ~= "taxi" then return end
    
        xPlayer.showNotification(TranslateCap("start_notify"), "success")
    
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
        if xPlayer.job.name ~= "taxi" then return end
    
        xPlayer.showNotification(TranslateCap("return_notify"), "success")
    end)

    RegisterNetEvent("taxi:finish", function(price, route)
        local source = source
        if not route then return end
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        if xPlayer.job.name ~= "taxi" then return end
        if not self:IsValidRoute(route) then return end

        if #(xPlayer.getCoords() - route) > 6.0 then return end
    
        xPlayer.addMoney(price)
        xPlayer.showNotification(TranslateCap("customer_dropoff", price), "success")
        xPlayer.showNotification(TranslateCap("new_mission_notify"), "info")
    end)
end

CreateThread(function()
    taxiJob:initialize()
end)
