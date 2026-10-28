local grtodown = Material( "vgui/gradient-u" )
local grtoup = Material( "vgui/gradient-d" )
local grtoright = Material( "vgui/gradient-l" )
local grtoleft = Material( "vgui/gradient-r" )
local addmat_r = Material("CA/add_r")
local addmat_g = Material("CA/add_g")
local addmat_b = Material("CA/add_b")
local vgbm = Material("vgui/black")

local blurimpulse = 0
local impulse = 0
local k = 0
local k4 = 0
local k3 = 0
local time = 0

net.Receive("MuR.PainImpulse",function()
	local fl = net.ReadFloat()
	impulse = fl * 10
	blurimpulse = fl * 5
end)

hook.Add("HUDPaint","MuR.PainEffect",function()
   if not LocalPlayer():Alive() then return end
   if blurimpulse <= 0 then return end

   k = Lerp(0.1,k,math.Clamp(blurimpulse / 250,0,15))
   DrawMotionBlur(0.2, k * 0.7, 0.02)
end)

local function DrawCA(rx, gx, bx, ry, gy, by)
	render.UpdateScreenEffectTexture()
	addmat_r:SetTexture("$basetexture", render.GetScreenEffectTexture())
	addmat_g:SetTexture("$basetexture", render.GetScreenEffectTexture())
	addmat_b:SetTexture("$basetexture", render.GetScreenEffectTexture())
	render.SetMaterial(vgbm)
	render.DrawScreenQuad()
	render.SetMaterial(addmat_r)
	render.DrawScreenQuadEx(-rx / 2, -ry / 2, ScrW() + rx, ScrH() + ry)
	render.SetMaterial(addmat_g)
	render.DrawScreenQuadEx(-gx / 2, -gy / 2, ScrW() + gx, ScrH() + gy)
	render.SetMaterial(addmat_b)
	render.DrawScreenQuadEx(-bx / 2, -by / 2, ScrW() + bx, ScrH() + by)
end

hook.Add("RenderScreenspaceEffects","MuR.PainImpulse",function()
	if not LocalPlayer():Alive() then
		impulse = 0
		blurimpulse = 0
		return
	end
	if impulse <= 0 and blurimpulse <= 0 then return end
	k3 = math.Clamp(Lerp(0.01,k3,impulse),0,50)
	impulse = math.max(impulse-FrameTime()/0.05, 0)
	blurimpulse = math.max(blurimpulse-FrameTime(), 0)
	DrawCA(4 * k3, 2 * k3, 0, 2 * k3, 1 * k3, 0)
end)

local bloodBlur = 0
local bloodVignette = 0

hook.Add("RenderScreenspaceEffects", "MuR.StunFX", function()
	local ply = LocalPlayer()
	if not ply:Alive() then return end
	local concussionEnd = ply:GetNW2Float("ConcussionEnd", 0)
	local concussionIntensity = ply:GetNW2Float("ConcussionIntensity", 0)
	if CurTime() >= concussionEnd then return end

	local left = concussionEnd - CurTime()
	local frac = math.Clamp(left / (concussionIntensity * 2), 0, 1)
	local col = {
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.02 * concussionIntensity * frac,
		["$pp_colour_contrast"] = 1 - 0.15 * concussionIntensity * frac,
		["$pp_colour_colour"] = 1 - 0.5 * concussionIntensity * frac,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	}
	DrawColorModify(col)
	DrawMotionBlur(0.1, 0.3 * concussionIntensity * frac, 0.03)
	local scrw, scrh = ScrW(), ScrH()
    surface.SetDrawColor(255, 255, 255, 25 * concussionIntensity * frac)
    surface.DrawRect(0, 0, scrw, scrh)
end)

hook.Add("RenderScreenspaceEffects", "MuR.CoordinationFX", function()
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    local coordinationEnd = ply:GetNW2Float("CoordinationEnd", 0)
    local coordinationSeverity = ply:GetNW2Float("CoordinationSeverity", 0)
    if CurTime() >= coordinationEnd then return end

    local left = coordinationEnd - CurTime()
    local frac = math.Clamp(left / 8, 0, 1)
    local col = {
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.02 * coordinationSeverity * frac,
        ["$pp_colour_contrast"] = 1 - 0.1 * coordinationSeverity * frac,
        ["$pp_colour_colour"] = 1 - 0.3 * coordinationSeverity * frac,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    }
    DrawColorModify(col)
    DrawMotionBlur(0.1, 0.5 * coordinationSeverity * frac, 0.03)
end)

