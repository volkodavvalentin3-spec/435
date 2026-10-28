local function We(x) return x * (ScrW() / 1920) end
local function He(y) return y * (ScrH() / 1080) end

local darkScreenMat = Material("bo6/da/dark.png")
local bloodAlwaysMat = Material("bo6/da/screen.png", "noclamp smooth")
local bloodShotMats = {}
for i=1,24 do bloodShotMats[#bloodShotMats+1] = Material("bo6/da/shot"..i..".png", "noclamp smooth") end
local bloodSplattersMats = {}
for i=1,50 do bloodSplattersMats[#bloodSplattersMats+1] = Material("bo6/da/splatter"..i..".png", "noclamp smooth") end
local bloodBigMat = Material("bo6/da/bigshot.png", "noclamp smooth")

local spawnedModels = {}
local deathAnimDOF = {
    active = false,
    initLength = 220,
    targetInit = 220,
    spacing = 96,
    targetSpacing = 96,
    lerpRate = 0.08,
    spacingLerp = 0.08,
    minInit = 140,
    maxInit = 420,
    minSpacing = 64,
    maxSpacing = 220,
    nearFocus = 140,
    farFocus = 640,
    fallbackInit = 220,
    fallbackSpacing = 110,
    lastInit = 0,
    lastSpacing = 0,
    updateThreshold = 0.5
}

local nzEffects = {}

local function takeThisIntoPhys(ent, name)
    local wep = ents.CreateClientProp(ent:GetModel())
    wep:SetAngles(ent:GetAngles())
    wep:SetPos(ent:GetPos())
    wep:Spawn()
    wep:GetPhysicsObject():Wake()

    spawnedModels[name] = wep
    ent:Remove()
    SafeRemoveEntityDelayed(wep, 15)

    return wep
end

function nzEffects:ApplyDamageEffect(damageLevel, duration)
    if !isnumber(duration) then
        duration = 8
    end
    local profiles = {
        [1] = {countMin = 10, countMax = 14, size = 520, motionBlur = 0.38, bloodAlwaysAlpha = 55, dripMin = 14, dripMax = 32, dripAccelMin = 6, dripAccelMax = 14, dripCap = 60, dripSpeedMul = 1.4, dripAccelMul = 1.35, dripCapMul = 1.1, scaleMin = 0.7, scaleMax = 1.1, sway = 18, decay = 0.4, fadeSpeed = 220, globalFade = 0.25, vignette = 80, colourAdd = 0.02, darken = 0.05, contrast = 0.12, desaturate = 0.06, tint = {r = 210, g = 40, b = 40}, splatterAlpha = 120, corner = false},
        [2] = {countMin = 14, countMax = 20, size = 620, motionBlur = 0.48, bloodAlwaysAlpha = 85, dripMin = 22, dripMax = 45, dripAccelMin = 12, dripAccelMax = 18, dripCap = 90, dripSpeedMul = 1.5, dripAccelMul = 1.45, dripCapMul = 1.15, scaleMin = 0.8, scaleMax = 1.2, sway = 20, decay = 0.55, fadeSpeed = 240, globalFade = 0.3, vignette = 110, colourAdd = 0.03, darken = 0.07, contrast = 0.16, desaturate = 0.08, tint = {r = 215, g = 35, b = 35}, splatterAlpha = 160, corner = false},
        [3] = {countMin = 20, countMax = 28, size = 760, motionBlur = 0.58, bloodAlwaysAlpha = 115, dripMin = 30, dripMax = 55, dripAccelMin = 16, dripAccelMax = 24, dripCap = 130, dripSpeedMul = 1.65, dripAccelMul = 1.6, dripCapMul = 1.2, scaleMin = 0.9, scaleMax = 1.35, sway = 24, decay = 0.7, fadeSpeed = 260, globalFade = 0.35, vignette = 140, colourAdd = 0.04, darken = 0.09, contrast = 0.2, desaturate = 0.12, tint = {r = 220, g = 30, b = 30}, splatterAlpha = 200, corner = false},
        [4] = {countMin = 26, countMax = 36, size = 860, motionBlur = 0.66, bloodAlwaysAlpha = 135, dripMin = 34, dripMax = 62, dripAccelMin = 20, dripAccelMax = 28, dripCap = 160, dripSpeedMul = 1.8, dripAccelMul = 1.75, dripCapMul = 1.25, scaleMin = 1, scaleMax = 1.45, sway = 28, decay = 0.85, fadeSpeed = 300, globalFade = 0.42, vignette = 165, colourAdd = 0.05, darken = 0.12, contrast = 0.24, desaturate = 0.16, tint = {r = 225, g = 25, b = 25}, splatterAlpha = 180, corner = true},
    }
    local config = profiles[damageLevel]
    if not config then return end
    local effectDuration = math.max(duration, 1.5)
    local count = math.random(config.countMin, config.countMax)
    local positions = {}
    local splatterMat = false
    local bigShot
    local splatterAlpha = config.splatterAlpha or 0
    local screenW, screenH = ScrW(), ScrH()
    if splatterAlpha > 0 then
        splatterMat = bloodSplattersMats[math.random(#bloodSplattersMats)]
    end
    local speedMul = config.dripSpeedMul or 1
    local accelMul = config.dripAccelMul or speedMul
    local capMul = config.dripCapMul or 1
    for i = 1, count do
        local dripSpeed = math.Rand(config.dripMin, config.dripMax) * speedMul
        local dripAccel = math.Rand(config.dripAccelMin, config.dripAccelMax) * accelMul
        positions[i] = {
            x = math.random(-screenW * 0.1, screenW * 1.1),
            y = math.random(-screenH * 0.15, screenH * 0.95),
            yaw = math.random(-30, 30),
            mat = bloodShotMats[math.random(#bloodShotMats)],
            scale = math.Rand(config.scaleMin, config.scaleMax),
            alpha = math.random(180, 235),
            life = effectDuration * math.Rand(0.65, 1.05),
            maxLife = effectDuration,
            speed = dripSpeed,
            accel = dripAccel,
            cap = config.dripCap * capMul,
            sway = math.Rand(-config.sway, config.sway)
        }
    end
    if damageLevel == 4 then
        bigShot = {
            x = math.random(screenW - We(720), screenW - We(460)),
            y = math.random(screenH - He(420), screenH - He(260)),
            yaw = math.random(-18, 18),
            mat = bloodBigMat,
            scale = math.Rand(0.95, 1.25),
            alpha = 255,
            life = effectDuration,
            maxLife = effectDuration,
            speed = math.Rand(config.dripMin * 0.4, config.dripMin),
            accel = math.Rand(config.dripAccelMin * 0.5, config.dripAccelMin),
            cap = config.dripCap * 0.6,
            sway = math.Rand(-config.sway * 0.3, config.sway * 0.3)
        }
    end
    hook.Remove("HUDPaint", "DamageEffect")
    hook.Remove("RenderScreenspaceEffects", "DamageBlur")
    timer.Remove("RemoveHooksDeathAnimsEffect")
    local alpha = 0
    local mainalpha = 1
    local downalpha = false
    local downmainalpha = false
    timer.Simple(effectDuration - math.min(effectDuration * 0.35, 1), function()
        downmainalpha = true
    end)
    hook.Add("HUDPaint", "DamageEffect", function()
        local frame = FrameTime()
        screenW = ScrW()
        screenH = ScrH()
        if downalpha then
            alpha = math.max(alpha - frame * config.fadeSpeed, 0)
        else
            alpha = math.min(alpha + frame * config.fadeSpeed * 3, config.bloodAlwaysAlpha)
            if alpha >= config.bloodAlwaysAlpha then
                downalpha = true
            end
        end
        if downmainalpha then
            mainalpha = math.max(mainalpha - frame * config.globalFade, 0)
        end
        surface.SetDrawColor(255, 255, 255, alpha * mainalpha)
        surface.SetMaterial(bloodAlwaysMat)
        surface.DrawTexturedRect(0, 0, screenW, screenH)
        if type(splatterMat) == "IMaterial" and splatterAlpha > 0 then
            local overlayAlpha = math.Clamp(math.floor(splatterAlpha * mainalpha), 0, 255)
            if overlayAlpha > 0 then
                surface.SetDrawColor(255, 255, 255, overlayAlpha)
                surface.SetMaterial(splatterMat)
                surface.DrawTexturedRect(0, 0, screenW, screenH)
            end
        end
        for _, pos in ipairs(positions) do
            pos.life = math.max(pos.life - frame * config.decay, 0)
            if pos.life > 0 then
                pos.y = pos.y + pos.speed * frame
                pos.x = pos.x + pos.sway * frame
                pos.speed = math.min(pos.speed + pos.accel * frame, pos.cap)
                local fade = (pos.life / pos.maxLife) * mainalpha
                if fade > 0 and pos.mat then
                    local paintMat = pos.mat
                    local matType = type(paintMat)
                    if matType ~= "IMaterial" then
                        if matType == "number" then
                            paintMat = bloodShotMats[paintMat]
                        elseif matType == "string" then
                            paintMat = Material(paintMat, "noclamp smooth")
                        else
                            paintMat = nil
                        end
                        pos.mat = paintMat
                    end
                    if paintMat then
                        surface.SetDrawColor(config.tint.r, config.tint.g, config.tint.b, pos.alpha * fade)
                        surface.SetMaterial(paintMat)
                        surface.DrawTexturedRectRotated(pos.x, pos.y, We(config.size * pos.scale), He(config.size * pos.scale), pos.yaw)
                    end
                end
            end
        end
        if bigShot then
            bigShot.life = math.max(bigShot.life - frame * config.decay, 0)
            if bigShot.life > 0 and bigShot.mat then
                bigShot.y = bigShot.y + bigShot.speed * frame
                bigShot.x = bigShot.x + bigShot.sway * frame
                bigShot.speed = math.min(bigShot.speed + bigShot.accel * frame, bigShot.cap)
                local fade = (bigShot.life / bigShot.maxLife) * mainalpha
                if fade > 0 then
                    local bigMat = bigShot.mat
                    local matType = type(bigMat)
                    if matType ~= "IMaterial" then
                        if matType == "number" then
                            bigMat = bloodShotMats[bigMat]
                        elseif matType == "string" then
                            bigMat = Material(bigMat, "noclamp smooth")
                        else
                            bigMat = nil
                        end
                        bigShot.mat = bigMat
                    end
                    if bigMat then
                        surface.SetDrawColor(255, 255, 255, bigShot.alpha * fade)
                        surface.SetMaterial(bigMat)
                        surface.DrawTexturedRectRotated(bigShot.x, bigShot.y, We(config.size * bigShot.scale), He(config.size * bigShot.scale), bigShot.yaw)
                    end
                end
            end
        end
    end)
    hook.Add("RenderScreenspaceEffects", "DamageBlur", function()
        DrawMotionBlur(0.08, config.motionBlur, 0.015)
        DrawColorModify({
            ["$pp_colour_addr"] = config.colourAdd * mainalpha,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -config.darken * mainalpha,
            ["$pp_colour_contrast"] = 1 + config.contrast * mainalpha,
            ["$pp_colour_colour"] = 1 - config.desaturate * mainalpha,
            ["$pp_colour_mulr"] = config.colourAdd * 2.5 * mainalpha,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    end)
    timer.Create("RemoveHooksDeathAnimsEffect", effectDuration, 1, function()
        hook.Remove("HUDPaint", "DamageEffect")
        hook.Remove("RenderScreenspaceEffects", "DamageBlur")
    end)
end

local function DeathAnimDOFApply(force)
    if not deathAnimDOF.active then return end

    deathAnimDOF.initLength = Lerp(deathAnimDOF.lerpRate, deathAnimDOF.initLength, deathAnimDOF.targetInit)
    deathAnimDOF.spacing = Lerp(deathAnimDOF.spacingLerp, deathAnimDOF.spacing, deathAnimDOF.targetSpacing)

    if force or math.abs(deathAnimDOF.initLength - deathAnimDOF.lastInit) > deathAnimDOF.updateThreshold then
        deathAnimDOF.lastInit = deathAnimDOF.initLength
        RunConsoleCommand("pp_dof_initlength", string.format("%.2f", deathAnimDOF.initLength))
    end

    if force or math.abs(deathAnimDOF.spacing - deathAnimDOF.lastSpacing) > deathAnimDOF.updateThreshold then
        deathAnimDOF.lastSpacing = deathAnimDOF.spacing
        RunConsoleCommand("pp_dof_spacing", string.format("%.2f", deathAnimDOF.spacing))
    end
end

local function GetModelFocusPoint(model)
    if not IsValid(model) then return nil end

    local attachmentIndex = model:LookupAttachment("eyes")
    if attachmentIndex and attachmentIndex > 0 then
        local att = model:GetAttachment(attachmentIndex)
        if att and att.Pos then return att.Pos end
    end

    local boneIndex = model:LookupBone("ValveBiped.Bip01_Head1")
    if boneIndex and boneIndex > -1 then
        local pos = model:GetBonePosition(boneIndex)
        if pos then return pos end
    end

    if model.GetBoneCount and model:GetBoneCount() > 0 then
        local pos = model:GetBonePosition(0)
        if pos then return pos end
    end

    return model:WorldSpaceCenter()
end

local function DeathAnimDOFStart()
    deathAnimDOF.active = true
    deathAnimDOF.initLength = deathAnimDOF.fallbackInit
    deathAnimDOF.targetInit = deathAnimDOF.fallbackInit
    deathAnimDOF.spacing = deathAnimDOF.fallbackSpacing
    deathAnimDOF.targetSpacing = deathAnimDOF.fallbackSpacing
    deathAnimDOF.lastInit = deathAnimDOF.fallbackInit
    deathAnimDOF.lastSpacing = deathAnimDOF.fallbackSpacing
    RunConsoleCommand("pp_dof", "1")
    DeathAnimDOFApply(true)
end

local function DeathAnimDOFStop()
    deathAnimDOF.active = false
    deathAnimDOF.targetInit = deathAnimDOF.fallbackInit
    deathAnimDOF.targetSpacing = deathAnimDOF.fallbackSpacing
    deathAnimDOF.initLength = deathAnimDOF.fallbackInit
    deathAnimDOF.spacing = deathAnimDOF.fallbackSpacing
    deathAnimDOF.lastInit = deathAnimDOF.fallbackInit
    deathAnimDOF.lastSpacing = deathAnimDOF.fallbackSpacing
    RunConsoleCommand("pp_dof_initlength", tostring(deathAnimDOF.fallbackInit))
    RunConsoleCommand("pp_dof_spacing", tostring(deathAnimDOF.fallbackSpacing))
    RunConsoleCommand("pp_dof", "0")
end

local isSceneActive = false

local function CreateTimedScene(modelsTable, effectsTable, sceneDuration, onFinish, customFov)
    RunConsoleCommand("cl_drawhud", "0")
    RunConsoleCommand("pp_dof", "0")
    local modelAnimations = {}
    isSceneActive = true
    local sceneFov = customFov or 75
    DeathAnimDOFStart()

    for _, modelData in ipairs(modelsTable) do
        local model = ClientsideModel(modelData.model, RENDERGROUP_OPAQUE)
        if IsValid(model) then
            model:SetPos(modelData.position or Vector(0, 0, 0))
            model:SetAngles(modelData.angle or Angle(0, 0, 0))

            local sequence = model:LookupSequence(modelData.animation or "idle")
            model:ResetSequence(sequence)

            local animDuration = model:SequenceDuration(sequence)
            local startCycle = modelData.cycle or 0
            model:SetCycle(startCycle)

            if modelData.name then
                spawnedModels[modelData.name] = model
            else
                table.insert(spawnedModels, model)
            end
            table.insert(modelAnimations, {
                model = model,
                duration = animDuration,
                startTime = CurTime(),
                cycle = startCycle
            })
        end
    end

    local prevPos = nil
    local smoothFov = 90
    local smoothAng = Angle(0, 0, 0)
    local shake = Angle(0, 0, 0)
    local fovMin = 50
    local fovMax = 80
    local fovChangeSpeed = 0.2
    local angChangeSpeed = 0.1
    local shakeDecay = 0.2
    local camEffectScale = 1
    local tiltMax = 12 * camEffectScale
    local pitchMax = 8 * camEffectScale
    local shakeMax = 2 * camEffectScale
    local fovDynamic = 10 * camEffectScale

    hook.Add("CalcView", "TimedSceneCameraView", function(player, origin, angles, fov)
        local view = {}
        local cfov = sceneFov
        local ent = spawnedModels["player"]
        //do return end

        if IsValid(ent) then
            local att = ent:GetAttachment(ent:LookupAttachment("eyes"))
            local an = ent:GetSequenceName(ent:GetSequence())

            if prevPos then
                local vel = att.Pos - prevPos
                local speed = vel:Length()
                local delta = math.Clamp(speed * 2, 0, 1)

                local targetFov = Lerp(delta, cfov, math.Clamp(cfov - fovDynamic, fovMin, fovMax))
                smoothFov = Lerp(fovChangeSpeed, smoothFov, targetFov)

                local roll = math.Clamp(vel.y * 0.5 * camEffectScale, -tiltMax, tiltMax)
                local pitch = math.Clamp(-vel.z * 0.5 * camEffectScale, -pitchMax, pitchMax)
                local targetAng = att.Ang + Angle(pitch, 0, roll)

                if speed > 0.2 then
                    local delta = math.Clamp(speed / 4, 0, 1)
                    shake = shake + Angle(
                        math.Rand(-shakeMax, shakeMax) * delta,
                        math.Rand(-shakeMax, shakeMax) * delta,
                        math.Rand(-shakeMax, shakeMax) * delta
                    )
                end
                shake = LerpAngle(shakeDecay, shake, Angle(0, 0, 0))

                smoothAng = LerpAngle(angChangeSpeed, smoothAng, targetAng) + shake
            else
                smoothFov = cfov
                smoothAng = att.Ang
            end
            prevPos = att.Pos

            local camForwardOffset = 0
            if isvector(origin) and istable(att) and isnumber(speed) and (att.Ang:Forward():Dot((att.Pos - origin):GetNormalized()) > 0.9) and speed > 2 then
                camForwardOffset = math.Clamp(speed * 1.5 * camEffectScale, 0, 10 * camEffectScale)
            end

            view.origin = att.Pos + att.Ang:Forward() * camForwardOffset
            view.angles = smoothAng
            view.fov = smoothFov
            view.znear = 1
            player:SetEyeAngles(Angle(smoothAng.x, smoothAng.y, 0))

            local focusPos
            local priorityKeys = {
                "zombie",
                "zombie2",
                "zombie3"
            }

            for _, key in ipairs(priorityKeys) do
                focusPos = GetModelFocusPoint(spawnedModels[key])
                if focusPos then break end
            end

            if not focusPos then
                focusPos = GetModelFocusPoint(ent)
            end

            if focusPos then
                local dist = view.origin:Distance(focusPos)
                local normalized = math.Clamp((dist - deathAnimDOF.nearFocus) / (deathAnimDOF.farFocus - deathAnimDOF.nearFocus), 0, 1)
                local initTarget = Lerp(normalized, deathAnimDOF.minInit, deathAnimDOF.maxInit)
                local spacingTarget = Lerp(1 - normalized, deathAnimDOF.maxSpacing, deathAnimDOF.minSpacing)

                deathAnimDOF.targetInit = math.Clamp(initTarget, deathAnimDOF.minInit, deathAnimDOF.maxInit)
                deathAnimDOF.targetSpacing = math.Clamp(spacingTarget, deathAnimDOF.minSpacing, deathAnimDOF.maxSpacing)
            else
                deathAnimDOF.targetInit = deathAnimDOF.fallbackInit
                deathAnimDOF.targetSpacing = deathAnimDOF.fallbackSpacing
            end

            DeathAnimDOFApply()
            local bool = render.GetLightColor(att.Pos):Length() < 0.005
            if bool then
                local dlight = DynamicLight(LocalPlayer():EntIndex())
                if dlight then
                    dlight.pos = att.Pos
                    dlight.r = 220
                    dlight.g = 40
                    dlight.b = 40
                    dlight.brightness = 0.1
                    dlight.decay = 1000
                    dlight.size = 256
                    dlight.dietime = CurTime() + 1
                end
            end

            return view
        end
    end)

    hook.Add("Think", "TimedSceneAnimationUpdate", function()
        for _, animData in ipairs(modelAnimations) do
            local model = animData.model
            if IsValid(model) then
                local timeElapsed = (CurTime() - animData.startTime) % animData.duration
                local cycle = (timeElapsed / animData.duration) + animData.cycle
                model:SetCycle(cycle % 1)
            end
        end
    end)

    for delay, type in pairs(effectsTable) do
        timer.Simple(delay, function()
            local ent = spawnedModels["player"]
            local zent = spawnedModels["zombie"]
            if IsValid(ent) then
                if type == "sound" then
                    local anim = zent:GetSequenceName(zent:GetSequence())
                    if anim == "death_zombie_solo_1" then
                        LocalPlayer():EmitSound("bo6/da/solo/solo_1.mp3")
                    elseif anim == "death_zombie_solo_2" then
                        LocalPlayer():EmitSound("bo6/da/solo/solo_2.mp3")
                    elseif anim == "death_zombie_solo_3" then
                        LocalPlayer():EmitSound("bo6/da/solo/solo_3.mp3")
                    elseif anim == "death_zombie_solo_4" then
                        LocalPlayer():EmitSound("bo6/da/solo/solo_4.mp3")
                    elseif anim == "death_zombie_duo_11" then
                        LocalPlayer():EmitSound("bo6/da/duo/duo_1.mp3")
                    elseif anim == "death_zombie_duo_21" then
                        LocalPlayer():EmitSound("bo6/da/duo/duo_2.mp3")
                    elseif anim == "death_zombie_duo_31" then
                        LocalPlayer():EmitSound("bo6/da/duo/duo_3.mp3")
                    elseif anim == "death_zombie_duo_41" then
                        LocalPlayer():EmitSound("bo6/da/duo/duo_4.mp3")
                    elseif anim == "death_zombie_duo_51" then
                        LocalPlayer():EmitSound("bo6/da/duo/duo_5.mp3")
                    elseif anim == "mwz_da_zombie_mangler_t10" then
                        LocalPlayer():EmitSound("bo6/da/other/mangler.mp3")
                    elseif anim == "mwz_da_zombie_vermin_1" then
                        LocalPlayer():EmitSound("bo6/da/other/vermin1.mp3")
                    elseif anim == "mwz_da_zombie_vermin_21" then
                        LocalPlayer():EmitSound("bo6/da/other/vermin2.mp3")
                    elseif anim == "mwz_da_zombie_amalgam" then
                        LocalPlayer():EmitSound("bo6/da/other/amalgam.mp3")
                    elseif anim == "mwz_da_zombie_mimic" then
                        LocalPlayer():EmitSound("bo6/da/other/mimic.mp3")
                    end
                elseif type == "pistol_solo_1" then
                    local prop = ClientsideModel("models/sidearms/w_1911.mdl")
                    prop:SetPos(ent:GetPos()-ent:GetRight()*16+ent:GetForward()*36+Vector(0,0,2))
                    prop:SetAngles(ent:GetAngles()+Angle(0,math.random(0,360),90))
                    SafeRemoveEntityDelayed(prop, 5)
                elseif type == "new_rhand" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 8)
                    timer.Simple(2, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 8)
                    end)
                    nzEffects:ApplyDamageEffect(1)
                elseif type == "new_neck_bite" then
                    for i=1,30 do
                        timer.Simple(i/10, function()
                            if !IsValid(ent) then return end
                            ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 4)
                        end)
                    end
                    nzEffects:ApplyDamageEffect(3)
                elseif type == "new_rfoot" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 5)
                    timer.Simple(1, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 5)
                    end)
                    nzEffects:ApplyDamageEffect(1)
                elseif type == "new_lhand" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 12)
                    timer.Simple(1, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 12)
                    end)
                    nzEffects:ApplyDamageEffect(1)
                elseif type == "amalgam_totalgib" then
                    for i=1,10 do
                        ParticleEffectAttach("vomit_barnacle", PATTACH_POINT_FOLLOW, zent, 10)
                    end
                    timer.Simple(1.55, function()
                        if !IsValid(ent) then return end
                        LocalPlayer():EmitSound("murdered/gore/kf2_totalgib2.wav")
                        nzEffects:ApplyDamageEffect(4)
                    end)
                elseif type == "new_rforearm" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 7)
                    timer.Simple(2, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 7)
                    end)
                    nzEffects:ApplyDamageEffect(1)
                elseif type == "new_rforearm_gib" then
                    for i=1,30 do
                        timer.Simple(i/10, function()
                            if !IsValid(ent) then return end
                            local att = ent:GetAttachment(4)
                            local pos = att.Pos
                            local e = EffectData()
                            e:SetOrigin(pos)
                            e:SetFlags(0)
                            util.Effect("mur_da_pool", e)
                            ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 6)
                        end)
                    end
                    nzEffects:ApplyDamageEffect(3)
                    ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 5)
                elseif type == "slash_spine_blood" then
                    for i=1,25 do
                        timer.Simple(i/5, function()
                            if !IsValid(ent) then return end
                            ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 6)
                            if i % 5 == 0 then
                                ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 8)
                            end
                            if i > 10 then
                                ParticleEffectAttach("blood_impact_red_01_droplets", PATTACH_POINT_FOLLOW, ent, 2)
                            end
                        end)
                    end
                    LocalPlayer():EmitSound("murdered/gore/flesh_squishy_impact_hard1.wav")
                    surface.PlaySound("murdered/player/deathmale/bullet/death_bullet65.ogg")
                    nzEffects:ApplyDamageEffect(4)
                elseif type == "fear" then
                    surface.PlaySound("murdered/player/deathmale/bullet/death_bullet25.ogg")
                elseif type == "mangler_ready" then
                    for i = 1, 15 do
                        ParticleEffectAttach("vj_rifle_smoke_dark", PATTACH_POINT_FOLLOW, zent, 13)
                    end
                    LocalPlayer():EmitSound("bo6/npc/mangler/charge.mp3")
                elseif type == "mangler_shot" then
                    for i = 1, 15 do
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, zent, 13)
                    end
                    nzEffects:ApplyDamageEffect(4)
                    LocalPlayer():EmitSound("murdered/gore/kf2_tear10.wav")
                elseif type == "pistol_in_hand" then
                    local model = "models/sidearms/w_1911.mdl"
                    local lpos = Vector(3,1,1)
                    local wep = ents.CreateClientside("base_anim")
                    local attach = ent:GetAttachment(ent:LookupAttachment("anim_attachment_RH"))
                    if attach then
                        wep:SetModel(model)
                        wep:Spawn()
                        wep:SetModelScale(0.9)
                        wep:SetPos(Vector(0,0,-9999))
                        wep:SetAngles(attach.Ang)
                        wep:SetParent(ent, ent:LookupAttachment("anim_attachment_RH"))
                        wep:SetLocalAngles(Angle(0,20,0))
                        wep:SetLocalPos(lpos)
                        spawnedModels["pistol"] = wep
                    else
                        wep:Remove()
                    end
                elseif type == "pistol_muzzle" then
                    local pistol = spawnedModels["pistol"]
                    if IsValid(pistol) then
                        ParticleEffectAttach("vj_rifle_full", PATTACH_POINT_FOLLOW, pistol, 1)
                        LocalPlayer():EmitSound("tfa_ins2_wpns/tfa_ins2_m1911colt/fire.wav", 75, math.random(95, 105))
                    end
                elseif type == "pistol_vermin_throw" then
                    local p = spawnedModels["pistol"]
                    if IsValid(p) then
                        local ent = spawnedModels["player"]
                        local wep = takeThisIntoPhys(p, "pistol")
                        if IsValid(wep) then
                            local phys = wep:GetPhysicsObject()
                            if IsValid(phys) then
                                phys:SetVelocity(ent:GetForward()*-256+ent:GetRight()*256)
                                phys:SetAngleVelocity(ent:GetRight()*1000+ent:GetForward()*-400)
                            end
                            timer.Simple(0.12, function()
                                if !IsValid(phys) then return end
                                phys:SetVelocity(ent:GetForward()*32+Vector(0,0,160))
                                phys:SetAngleVelocity(ent:GetRight()*-800)
                            end)
                        end
                    end
                elseif type == "pistol_vermin_1" then
                    local prop = ClientsideModel("models/sidearms/w_1911.mdl")
                    prop:SetPos(ent:GetPos()-ent:GetRight()*140+ent:GetForward()*10+Vector(0,0,0.5))
                    prop:SetAngles(ent:GetAngles()+Angle(0,math.random(0,360),90))
                    SafeRemoveEntityDelayed(prop, 5)
                elseif type == "new_rhand2" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 7)
                    timer.Simple(0.5, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 7)
                        if !IsValid(zent) then return end
                        for i=1,5 do
                            ParticleEffectAttach("vomit_barnacle", PATTACH_POINT_FOLLOW, zent, 2)
                        end
                    end)
                    nzEffects:ApplyDamageEffect(3)
                elseif type == "new_spine4" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 2)
                    nzEffects:ApplyDamageEffect(2)
                elseif type == "amalgam_hands" then
                    ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 11)
                    nzEffects:ApplyDamageEffect(2)
                    LocalPlayer():EmitSound("murdered/gore/bonebreak"..math.random(1,6)..".mp3")
                    timer.Simple(1.05, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 10)
                        LocalPlayer():EmitSound("murdered/gore/bonebreak"..math.random(1,6)..".mp3")
                        nzEffects:ApplyDamageEffect(3)
                    end)
                elseif type == "mimic_spine4" then
                    timer.Simple(0.1, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 2)
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, zent, 9)
                        nzEffects:ApplyDamageEffect(3)
                        LocalPlayer():EmitSound("murdered/gore/kf2_tear15.wav")
                    end)
                    timer.Simple(1.3, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 2)
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, zent, 9)
                        nzEffects:ApplyDamageEffect(2)
                        LocalPlayer():EmitSound("murdered/gore/kf2_tear2.wav")
                    end)
                    timer.Simple(2, function()
                        if !IsValid(ent) then return end
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 2)
                        ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, zent, 9)
                        nzEffects:ApplyDamageEffect(2)
                        LocalPlayer():EmitSound("murdered/gore/kf2_tear4.wav")
                    end)
                    timer.Simple(2.8, function()
                        if !IsValid(ent) then return end
                        for i=1,25 do
                            timer.Simple(i/5, function()
                                if !IsValid(zent) then return end
                                ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, zent, 9)
                                ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, zent, 9)
                            end)
                            timer.Simple(i/5, function()
                                if !IsValid(ent) then return end
                                ParticleEffectAttach("vj_blood_impact_red", PATTACH_POINT_FOLLOW, ent, 5)
                                ParticleEffectAttach("blood_advisor_pierce_spray", PATTACH_POINT_FOLLOW, ent, 5)
                            end)
                        end
                        LocalPlayer():EmitSound("murdered/gore/kf2_totalgib3.wav")
                        nzEffects:ApplyDamageEffect(4)

                        local guts = ClientsideRagdoll("models/gore/fatalityguts.mdl")
                        guts:SetModelScale(1.5, 0.0001)
                        guts.NoHideDA = true
                        guts:SetNoDraw(false)
                        guts:DrawShadow(true)
                        if IsValid(guts) then
                            local att = zent:GetAttachment(9)
                            if att then
                                for i = 0, guts:GetPhysicsObjectCount() - 1 do
                                    local phys = guts:GetPhysicsObjectNum(i)
                                    phys:SetPos(att.Pos)
                                end
                            end
                            table.insert(spawnedModels, guts)
                            hook.Add("Think", "MimicGutsFollow"..guts:EntIndex(), function()
                                if !IsValid(zent) then
                                    if IsValid(guts) then guts:Remove() end
                                    hook.Remove("Think", "MimicGutsFollow"..guts:EntIndex())
                                    return
                                end
                                if !IsValid(guts) then
                                    hook.Remove("Think", "MimicGutsFollow"..guts:EntIndex())
                                    return
                                end
                                local att = zent:GetAttachment(9)
                                if att then
                                    local phys = guts:GetPhysicsObjectNum(12)
                                    if IsValid(phys) then
                                        phys:SetPos(att.Pos)
                                    end
                                end
                            end)
                        end
                    end)
                end
            end
        end)
    end

    hook.Add("HUDPaint", "TimedSceneCameraHUD", function()
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(darkScreenMat)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    end)

    timer.Simple(sceneDuration, function()
        isSceneActive = false
        DeathAnimDOFStop()
        for _, model in pairs(spawnedModels) do
            if IsValid(model) then
                model:Remove()
            end
        end

        hook.Remove("HUDPaint", "TimedSceneCameraHUD")
        hook.Remove("CalcView", "TimedSceneCameraView")
        hook.Remove("Think", "TimedSceneAnimationUpdate")
        game.GetWorld():RemoveAllDecals()

        if onFinish and type(onFinish) == "function" then
            onFinish()
        end
    end)
