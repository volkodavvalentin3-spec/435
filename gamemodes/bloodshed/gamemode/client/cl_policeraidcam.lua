local CameraSystem = {}
CameraSystem.Active = false
CameraSystem.StartTime = 0
CameraSystem.Duration = 15
CameraSystem.TargetPlayer = nil
CameraSystem.CameraPos = Vector()
CameraSystem.CameraAng = Angle()
CameraSystem.StartPos = Vector()
CameraSystem.StartAng = Angle()
CameraSystem.EndPos = Vector()
CameraSystem.EndAng = Angle()
CameraSystem.FOV = 75
CameraSystem.ZoomCycle = 0
CameraSystem.FadeStartTime = 0
CameraSystem.FadeDuration = 1
CameraSystem.ProjectedTexture = nil

local function IsOutdoorPosition(pos)
    local tr = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 1000),
        mask = MASK_SOLID_BRUSHONLY
    })

    return tr.HitSky
end

local tr = { collisiongroup = COLLISION_GROUP_WORLD, output = {} }
function util.IsInWorld( pos )
	tr.start = pos
	tr.endpos = pos+Vector(0, 0, 1)
	return not util.TraceLine( tr ).HitWorld
end

local function FindValidCameraPosition(targetPos)
    local attempts = 0
    local maxAttempts = 200

    while attempts < maxAttempts do
        local angle = math.random() * math.pi * 2
        local distance = math.random(400, 1000)
        local height = math.random(150, 400)

        local pos = targetPos + Vector(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
            height
        )

        if util.IsInWorld(pos) and IsOutdoorPosition(pos) then
            local hullTrace = util.TraceHull({
                start = pos,
                endpos = pos,
                mins = Vector(-32, -32, -32),
                maxs = Vector(32, 32, 32),
                mask = MASK_SOLID_BRUSHONLY
            })

            if not hullTrace.Hit then
                local groundTr = util.TraceLine({
                    start = pos,
                    endpos = pos - Vector(0, 0, 1000),
                    mask = MASK_SOLID_BRUSHONLY
                })

                if groundTr.Hit and (pos.z - groundTr.HitPos.z) > 50 then
                    return pos
                end
            end
        end

        attempts = attempts + 1
    end

    return targetPos + Vector(0, 0, 300)
end

local function GetRandomCriminal()
    local targets = {}

    for _, ply in player.Iterator() do
        if ply:Alive() then
            local class = ply:GetNW2String("Class", "")
            if ply:IsKiller() or class == "Criminal" or ply:Team() == 1 then
                table.insert(targets, ply)
            end
        end
    end

    if #targets > 0 then
        return table.Random(targets)
    end

    local alivePlayers = {}
    for _, ply in player.Iterator() do
        if ply:Alive() then
            table.insert(alivePlayers, ply)
        end
    end

    if #alivePlayers > 0 then
        return table.Random(alivePlayers)
    end

    return nil
end

local function StartCameraSystem()
    if CameraSystem.Active then return end

    local target = GetRandomCriminal()
    if not IsValid(target) then return end

    CameraSystem.Active = true
    CameraSystem.StartTime = CurTime()
    CameraSystem.TargetPlayer = target
    CameraSystem.FOV = 75
    CameraSystem.ZoomCycle = 0
    CameraSystem.FadeStartTime = CurTime()

    local targetPos = target:WorldSpaceCenter()
    local startPos = FindValidCameraPosition(targetPos)
    local endPos = FindValidCameraPosition(targetPos + Vector(math.random(-200, 200), math.random(-200, 200), 0))

    if not util.IsInWorld(startPos) then
        startPos = targetPos + Vector(0, 0, 300)
    end
    if not util.IsInWorld(endPos) then
        endPos = targetPos + Vector(0, 0, 300)
    end

    CameraSystem.StartPos = startPos
    CameraSystem.EndPos = endPos
    CameraSystem.StartAng = (targetPos - startPos):Angle()
    CameraSystem.EndAng = (targetPos - endPos):Angle()
    CameraSystem.CameraPos = startPos
    CameraSystem.CameraAng = CameraSystem.StartAng

    if IsValid(CameraSystem.ProjectedTexture) then
        CameraSystem.ProjectedTexture:Remove()
    end

    CameraSystem.ProjectedTexture = ProjectedTexture()
    CameraSystem.ProjectedTexture:SetTexture("effects/flashlight001")
    CameraSystem.ProjectedTexture:SetFOV(45)
    CameraSystem.ProjectedTexture:SetFarZ(2000)
    CameraSystem.ProjectedTexture:SetNearZ(10)
    CameraSystem.ProjectedTexture:SetColor(Color(255, 255, 255, 255))
    CameraSystem.ProjectedTexture:SetBrightness(3)
    CameraSystem.ProjectedTexture:SetPos(CameraSystem.CameraPos)
    CameraSystem.ProjectedTexture:SetAngles(CameraSystem.CameraAng)
    CameraSystem.ProjectedTexture:Update()