hook.Add("RenderScreenspaceEffects", "MuR.LowHealthFX", function()
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    local health = ply:Health()
    local maxHealth = ply:GetMaxHealth()
    local threshold = maxHealth * 0.35

    if health < threshold then
        local frac = 1 - (health / threshold)

        local col = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -0.1 * frac,
            ["$pp_colour_contrast"] = 1 + 0.1 * frac,
            ["$pp_colour_colour"] = 1 - (0.6 * frac),
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        }

        DrawColorModify(col)
        DrawMotionBlur(0.1, 0.5 * frac, 0.01)
    end
end)

hook.Remove("RenderScreenspaceEffects", "MuR.DyingFX")
hook.Remove("HUDPaint", "MuR.DyingTunnel")

local OXYGEN_GREYOUT_START = 90
local OXYGEN_BLACKOUT = 45

local function GetSyncopeStrain(ply)
    local oxygen = ply:GetNW2Float("CerebralOxygen", 100)
    local strain = math.Clamp((OXYGEN_GREYOUT_START - oxygen) / (OXYGEN_GREYOUT_START - OXYGEN_BLACKOUT), 0, 1)

    strain = math.max(strain, ply:GetNW2Int("HypovolemiaStage", 0) * 0.22)

    return strain
end

hook.Add("RenderScreenspaceEffects", "MuR.SyncopeFX", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local strain = GetSyncopeStrain(ply)
    local dying = ply:GetNW2Bool("MuR.Dying", false)
    if strain <= 0.02 and not dying then return end

    if dying then strain = math.max(strain, 0.35) end

    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.05 - strain * 0.3,
        ["$pp_colour_contrast"] = 1 - strain * 0.25,
        ["$pp_colour_colour"] = math.max(1 - strain * 0.95, 0),
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    })

    if strain > 0.25 then
        DrawMotionBlur(0.12, 0.3 + strain * 0.4, 0.02)
    end
    if dying then
        DrawBloom(0.6, 0.8 + strain, 6, 6, 1, 1, 1, 1, 1)
    end
end)

local matGradDown = Material("gui/gradient_down")
local matGradUp = Material("gui/gradient_up")
local matGradSide = Material("gui/gradient")

local function drawTunnel(strain)
    local w, h = ScrW(), ScrH()
    local depthY = (0.06 + strain * 0.36) * h
    local depthX = (0.06 + strain * 0.36) * w
    local alpha = math.floor(255 * (0.35 + strain * 0.6))

    surface.SetDrawColor(0, 0, 0, alpha)

    surface.SetMaterial(matGradDown)
    surface.DrawTexturedRect(0, 0, w, depthY)

    surface.SetMaterial(matGradUp)
    surface.DrawTexturedRect(0, h - depthY, w, depthY)

    surface.SetMaterial(matGradSide)
    surface.DrawTexturedRect(0, 0, depthX, h)
    surface.DrawTexturedRectRotated(w - depthX * 0.5, h * 0.5, depthX, h, 180)
end

hook.Add("HUDPaint", "MuR.SyncopeTunnel", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local strain = GetSyncopeStrain(ply)
    if ply:GetNW2Bool("MuR.Dying", false) then strain = math.max(strain, 0.35) end
    if strain <= 0.05 then return end

    drawTunnel(strain)
end)

local heartbeat

hook.Add("Think", "MuR.SyncopeHeartbeat", function()
    local ply = LocalPlayer()

    if not IsValid(ply) or not ply:Alive() then
        if heartbeat then heartbeat:Stop() heartbeat = nil end
        return
    end

    local strain = GetSyncopeStrain(ply)

    if strain < 0.18 then
        if heartbeat then heartbeat:Stop() heartbeat = nil end
        return
    end

    if not heartbeat then
        heartbeat = CreateSound(ply, "player/heartbeat1.wav")
        if not heartbeat then return end
        heartbeat:PlayEx(0, 100)
    end

    heartbeat:ChangePitch(math.floor(70 + strain * 55), 0.3)
    heartbeat:ChangeVolume(math.min(0.2 + strain * 0.5, 0.85), 0.3)
end)

hook.Add("PlayerSpawn", "MuR.SyncopeHeartbeatReset", function(ply)
    if ply == LocalPlayer() and heartbeat then
        heartbeat:Stop()
        heartbeat = nil
    end
end)

hook.Add("RenderScreenspaceEffects", "MuR.UnconsciousFX", function()
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    if ply:GetNW2Bool("AdrenalineOverdosing", false) then return end
    local unconsciousEnd = ply:GetNW2Float("UnconsciousEnd", 0)
    if CurTime() >= unconsciousEnd then return end

    local col = {
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.9,
        ["$pp_colour_contrast"] = 1,
        ["$pp_colour_colour"] = 0,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0
    }
    DrawColorModify(col)
end)