end

local DeathAnimations = {
    ["Zombies"] = {
        ["death_%s_solo_1"] = {time = 5.43, yaw = 270, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0] = "pistol_solo_1", [0.2] = "sound", [2.8] = "new_rhand"}},
        ["death_%s_solo_2"] = {time = 4.76, yaw = 270, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.4] = "sound", [4.4] = "new_neck_bite"}},
        ["death_%s_solo_3"] = {time = 4.16, yaw = 270, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.1] = "sound", [3.4] = "new_neck_bite"}},
        ["death_%s_solo_4"] = {time = 5.63, yaw = 0, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.1] = "sound", [1.4] = "new_rfoot", [2.2] = "new_lhand", [3.2] = "new_neck_bite"}},
        ["death_%s_duo_1"] = {time = 4.8, yaw = 0, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.1] = "sound", [3.6] = "new_neck_bite"}},
        ["death_%s_duo_2"] = {time = 4.73, yaw = 0, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.1] = "sound"}},
        ["death_%s_duo_3"] = {time = 8.8, yaw = 0, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.7] = "sound", [7.9] = "new_neck_bite"}},
        ["death_%s_duo_4"] = {time = 5.86, yaw = 270, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.1] = "sound", [0.4] = "new_rforearm", [3.8] = "new_rforearm_gib"}},
        ["death_%s_duo_5"] = {time = 9, yaw = 270, model = "models/murdered/nz/da/zombie_anims.mdl", eff = {[0.1] = "sound", [1.7] = "new_rforearm", [5.4] = "new_rforearm_gib"}},
    },
    ["Mangler"] = {
        ["mwz_da_%s_mangler_t10"] = {time = 7.6, fov = 55, yaw = 270, model = "models/murdered/nz/bo6_mangler.mdl", zmodel = "models/murdered/nz/bo6_mangler.mdl", eff = {[0.01] = "sound", [1] = "fear", [2.1] = "slash_spine_blood", [6.1] = "mangler_ready", [7.3] = "mangler_shot"}},
    },
    ["Vermin"] = {
        ["mwz_da_%s_vermin_1"] = {time = 4.7, fov = 45, yaw = 270, model = "models/murdered/nz/bo6_vermin.mdl", zmodel = "models/murdered/nz/bo6_vermin.mdl", eff = {[0.01] = "sound", [0.02] = "pistol_vermin_1", [2.4] = "new_rhand2"}},
        ["mwz_da_%s_vermin_2"] = {time = 5.83, fov = 45, yaw = 180, model = "models/murdered/nz/bo6_vermin.mdl", zmodel = "models/murdered/nz/bo6_vermin.mdl", eff = {[0.01] = "sound", [0.02] = "pistol_in_hand", [0.7] = "pistol_muzzle", [1.3] = "pistol_muzzle", [2.1] = "pistol_muzzle", [3.36] = "pistol_vermin_throw", [4.73] = "new_spine4", [4.95] = "new_spine4"}},
    },
    ["Amalgam"] = {
        ["mwz_da_%s_amalgam"] = {time = 9.6, fov = 55, yaw = 180, model = "models/murdered/nz/bo6_amalgam.mdl", zmodel = "models/murdered/nz/bo6_amalgam.mdl", eff = {[0.01] = "sound", [5.6] = "amalgam_hands", [8] = "amalgam_totalgib"}},
    },
    ["Mimic"] = {
        ["mwz_da_%s_mimic"] = {time = 10, fov = 75, yaw = 90, model = "models/murdered/nz/bo6_mimic.mdl", zmodel = "models/murdered/nz/bo6_mimic.mdl", eff = {[0.01] = "sound", [3.9] = "mimic_spine4"}},
    },
}

