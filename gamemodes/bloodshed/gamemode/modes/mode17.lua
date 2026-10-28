MuR.RegisterMode(17, {
    name = "Territory Control (Gang Wars)",
    chance = 20,
    need_players = 4,
    disables = true,
    no_default_roles = true,
    custom_spawning = true,
    no_win_screen = true,
    no_guilt = true,
    timer = 600,
    countdown_on_start = true,
    kteam = "GangGreen",
    dteam = "GangRed",
    OnModeStarted = function(mode)
        if SERVER then
            MuR.Mode17 = {
                Points = {},
                TeamScores = {[1] = 0, [2] = 0},
                MaxScore = 100,
                PoliceDisabled = false,
                PoliceArriveTime = CurTime() + 540,
                RoundEnded = false
            }

            local playerCount = player.GetCount()
            local pointCount = 2
            if playerCount > 7 then pointCount = 3 end
            if playerCount > 13 then pointCount = 4 end

            local spawnedPoints = 0
            local attempts = 0
            local maxAttempts = 300

            while spawnedPoints < pointCount and attempts < maxAttempts do
                attempts = attempts + 1
                local pos = MuR:GetRandomPos(nil, nil, nil, nil, true)

                if pos then
                    local tooClose = false
                    for _, point in pairs(MuR.Mode17.Points) do
                        if pos:DistToSqr(point.pos) < 2000000 then
                            tooClose = true
                            break
                        end
                    end

                    if not tooClose then
                        local isIndoor = false
                        local traceUp = util.TraceLine({
                            start = pos,
                            endpos = pos + Vector(0, 0, 500),
                            mask = MASK_SOLID_BRUSHONLY
                        })

                        if traceUp.Hit and traceUp.HitPos.z - pos.z < 300 then
                            isIndoor = true
                        end

                        local shouldSpawn = false
                        if isIndoor then
                            shouldSpawn = math.random(1, 100) <= 75
                        else
                            shouldSpawn = math.random(1, 100) <= 25
                        end

                        if shouldSpawn then
                            local point = ents.Create("prop_physics")
                            point:SetModel("models/props/CS_militia/footlocker01_closed.mdl")
                            point:SetPos(pos+Vector(0,0,10))
                            point:SetAngles(Angle(0, math.random(0, 360), 0))
                            point:Spawn()
                            point:SetColor(Color(255, 255, 255))
                            point:SetRenderMode(RENDERMODE_TRANSALPHA)
                            point:GetPhysicsObject():EnableMotion(false)
                            point.IsControlPoint = true
                            point.ControlTeam = 0
                            point.CaptureProgress = 0
                            point.MaxCapture = 100

                            local light = ents.Create("light_dynamic")
                            light:SetPos(pos + Vector(0, 0, 48))
                            light:SetKeyValue("_light", "255 255 255 200")
                            light:SetKeyValue("brightness", "2")
                            light:SetKeyValue("distance", "256")
                            light:Spawn()
                            light:Fire("TurnOn")

                            point.Light = light

                            MuR.Mode17.Points[spawnedPoints + 1] = {
                                entity = point,
                                pos = pos,
                                team = 0,
                                progress = 0
                            }
                            spawnedPoints = spawnedPoints + 1
                        end
                    end
                end
            end

            util.AddNetworkString("MuR.Mode17Score")
            util.AddNetworkString("MuR.Mode17Points")

            MuR:SendMode17Data()

            timer.Create("MuR_Mode17_CorpseCleanup", 30, 0, function()
                if MuR.Gamemode == 17 then
                    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
                        if not IsValid(ent) then continue end
                        local isLive = false
                        for _, ply in player.Iterator() do
                            if ply:Alive() and ply:GetNW2Entity("RD_EntCam") == ent then
                                isLive = true
                                break
                            end
                        end
                        if not isLive then
                            ent:Remove()
                        end
                    end
                else
                    timer.Remove("MuR_Mode17_CorpseCleanup")
                end
            end)
        end
    end,
    OnModeThink = function(mode)
        if SERVER and MuR.Mode17 and not MuR.Ending then
            if not MuR.Mode17.PoliceDisabled and CurTime() >= MuR.Mode17.PoliceArriveTime then
                MuR.Mode17.PoliceDisabled = true
                MuR:SetPoliceTime(0, true)
                MuR.PoliceState = 1
                MuR:PlayDispatch("gunfire")
            end

            for i, pointData in pairs(MuR.Mode17.Points) do
                local point = pointData.entity
                if IsValid(point) then
                    local nearbyPlayers = {[1] = {}, [2] = {}}

                    for _, ply in player.Iterator() do
                        if ply:Alive() and ply:GetPos():DistToSqr(point:GetPos()) < 160000 then
                            local team = ply:Team()
                            if team == 1 or team == 2 then
                                table.insert(nearbyPlayers[team], ply)
                            end
                        end
                    end

                    local team1Count = #nearbyPlayers[1]
                    local team2Count = #nearbyPlayers[2]

                    if team1Count > 0 and team2Count == 0 then
                        pointData.progress = math.min(pointData.progress + (team1Count * FrameTime() * 2), 100)
                        if pointData.progress >= 100 and pointData.team ~= 1 then
                            pointData.team = 1
                            point:SetColor(Color(200, 50, 50))
                            if point.Light and IsValid(point.Light) then
                                point.Light:SetKeyValue("_light", "200 50 50 200")
                            end
                            for _, ply in pairs(nearbyPlayers[1]) do
                                ply:EmitSound("buttons/button14.wav", 75, 100)
                            end
                        end
                    elseif team2Count > 0 and team1Count == 0 then
                        pointData.progress = math.max(pointData.progress - (team2Count * FrameTime() * 2), -100)
                        if pointData.progress <= -100 and pointData.team ~= 2 then
                            pointData.team = 2
                            point:SetColor(Color(50, 200, 50))
                            if point.Light and IsValid(point.Light) then
                                point.Light:SetKeyValue("_light", "50 200 50 200")
                            end
                            for _, ply in pairs(nearbyPlayers[2]) do
                                ply:EmitSound("buttons/button14.wav", 75, 100)
                            end
                        end
                    elseif team1Count == 0 and team2Count == 0 then
                        if pointData.progress > 0 then
                            pointData.progress = math.max(pointData.progress - FrameTime() * 0.5, 0)
                        elseif pointData.progress < 0 then
                            pointData.progress = math.min(pointData.progress + FrameTime() * 0.5, 0)
                        end

                        if pointData.progress == 0 and pointData.team ~= 0 then
                            pointData.team = 0
                            point:SetColor(Color(255, 255, 255))
                            if point.Light and IsValid(point.Light) then
                                point.Light:SetKeyValue("_light", "255 255 255 200")
                            end
                        end
                    end
                end
            end

            local team1Points = 0
            local team2Points = 0
            local totalPoints = 0

            for _, pointData in pairs(MuR.Mode17.Points) do
                totalPoints = totalPoints + 1
                if pointData.team == 1 then
                    team1Points = team1Points + 1
                elseif pointData.team == 2 then
                    team2Points = team2Points + 1
                end
            end

            if totalPoints > 0 then
                local scoreChangeRate = FrameTime() * (MuR.Mode17.MaxScore / 60)

                if team1Points == team2Points then
                elseif team1Points > team2Points then
                    local advantage = (team1Points - team2Points) / totalPoints
                    local team1Gain = scoreChangeRate * advantage
                    MuR.Mode17.TeamScores[1] = math.min(MuR.Mode17.TeamScores[1] + team1Gain, MuR.Mode17.MaxScore)
                elseif team2Points > team1Points then
                    local advantage = (team2Points - team1Points) / totalPoints
                    local team2Gain = scoreChangeRate * advantage
                    MuR.Mode17.TeamScores[2] = math.min(MuR.Mode17.TeamScores[2] + team2Gain, MuR.Mode17.MaxScore)
                end

                local totalScore = MuR.Mode17.TeamScores[1] + MuR.Mode17.TeamScores[2]
                if totalScore > MuR.Mode17.MaxScore then
                    local ratio1 = MuR.Mode17.TeamScores[1] / totalScore
                    local ratio2 = MuR.Mode17.TeamScores[2] / totalScore

                    MuR.Mode17.TeamScores[1] = ratio1 * MuR.Mode17.MaxScore
                    MuR.Mode17.TeamScores[2] = ratio2 * MuR.Mode17.MaxScore
                end
            end

            MuR:SendMode17Data()

            if not MuR.Mode17.RoundEnded then
                if !MuR.Mode17.PoliceDisabled then
                    MuR.Delay_Before_Lose = CurTime() + 8
                end
                if MuR.Mode17.TeamScores[1] >= MuR.Mode17.MaxScore then
                    MuR.Mode17.RoundEnded = true
                    for _, ply in player.Iterator() do
                        if ply:Team() == 1 then
                            ply:AddMoney(250)
                        elseif ply:Team() == 2 and ply:Alive() then
                            MuR.ForceKill(ply)
                        end
                    end
                    timer.Simple(3, function()
                        if MuR.Mode17 then
                            MuR.Delay_Before_Lose = CurTime()
                        end
                    end)
                    return
                elseif MuR.Mode17.TeamScores[2] >= MuR.Mode17.MaxScore then
                    MuR.Mode17.RoundEnded = true
                    for _, ply in player.Iterator() do
                        if ply:Team() == 2 then
                            ply:AddMoney(250)
                        elseif ply:Team() == 1 and ply:Alive() then
                            MuR.ForceKill(ply)
                        end
                    end
                    timer.Simple(3, function()
                        if MuR.Mode17 then
                            MuR.Delay_Before_Lose = CurTime()
                        end
                    end)
                    return
                end
            end
        end
    end,
    OnModeEnded = function(mode)
        if SERVER and MuR.Mode17 then
            for _, pointData in pairs(MuR.Mode17.Points) do
                if IsValid(pointData.entity) then
                    if IsValid(pointData.entity.Light) then
                        pointData.entity.Light:Remove()
                    end
                    pointData.entity:Remove()
                end
            end
        end
        if CLIENT then
            hook.Remove("HUDPaint", "MuR.Mode17HUD")
            hook.Remove("PostDrawTranslucentRenderables", "Mode17DrawPoints")
            MuR.Mode17Client = nil
        end
    end
})

