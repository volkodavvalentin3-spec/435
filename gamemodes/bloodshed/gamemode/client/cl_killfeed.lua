local killfeed = {}
local killfeed_lifetime = 10
local killfeed_fade = 2

local function GetPlayerColor(ply)
    if not IsValid(ply) then return color_white end
    local class = ply:GetNW2String("Class")
    local roleData = MuR:GetRole(class)
    if roleData and roleData.color then
        return roleData.color
    end
    return color_white
end

net.Receive("MuR.KillFeed", function()
    local victim = net.ReadEntity()
    local attacker = net.ReadEntity()
    local inflictorClass = net.ReadString()

    if not IsValid(victim) then return end

    local entry = {
        victim = victim:Nick(),
        victimColor = GetPlayerColor(victim),
        time = CurTime()
    }

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        entry.attacker = attacker:Nick()
        entry.attackerColor = GetPlayerColor(attacker)
    elseif IsValid(attacker) and not attacker:IsPlayer() then

         local cls = attacker:GetClass()
         if cls == "worldspawn" then
             entry.attacker = nil
         else
             entry.attacker = cls
             entry.attackerColor = Color(200, 200, 200)
         end
    elseif attacker == victim then
        entry.attacker = nil
    end

    table.insert(killfeed, entry)
end)

local allowedModes = {[5]=true, [11]=true, [12]=true, [13]=true, [17]=true}

hook.Add("HUDPaint", "MuR.DrawKillFeed", function()
    if not allowedModes[MuR.GamemodeCount] then return end
    if MuR.GetClient and MuR:GetClient("blsd_nohud") then return end

    local x = ScrW() - 20
    local y = 20
    local height = 30
    local padding = 10

    for i = #killfeed, 1, -1 do
        local entry = killfeed[i]
        local timeDiff = CurTime() - entry.time

        if timeDiff > killfeed_lifetime then
            table.remove(killfeed, i)
            continue
        end

        local alpha = 255
        if timeDiff > (killfeed_lifetime - killfeed_fade) then
            alpha = math.Remap(timeDiff, killfeed_lifetime - killfeed_fade, killfeed_lifetime, 255, 0)
        end

        surface.SetFont("MuR_Font2")

        local victimW, _ = surface.GetTextSize(entry.victim)
        local attackerW = 0
        local sepW = 0
        local separator = " ☠ "

        if entry.attacker then
            attackerW, _ = surface.GetTextSize(entry.attacker)
            sepW, _ = surface.GetTextSize(separator)
        else
            separator = " ☠ "
            sepW, _ = surface.GetTextSize(separator)
        end

        local totalW = victimW + attackerW + sepW + padding * 2

        draw.RoundedBox(4, x - totalW, y, totalW, height, Color(20, 20, 20, 200 * (alpha/255)))

        local currentX = x - padding

        draw.SimpleText(entry.victim, "MuR_Font2", currentX, y + height/2, ColorAlpha(entry.victimColor, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        currentX = currentX - victimW

        draw.SimpleText(separator, "MuR_Font2", currentX, y + height/2, Color(200, 200, 200, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        currentX = currentX - sepW

        if entry.attacker then

            draw.SimpleText(entry.attacker, "MuR_Font2", currentX, y + height/2, ColorAlpha(entry.attackerColor, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        y = y + height + 5
    end
end)