local function StartDeathAnimation(pos, ang, npcClass)
    local animType = MuR.DeathAnimClasses[npcClass] or "Zombies"
    local animTable = DeathAnimations[animType]

    if not animTable then
        animTable = DeathAnimations["Zombies"]
        animType = "Zombies"
    end

    local animKeys = {}
    for k, v in pairs(animTable) do
        table.insert(animKeys, k)
    end
    local anim = animKeys[math.random(#animKeys)]
    local data = animTable[anim]

    local zanimmodel = data.model or "models/murdered/nz/da/zombie_anims.mdl"
    local panimmodel = "models/murdered/nz/da/human_anims.mdl"
    if animType != "Zombies" then
        panimmodel = "models/murdered/nz/da/da_anims_human.mdl"
    end

    local zombieModels = data.zmodel and {data.zmodel} or {
        "models/murdered/nz/da/zed4.mdl",
        "models/murdered/nz/da/zed6.mdl",
        "models/murdered/nz/da/zed8.mdl"
    }

    local main_pos = pos
    local main_ang = ang or Angle(0,math.random(0,360),0)

    if !isvector(main_pos) then return end

    local add1 = ""
    main_ang = main_ang + Angle(0, data.yaw or 0, 0)

    local atab = {
        {name = "player", model = panimmodel, position = main_pos, angle = main_ang, animation = string.format(anim, "human")},
    }

    if string.match(anim, "_duo") or string.match(anim, "vermin_2") then
        add1 = "1"
        table.insert(atab, {name = "zombie2", model = zanimmodel, position = main_pos, angle = main_ang, animation = string.format(anim, "zombie").."2"})
    end

    if animType == "Mimic" then
        local mimicZombieAnimModel = "models/murdered/nz/da/zombie_anims.mdl"
        table.insert(atab, {name = "zombie_mimic1", model = mimicZombieAnimModel, position = main_pos, angle = main_ang, animation = "death_zombie_mimic_1"})
        table.insert(atab, {name = "zombie_mimic2", model = mimicZombieAnimModel, position = main_pos, angle = main_ang, animation = "death_zombie_mimic_2"})
        table.insert(atab, {name = "zombie_mimic3", model = mimicZombieAnimModel, position = main_pos, angle = main_ang, animation = "death_zombie_mimic_3"})
    end

    table.insert(atab, {name = "zombie", model = zanimmodel, position = main_pos, angle = main_ang, animation = string.format(anim, "zombie")..add1})

    MuR.CutsceneActive = true
    CreateTimedScene(
        atab,
        data.eff,
        data.time,
        function()
            print("Scene finished!")
        end,
        data.fov
    )

    timer.Simple(0.01, function()
        surface.PlaySound("bo6/da/start.mp3")
        local ent = spawnedModels["player"]
        if IsValid(ent) then
            ent:SetNoDraw(true)
            local model = ClientsideModel(LocalPlayer():GetModel())
            model:SetPos(ent:GetPos())
            model:AddEffects(1)
            model:SetParent(ent)
            model:SetSkin(LocalPlayer():GetSkin())
            for i = 0, LocalPlayer():GetNumBodyGroups() - 1 do
                model:SetBodygroup(i, LocalPlayer():GetBodygroup(i))
            end
            model:ManipulateBoneScale(model:LookupBone("ValveBiped.Bip01_Head1"), Vector(0,0,0))
            table.insert(spawnedModels, model)
        end

        local ent = spawnedModels["zombie"]
        if IsValid(ent) then
            ent:SetNoDraw(true)
            local zModelPath = zombieModels[math.random(#zombieModels)]
            local model = ClientsideModel(zModelPath)
            model:SetPos(ent:GetPos())
            model:AddEffects(1)
            model:SetParent(ent)
            model:SetSkin(math.random(0, 21))
            table.insert(spawnedModels, model)
        end

        local ent = spawnedModels["zombie2"]
        if IsValid(ent) then
            ent:SetNoDraw(true)
            local zModelPath = zombieModels[math.random(#zombieModels)]
            local model = ClientsideModel(zModelPath)
            model:SetPos(ent:GetPos())
            model:AddEffects(1)
            model:SetParent(ent)
            model:SetSkin(math.random(0, 21))
            table.insert(spawnedModels, model)
        end

        local mimicZombieModels = {
            "models/murdered/nz/da/zed4.mdl",
            "models/murdered/nz/da/zed6.mdl",
            "models/murdered/nz/da/zed8.mdl"
        }
        for i=1,3 do
            local ent = spawnedModels["zombie_mimic"..i]
            if IsValid(ent) then
                ent:SetNoDraw(true)
                local zModelPath = mimicZombieModels[math.random(#mimicZombieModels)]
                local model = ClientsideModel(zModelPath)
                model:SetPos(ent:GetPos())
                model:AddEffects(1)
                model:SetParent(ent)
                model:SetSkin(math.random(0, 21))
                table.insert(spawnedModels, model)
            end
        end
    end)

    timer.Simple(data.time-0.1, function()
        LocalPlayer():ScreenFade(SCREENFADE.OUT, color_black, 0.05, 5)
        surface.PlaySound("bo6/da/death.mp3")
        nzEffects:ApplyDamageEffect(1, 0)
    end)

    timer.Simple(data.time+5, function()
        RunConsoleCommand("cl_drawhud", "1")
        MuR.CutsceneActive = false
    end)
end

local function FindSafeDeathAnimationPos(pos)
    local checkHeight = 48
    local playerHeight = 72
    local minClearance = 120
    local minSideClearance = 100
    local minBackClearance = 90
    local maxScanDist = 768
    local gridSize = 48
    local hullMins = Vector(-20, -20, 0)
    local hullMaxs = Vector(20, 20, 72)
    local hullMinsWide = Vector(-40, -40, 0)
    local hullMaxsWide = Vector(40, 40, 72)

    local function ShouldIgnoreEntity(ent)
        if not IsValid(ent) then return true end
        if ent:IsPlayer() then return true end
        if MuR.IsAI(ent) then return true end
        local class = ent:GetClass()
        if class == "prop_ragdoll" or class == "class C_ClientRagdoll" then return true end
        if string.find(class, "ragdoll") then return true end
        return false
    end

    local function TraceOpen(from, dir, dist)
        local tr = util.TraceLine({
            start = from,
            endpos = from + dir * dist,
            mask = MASK_SOLID,
            filter = ShouldIgnoreEntity
        })
        return tr.Fraction * dist
    end

    local function TraceHullOpen(from, dir, dist, mins, maxs)
        mins = mins or hullMins
        maxs = maxs or hullMaxs
        local tr = util.TraceHull({
            start = from,
            endpos = from + dir * dist,
            mins = mins,
            maxs = maxs,
            mask = MASK_SOLID,
            filter = ShouldIgnoreEntity
        })
        return tr.Fraction * dist, tr.Hit, tr.HitPos
    end

    local function CheckPositionClear(testPos)
        local tr = util.TraceHull({
            start = testPos + Vector(0, 0, 4),
            endpos = testPos + Vector(0, 0, 8),
            mins = hullMins,
            maxs = hullMaxs,
            mask = MASK_SOLID,
            filter = ShouldIgnoreEntity
        })
        return not tr.StartSolid and not tr.AllSolid
    end

    local function CheckPositionClearWide(testPos)
        local tr = util.TraceHull({
            start = testPos + Vector(0, 0, 4),
            endpos = testPos + Vector(0, 0, 8),
            mins = hullMinsWide,
            maxs = hullMaxsWide,
            mask = MASK_SOLID,
            filter = ShouldIgnoreEntity
        })
        return not tr.StartSolid and not tr.AllSolid
    end

    local function CheckCeiling(testPos)
        local tr = util.TraceHull({
            start = testPos,
            endpos = testPos + Vector(0, 0, playerHeight + 32),
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 0),
            mask = MASK_SOLID,
            filter = ShouldIgnoreEntity
        })
        return tr.Fraction * (playerHeight + 32)
    end

    local function CheckFloor(testPos)
        local tr = util.TraceHull({
            start = testPos + Vector(0, 0, 24),
            endpos = testPos - Vector(0, 0, 500),
            mins = Vector(-8, -8, 0),
            maxs = Vector(8, 8, 0),
            mask = MASK_SOLID,
            filter = ShouldIgnoreEntity
        })
        if tr.Hit and not tr.StartSolid then
            return tr.HitPos, tr.HitNormal
        end
        return nil, nil
    end

    local function EvaluatePosition(testPos, testAng)
        local score = 0
        local forward = testAng:Forward()
        local right = testAng:Right()
        local center = testPos + Vector(0, 0, checkHeight)

        if not CheckPositionClear(testPos) then
            return -10000
        end

        if CheckPositionClearWide(testPos) then
            score = score + 500
        end

        local frontDistLine = TraceOpen(center, forward, maxScanDist)
        local frontDistHull = TraceHullOpen(center, forward, maxScanDist * 0.7, Vector(-14, -14, -14), Vector(14, 14, 14))
        local frontDist = math.min(frontDistLine, frontDistHull * 1.4)
        score = score + frontDist * 3.0

        local frontLeftDist = TraceHullOpen(center, (forward + right * -0.5):GetNormalized(), maxScanDist * 0.6, Vector(-10, -10, -10), Vector(10, 10, 10))
        local frontRightDist = TraceHullOpen(center, (forward + right * 0.5):GetNormalized(), maxScanDist * 0.6, Vector(-10, -10, -10), Vector(10, 10, 10))
        score = score + (frontLeftDist + frontRightDist) * 1.5

        local leftDist = TraceHullOpen(center, -right, maxScanDist * 0.5, Vector(-10, -10, -10), Vector(10, 10, 10))
        local rightDist = TraceHullOpen(center, right, maxScanDist * 0.5, Vector(-10, -10, -10), Vector(10, 10, 10))
        local sideBalance = math.min(leftDist, rightDist)
        score = score + sideBalance * 2.0
        score = score - math.abs(leftDist - rightDist) * 0.5

        if leftDist < minSideClearance then
            score = score - (minSideClearance - leftDist) * 2.5
        end
        if rightDist < minSideClearance then
            score = score - (minSideClearance - rightDist) * 2.5
        end

        local backDist = TraceHullOpen(center, -forward, maxScanDist * 0.4, Vector(-12, -12, -12), Vector(12, 12, 12))
        score = score + backDist * 1.5
        if backDist < minBackClearance then
            score = score - (minBackClearance - backDist) * 3.5
        end

        local ceilingClear = CheckCeiling(testPos)
        if ceilingClear < playerHeight then
            score = score - 2000
        end

        local floorPos, floorNormal = CheckFloor(testPos)
        if not floorPos then
            score = score - 3000
        else
            local slopeDot = floorNormal:Dot(Vector(0, 0, 1))
            if slopeDot < 0.7 then
                score = score - (1 - slopeDot) * 800
            end
        end

        local blockedDirs = 0
        for i = 0, 11 do
            local rad = math.rad(i * 30)
            local dir = Vector(math.cos(rad), math.sin(rad), 0)
            local dist = TraceHullOpen(center, dir, minClearance, Vector(-8, -8, -8), Vector(8, 8, 8))
            if dist < minClearance * 0.5 then
                blockedDirs = blockedDirs + 1
            end
        end
        if blockedDirs >= 4 then
            score = score - blockedDirs * 200
        end

        local heights = {8, 36, 64}
        for _, h in ipairs(heights) do
            local checkPos = testPos + Vector(0, 0, h)
            local frontClear = TraceHullOpen(checkPos, forward, 250, Vector(-12, -12, -12), Vector(12, 12, 12))
            if frontClear < 120 then
                score = score - (120 - frontClear) * 1.2
            end

            local sideClearL = TraceHullOpen(checkPos, -right, 150, Vector(-8, -8, -8), Vector(8, 8, 8))
            local sideClearR = TraceHullOpen(checkPos, right, 150, Vector(-8, -8, -8), Vector(8, 8, 8))
            if sideClearL < 70 then
                score = score - (70 - sideClearL) * 0.8
            end
            if sideClearR < 70 then
                score = score - (70 - sideClearR) * 0.8
            end
        end

        local diagonals = {
            {dir = (forward + right):GetNormalized(), weight = 1.2},
            {dir = (forward - right):GetNormalized(), weight = 1.2},
            {dir = (-forward + right):GetNormalized(), weight = 1.0},
            {dir = (-forward - right):GetNormalized(), weight = 1.0}
        }
        for _, diag in ipairs(diagonals) do
            local diagDist = TraceHullOpen(center, diag.dir, 140, Vector(-10, -10, -10), Vector(10, 10, 10))
            if diagDist < 70 then
                score = score - (70 - diagDist) * diag.weight
            end
        end

        return score
    end

    local function FindBestAngle(testPos)
        local bestAng = Angle(0, 0, 0)
        local bestScore = -math.huge

        for yaw = 0, 350, 15 do
            local testAng = Angle(0, yaw, 0)
            local score = EvaluatePosition(testPos, testAng)
            if score > bestScore then
                bestScore = score
                bestAng = testAng
            end
        end

        for yaw = bestAng.y - 12, bestAng.y + 12, 4 do
            local testAng = Angle(0, yaw, 0)
            local score = EvaluatePosition(testPos, testAng)
            if score > bestScore then
                bestScore = score
                bestAng = testAng
            end
        end

        return bestAng, bestScore
    end

    local function FindNearestClearSpot(startPos)
        if CheckPositionClear(startPos) then
            return startPos
        end

        for dist = 16, 128, 16 do
            for i = 0, 15 do
                local rad = math.rad(i * 22.5)
                local offset = Vector(math.cos(rad) * dist, math.sin(rad) * dist, 0)
                local testPos = startPos + offset
                local floorPos, _ = CheckFloor(testPos)
                if floorPos and CheckPositionClear(floorPos) then
                    return floorPos
                end
            end
        end

        return startPos
    end

    local floorPos, _ = CheckFloor(pos)
    if floorPos then
        pos = floorPos
    end

    pos = FindNearestClearSpot(pos)

    local candidates = {{pos = pos, priority = 1}}

    for ring = 1, 5 do
        local ringDist = gridSize * ring
        local pointsInRing = 8 + ring * 6
        for i = 0, pointsInRing - 1 do
            local rad = math.rad(i * (360 / pointsInRing))
            local offset = Vector(math.cos(rad) * ringDist, math.sin(rad) * ringDist, 0)
            local candidatePos = pos + offset

            local candidateFloor, _ = CheckFloor(candidatePos)
            if candidateFloor and CheckPositionClear(candidateFloor) then
                table.insert(candidates, {pos = candidateFloor, priority = 1 + ring * 0.12})
            end
        end
    end

    local bestPos = pos
    local bestAng = Angle(0, 0, 0)
    local bestTotalScore = -math.huge

    for _, candidate in ipairs(candidates) do
        local ang, score = FindBestAngle(candidate.pos)
        score = score / candidate.priority

        if score > bestTotalScore then
            bestTotalScore = score
            bestPos = candidate.pos
            bestAng = ang
        end
    end

    local center = bestPos + Vector(0, 0, checkHeight)
    local forward = bestAng:Forward()
    local right = bestAng:Right()
    local adjustment = Vector(0, 0, 0)

    local backDist = TraceHullOpen(center, -forward, minBackClearance, Vector(-12, -12, -12), Vector(12, 12, 12))
    if backDist < minBackClearance * 0.5 then
        adjustment = adjustment + forward * (minBackClearance * 0.5 - backDist)
    end

    local leftDist = TraceHullOpen(center, -right, minSideClearance, Vector(-12, -12, -12), Vector(12, 12, 12))
    local rightDist = TraceHullOpen(center, right, minSideClearance, Vector(-12, -12, -12), Vector(12, 12, 12))
    if leftDist < minSideClearance * 0.5 then
        adjustment = adjustment + right * (minSideClearance * 0.5 - leftDist)
    end
    if rightDist < minSideClearance * 0.5 then
        adjustment = adjustment - right * (minSideClearance * 0.5 - rightDist)
    end

    if adjustment:LengthSqr() > 1 then
        local adjustedPos = bestPos + adjustment
        local adjustedFloor, _ = CheckFloor(adjustedPos)
        if adjustedFloor and CheckPositionClear(adjustedFloor) then
            bestPos = adjustedFloor
        end
    end

    if not CheckPositionClear(bestPos) then
        bestPos = FindNearestClearSpot(bestPos)
    end

    debugoverlay.Line(bestPos, bestPos + bestAng:Forward() * 32, 20, Color(0, 255, 0), true)
    return bestPos, bestAng
end

local hiddenEntities = {}

hook.Add("PrePlayerDraw", "HidePlayersInDeathScene", function(ply)
    if isSceneActive then return true end
end)

hook.Add("Think", "ManageEntitiesInDeathScene", function()
    if not isSceneActive then
        for ent, data in pairs(hiddenEntities) do
            if IsValid(ent) then
                ent:SetNoDraw(false)
            end
        end
        table.Empty(hiddenEntities)
        return
    end

    for _, ent in ents.Iterator() do
        if IsValid(ent) and not hiddenEntities[ent] and not ent.NoHideDA then
            local class = ent:GetClass()
            if MuR.IsAI(ent) or class == "prop_ragdoll" or class == "class C_ClientRagdoll" then
                hiddenEntities[ent] = true
                ent:SetNoDraw(true)
            end
        end
    end
end)

net.Receive("MuR.ZombieDeathAnim", function()
    local pos = net.ReadVector()
    local npcClass = net.ReadString()
    local safePos, safeAng = FindSafeDeathAnimationPos(pos)
    LocalPlayer():ScreenFade(SCREENFADE.IN, color_black, 0.2, 0)
    StartDeathAnimation(safePos, safeAng, npcClass)
end)