if SERVER then
    hook.Add("PlayerDeath", "Mode17AutoRespawn", function(victim, inflictor, attacker)
        if MuR.Gamemode == 17 and MuR.Mode17 and not MuR.Mode17.PoliceDisabled then
            timer.Simple(5, function()
                if IsValid(victim) and not victim:Alive() then
                    victim.ForceSpawn = true
                    victim:Spawn()
                    victim:ScreenFade(SCREENFADE.IN, color_black, 1, 0)
                end
            end)
        end
    end)

    function MuR:SendMode17Data()
        if MuR.Mode17 then
            net.Start("MuR.Mode17Score")
            net.WriteTable(MuR.Mode17.TeamScores)
            net.WriteInt(MuR.Mode17.MaxScore, 16)
            net.Broadcast()

            local pointsData = {}
            for i, pointData in pairs(MuR.Mode17.Points) do
                pointsData[i] = {
                    pos = pointData.pos,
                    team = pointData.team,
                    progress = pointData.progress
                }
            end

            net.Start("MuR.Mode17Points")
            net.WriteTable(pointsData)
            net.Broadcast()
        end
    end
end

if CLIENT then
    local function We(x)
        return x / 1920 * ScrW()
    end

    local function He(y)
        return y / 1080 * ScrH()
    end

    MuR.Mode17Client = MuR.Mode17Client or {TeamScores = {[1] = 0, [2] = 0}, MaxScore = 100, Points = {}}

    net.Receive("MuR.Mode17Score", function()
        local scores = net.ReadTable()
        local maxScore = net.ReadInt(16)
        MuR.Mode17Client.TeamScores = scores
        MuR.Mode17Client.MaxScore = maxScore
    end)

    net.Receive("MuR.Mode17Points", function()
        local pointsData = net.ReadTable()
        MuR.Mode17Client.Points = pointsData
    end)

    hook.Add("HUDPaint", "MuR.Mode17HUD", function()
        if MuR.GamemodeCount == 17 and MuR.DrawHUD and not MuR:GetClient("blsd_nohud") then
            local scrW, scrH = ScrW(), ScrH()
            local barWidth = We(400)
            local barHeight = He(20)
            local barX = (scrW - barWidth) / 2
            local barY = He(80)

            local team1Score = MuR.Mode17Client.TeamScores[1] or 0
            local team2Score = MuR.Mode17Client.TeamScores[2] or 0
            local maxScore = MuR.Mode17Client.MaxScore or 100

            local team1Progress = team1Score / maxScore
            local team2Progress = team2Score / maxScore

            draw.SimpleText("Ballas", "MuR_Font2", barX, barY - He(20), Color(200, 50, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Grove", "MuR_Font2", barX + barWidth, barY - He(20), Color(50, 200, 50), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            draw.RoundedBox(4, barX - 2, barY - 2, barWidth + 4, barHeight + 4, Color(0, 0, 0, 150))

            local team1Width = barWidth * team1Progress
            local team2Width = barWidth * team2Progress

            if team1Width + team2Width > barWidth then
                local totalProgress = team1Progress + team2Progress
                team1Width = barWidth * (team1Progress / totalProgress)
                team2Width = barWidth * (team2Progress / totalProgress)
            end

            if team1Width > 0 then
                draw.RoundedBox(2, barX, barY, team1Width, barHeight, Color(200, 50, 50, 200))
            end

            if team2Width > 0 then
                draw.RoundedBox(2, barX + barWidth - team2Width, barY, team2Width, barHeight, Color(50, 200, 50, 200))
            end

            draw.SimpleText(string.format("%d", team1Score), "MuR_Font3", barX - We(10), barY + barHeight/2, Color(200, 50, 50), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.format("%d", team2Score), "MuR_Font3", barX + barWidth + We(10), barY + barHeight/2, Color(50, 200, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            for i, point in pairs(MuR.Mode17Client.Points) do
                if point.pos then
                    local screenPos = point.pos:ToScreen()
                    if screenPos.visible then
                        local color = Color(255, 255, 255)
                        if point.team == 1 then
                            color = Color(200, 50, 50)
                        elseif point.team == 2 then
                            color = Color(50, 200, 50)
                        end

                        draw.SimpleText("●", "DermaLarge", screenPos.x, screenPos.y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        local progress = math.abs(point.progress or 0)
                        if progress > 0 and progress < 100 then
                            draw.SimpleText(string.format("%.0f%%", progress), "DermaDefault", screenPos.x, screenPos.y + He(15), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        end
                    end
                end
            end
        end
    end)
end