local RAGDOLL_CONTROL_KEYS = {
    IN_ATTACK, IN_ATTACK2, IN_SPEED, IN_WALK, IN_JUMP,
    IN_RELOAD, IN_USE, IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT
}

hook.Add("CreateMove", "MuR.DyingControl", function(cmd)
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    if ply:GetNW2Bool("IsUnconscious", false) or ply:GetNW2Bool("MuR.Dying", false) then
        for _, key in ipairs(RAGDOLL_CONTROL_KEYS) do
            cmd:RemoveKey(key)
        end
        cmd:ClearMovement()
    end
end)

hook.Add("CreateMove", "MuR.CoordinationControl", function(cmd)
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    local coordinationEnd = ply:GetNW2Float("CoordinationEnd", 0)
    local coordinationSeverity = math.max(ply:GetNW2Float("CoordinationSeverity", 0)/100, 0.000001)
    if CurTime() >= coordinationEnd then return end

    local frac = math.Clamp((coordinationEnd - CurTime()) / 8, 0, 1)
    local severity = coordinationSeverity * frac
    local shake = math.sin(CurTime() * 15) * severity * 90
    local ang = cmd:GetViewAngles()
    ang.p = ang.p + shake * 0.5
    ang.y = ang.y + shake
    cmd:SetViewAngles(ang)
end)

hook.Add("PlayerDeath", "MuR.ClearBloodEffects", function(victim)
	if victim == LocalPlayer() then
		bloodBlur = 0
		bloodVignette = 0
	end
end)

hook.Add("HUDPaint", "MuR.BloodEffects", function()
	if not LocalPlayer():Alive() then
		bloodBlur = Lerp(FrameTime() * 3, bloodBlur, 0)
		bloodVignette = Lerp(FrameTime() * 3, bloodVignette, 0)
		if bloodBlur < 0.01 and bloodVignette < 0.01 then return end
	end

	local ply = LocalPlayer()
	local bleedLevel = ply:GetNW2Float("BleedLevel") or 0
	local hardBleed = ply:GetNW2Bool("HardBleed") or false

	if not ply:Alive() then
		bloodBlur = Lerp(FrameTime() * 5, bloodBlur, 0)
		bloodVignette = Lerp(FrameTime() * 5, bloodVignette, 0)
		return
	end

	local bloodIntensity = 0
	if hardBleed then
		bloodIntensity = 0.4 + math.sin(CurTime() * 8) * 0.1
	elseif bleedLevel >= 3 then
		bloodIntensity = 0.25 + math.sin(CurTime() * 4) * 0.08
	elseif bleedLevel == 2 then
		bloodIntensity = 0.12 + math.sin(CurTime() * 2) * 0.05
	elseif bleedLevel == 1 then
		bloodIntensity = 0.05 + math.sin(CurTime()) * 0.02
	end

	bloodBlur = Lerp(FrameTime() * 2, bloodBlur, bloodIntensity * 2)
	bloodVignette = Lerp(FrameTime() * 1.5, bloodVignette, bloodIntensity)

	if bloodBlur > 0.05 and ply:Alive() and ply:GetVelocity():Length() > 50 then
		DrawMotionBlur(0.05, bloodBlur * 0.2, 0.005)
	end

	if bloodVignette > 0.02 then
		local vignetteAlpha = math.Clamp(bloodVignette * 80, 0, 120)
		local vignetteSize = Lerp(bloodVignette, 0.2, 0.6)

		surface.SetMaterial(grtodown)
		surface.SetDrawColor(80, 15, 15, vignetteAlpha)
		surface.DrawTexturedRect(0, ScrH() * (1 - vignetteSize), ScrW(), ScrH() * vignetteSize)

		surface.SetMaterial(grtoup)
		surface.SetDrawColor(80, 15, 15, vignetteAlpha * 0.6)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH() * vignetteSize * 0.4)

		surface.SetMaterial(grtoright)
		surface.SetDrawColor(80, 15, 15, vignetteAlpha * 0.4)
		surface.DrawTexturedRect(0, 0, ScrW() * vignetteSize * 0.2, ScrH())

		surface.SetMaterial(grtoleft)
		surface.SetDrawColor(80, 15, 15, vignetteAlpha * 0.4)
		surface.DrawTexturedRect(ScrW() * (1 - vignetteSize * 0.2), 0, ScrW() * vignetteSize * 0.2, ScrH())
	end
end)

hook.Add("RenderScreenspaceEffects", "MuR.BloodScreenEffects", function()
	local ply = LocalPlayer()
	local bleedLevel = ply:GetNW2Float("BleedLevel") or 0
	local hardBleed = ply:GetNW2Bool("HardBleed") or false

end)
