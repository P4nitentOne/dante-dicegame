local QBCore = exports['qb-core']:GetCoreObject()

-- Keep track of active challenges
local pendingBets = {}

-- When player sends a bet request
RegisterServerEvent("dicegame:requestBet", function(targetId, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or not targetId or not amount or amount <= 0 then
        return
    end

    -- Check if already has a pending challenge
    if pendingBets[targetId] then
        TriggerClientEvent("QBCore:Notify", src, "❌ That player already has a pending challenge.", "error")
        return
    end

    -- Check player has enough money
    if not Player.Functions.RemoveMoney("cash", amount, "dice-bet") then
        TriggerClientEvent("QBCore:Notify", src, "❌ You don't have enough cash.", "error")
        return
    end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        Player.Functions.AddMoney("cash", amount, "refund-bet")
        TriggerClientEvent("QBCore:Notify", src, "❌ That player is not online.", "error")
        return
    end

    pendingBets[targetId] = {
        challenger = src,
        amount = amount
    }

    TriggerClientEvent("dicegame:betRequest", targetId, src, amount)
    TriggerClientEvent("QBCore:Notify", src, "✅ Bet request sent!", "success")
end)

-- When bet is accepted
RegisterServerEvent("dicegame:acceptBet", function(fromId, amount)
    local src = source
    local Player1 = QBCore.Functions.GetPlayer(src)
    local Player2 = QBCore.Functions.GetPlayer(fromId)

    local pending = pendingBets[src]

    -- Validate pending bet exists and matches
    if not pending or pending.challenger ~= fromId or pending.amount ~= amount then
        TriggerClientEvent("QBCore:Notify", src, "❌ No valid bet found. Ask the challenger to /dicebet again.", "error")
        return
    end

    if not Player1 or not Player2 then
        return
    end

    -- Remove the bet from tracking
    pendingBets[src] = nil

    -- Deduct money from acceptor
    if not Player1.Functions.RemoveMoney("cash", amount, "dice-bet") then
        -- Refund challenger
        Player2.Functions.AddMoney("cash", amount, "refund-bet")
        TriggerClientEvent("QBCore:Notify", src, "❌ You don’t have enough cash to accept the bet.", "error")
        TriggerClientEvent("QBCore:Notify", fromId, "❌ Opponent couldn’t pay. You’ve been refunded.", "error")
        return
    end

    -- Roll dice
    local roll1 = math.random(1, 6)
    local roll2 = math.random(1, 6)

    if roll1 > roll2 then
        Player1.Functions.AddMoney("cash", amount * 2, "dice-win")
        TriggerClientEvent("dicegame:rollResult", src, roll1, roll2, true, amount)
        TriggerClientEvent("dicegame:rollResult", fromId, roll2, roll1, false, amount)
    elseif roll2 > roll1 then
        Player2.Functions.AddMoney("cash", amount * 2, "dice-win")
        TriggerClientEvent("dicegame:rollResult", src, roll1, roll2, false, amount)
        TriggerClientEvent("dicegame:rollResult", fromId, roll2, roll1, true, amount)
    else
        Player1.Functions.AddMoney("cash", amount, "dice-refund")
        Player2.Functions.AddMoney("cash", amount, "dice-refund")
        TriggerClientEvent("dicegame:rollResult", src, roll1, roll2, nil, amount)
        TriggerClientEvent("dicegame:rollResult", fromId, roll2, roll1, nil, amount)
    end
end)
