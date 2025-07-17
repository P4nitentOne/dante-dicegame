local QBCore = exports['qb-core']:GetCoreObject()

local inBet = false
local acceptCommandRegistered = false

local function PlayDiceAnim()
    local ped = PlayerPedId()
    local dict = "anim@mp_player_intcelebrationmale@wank"
    local anim = "wank"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end

    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 50, 0, false, false, false)
    Wait(2000)
    ClearPedTasks(ped)
end

local function SpawnDiceProps()
    local model = `ch_prop_arcade_fortune_coin_01a`

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.5, 1.0, 0.2)

    local dice1 = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local dice2 = CreateObject(model, coords.x + 0.2, coords.y, coords.z, true, true, false)

    SetEntityRotation(dice1, math.random(0, 360), math.random(0, 360), math.random(0, 360), 2, true)
    SetEntityRotation(dice2, math.random(0, 360), math.random(0, 360), math.random(0, 360), 2, true)

    ApplyForceToEntity(dice1, 1, 0.5, 0.5, 0.3, 0, 0, 0, 0, true, true, true, false, true)
    ApplyForceToEntity(dice2, 1, -0.5, 0.5, 0.3, 0, 0, 0, 0, true, true, true, false, true)

    Wait(5000)
    DeleteEntity(dice1)
    DeleteEntity(dice2)
end

-- /dicebet [amount] [targetId]
RegisterCommand("dicebet", function(_, args)
    if inBet then return end

    local amount = tonumber(args[1])
    local targetId = tonumber(args[2])

    if not amount or amount <= 0 then
        QBCore.Functions.Notify("❌ Invalid amount.", "error")
        return
    end

    if not targetId then
        QBCore.Functions.Notify("❌ You must enter the target player's ID.", "error")
        return
    end

    if targetId == GetPlayerServerId(PlayerId()) then
        QBCore.Functions.Notify("❌ You can't bet against yourself.", "error")
        return
    end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local found = false

    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetId then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(myCoords - targetCoords)

            if dist <= 3.0 then
                inBet = true
                TriggerServerEvent("dicegame:requestBet", targetId, amount)
                acceptCommandRegistered = false
                found = true
                break
            else
                QBCore.Functions.Notify("❌ Player is too far away (must be within 3 meters).", "error")
                return
            end
        end
    end

    if not found then
        QBCore.Functions.Notify("❌ Player with ID " .. targetId .. " not found nearby.", "error")
    end
end)

RegisterNetEvent("dicegame:betRequest")
AddEventHandler("dicegame:betRequest", function(fromId, amount)
    if acceptCommandRegistered then return end
    acceptCommandRegistered = true

    QBCore.Functions.Notify("🎲 Player challenged you to a $"..amount.." dice roll. Type /acceptdice to play!", "primary")

    RegisterCommand("acceptdice", function()
        if not acceptCommandRegistered then
            QBCore.Functions.Notify("❌ No active challenge.", "error")
            return
        end

        TriggerServerEvent("dicegame:acceptBet", fromId, amount)
        QBCore.Functions.Notify("🎲 You accepted the bet!", "success")

        acceptCommandRegistered = false
        inBet = false

        -- Remove /acceptdice after use
        TriggerEvent("chat:removeSuggestion", "/acceptdice")
        ExecuteCommand("removecommand acceptdice")
    end, false)

    
    TriggerEvent('chat:addSuggestion', '/acceptdice', 'Accept the dice bet challenge')
end)

RegisterNetEvent("dicegame:rollResult")
AddEventHandler("dicegame:rollResult", function(yourRoll, oppRoll, won, amount)
    PlayDiceAnim()
    SpawnDiceProps()

    QBCore.Functions.Notify("🎲 You rolled: " .. yourRoll .. " | Opponent rolled: " .. oppRoll, "primary")

    if won == true then
        QBCore.Functions.Notify("✅ You won $" .. (amount * 2) .. "!", "success")
    elseif won == false then
        QBCore.Functions.Notify("❌ You lost $" .. amount .. ".", "error")
    else
        QBCore.Functions.Notify("⚔️ It's a tie! Money refunded.", "info")
    end

    inBet = false
    acceptCommandRegistered = false
end)

RegisterCommand("dicecheck", function()
    local playerPed = PlayerPedId()
    local myCoords = GetEntityCoords(playerPed)
    local foundAnyone = false

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(myCoords - targetCoords)

            if dist <= 10.0 then
                local serverId = GetPlayerServerId(player)
                local name = GetPlayerName(player)
                TriggerEvent("chat:addMessage", {
                    color = {0, 255, 100},
                    args = {"Nearby Player", "ID: " .. serverId .. " | Name: " .. name .. " | Distance: " .. string.format("%.1f", dist) .. "m"}
                })
                foundAnyone = true
            end
        end
    end

    if not foundAnyone then
        QBCore.Functions.Notify("No players nearby within 10 meters.", "error")
    end
end, false)