end

local function StopCameraSystem()
    CameraSystem.Active = false
    CameraSystem.TargetPlayer = nil

    if IsValid(CameraSystem.ProjectedTexture) then
        CameraSystem.ProjectedTexture:Remove()
        CameraSystem.ProjectedTexture = nil
    end
end

local function UpdateCamera()
    if not CameraSystem.Active then return end

    local elapsed = CurTime() - CameraSystem.StartTime
    local progress = math.Clamp(elapsed / CameraSystem.Duration, 0, 1)

    if progress >= 1 then
        StopCameraSystem()
        return
    end

    if not IsValid(CameraSystem.TargetPlayer) or not CameraSystem.TargetPlayer:Alive() then
        StopCameraSystem()
        return
    end

    local smoothProgress = math.sin(progress * math.pi * 0.5)

    local newPos = LerpVector(smoothProgress, CameraSystem.StartPos, CameraSystem.EndPos)

    local traceToNewPos = util.TraceLine({
        start = CameraSystem.CameraPos,
        endpos = newPos,
        mask = MASK_SOLID_BRUSHONLY
    })

    if traceToNewPos.Hit then
        newPos = traceToNewPos.HitPos + (CameraSystem.CameraPos - newPos):GetNormalized() * 50
    end

    CameraSystem.CameraPos = newPos

    local targetPos = CameraSystem.TargetPlayer:WorldSpaceCenter()
    CameraSystem.CameraAng = (targetPos - CameraSystem.CameraPos):Angle()

    if IsValid(CameraSystem.ProjectedTexture) then
        CameraSystem.ProjectedTexture:SetPos(CameraSystem.CameraPos)
        CameraSystem.ProjectedTexture:SetAngles(CameraSystem.CameraAng)
        CameraSystem.ProjectedTexture:Update()
    end

    CameraSystem.ZoomCycle = CameraSystem.ZoomCycle + FrameTime() * 0.3
    local baseFOV = 75
    local zoomVariation = math.sin(CameraSystem.ZoomCycle) * 10
    CameraSystem.FOV = baseFOV + zoomVariation
end

hook.Add("CalcView", "CameraSystem", function(ply, pos, angles, fov)
    if not CameraSystem.Active then return end
    if MuR.CutsceneActive then return end

    local view = {}
    view.origin = CameraSystem.CameraPos
    view.angles = CameraSystem.CameraAng
    view.fov = CameraSystem.FOV
    view.drawviewer = true

    return view
end)

hook.Add("RenderScreenspaceEffects", "CameraSystem", function()
    if not CameraSystem.Active then return end

    local fadeAlpha = 0
    local fadeElapsed = CurTime() - CameraSystem.FadeStartTime
    if fadeElapsed < CameraSystem.FadeDuration then
        fadeAlpha = 1 - (fadeElapsed / CameraSystem.FadeDuration)
    end

    if fadeAlpha > 0 then
        local tab = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -(fadeAlpha * 1),
            ["$pp_colour_contrast"] = 1,
            ["$pp_colour_colour"] = 1,
            ["$pp_colour_mulr"] = 1 - fadeAlpha,
            ["$pp_colour_mulg"] = 1 - fadeAlpha,
            ["$pp_colour_mulb"] = 1 - fadeAlpha
        }
        DrawColorModify(tab)
    end
end)

hook.Add("Think", "CameraSystem", function()
    local shouldBeActive = MuR.GamemodeCount == 13 and not LocalPlayer():Alive() and MuR.Data["PoliceState"] == 5

    if shouldBeActive and not CameraSystem.Active then
        StartCameraSystem()
    elseif not shouldBeActive and CameraSystem.Active then
        StopCameraSystem()
    end

    if CameraSystem.Active then
        UpdateCamera()
    end
end)

timer.Create("CameraSystemUpdate", 15, 0, function()
    if CameraSystem.Active and MuR.GamemodeCount == 13 and not LocalPlayer():Alive() and MuR.Data["PoliceState"] == 5 then
        CameraSystem.FadeStartTime = CurTime()
        StopCameraSystem()
        timer.Simple(0.1, function()
            StartCameraSystem()
        end)
    end
end)
