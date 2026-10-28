local function GetRandomPlayer(exclude)
    local players = {}
    for _, ply in player.Iterator() do
        if ply:Alive() and ply ~= exclude then
            table.insert(players, ply)
        end
    end
    return #players > 0 and players[math.random(#players)] or nil
end

local ROLE = {}

ROLE.name = "HeadHunter"
ROLE.team = 2
ROLE.flashlight = false

ROLE.langName = "headhunter"
ROLE.color = Color(255, 120, 60)
ROLE.desc = "headhunter_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("tfa_bs_cleaver")

    timer.Simple(2, function()
        if IsValid(ply) and ply:Alive() then
            local rnd = GetRandomPlayer(ply)
            if IsValid(rnd) then ply:SetNW2Entity("CurrentTarget", rnd) end
        end
    end)
end

MuR:RegisterRole(ROLE)
