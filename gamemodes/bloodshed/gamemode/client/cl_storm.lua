local StormActive = false
local WindDirection = Vector(0, 0, 0)
local RainActiveAt = 0
local ThunderFlashUntil = 0
local LastStrikeAt = 0
local LastStrikePos = vector_origin
local LastStrikeRadius = 0
local NextAmbientUpdate = 0
local RainLoop
local WindLoop

net.Receive("MuR.Storm.Start", function()
	StormActive = true
	RainActiveAt = CurTime() + 30
end)

net.Receive("MuR.Storm.End", function()
	StormActive = false
	ThunderFlashUntil = 0
	if RainLoop then RainLoop:Stop() RainLoop = nil end
	if WindLoop then WindLoop:Stop() WindLoop = nil end
end)

net.Receive("MuR.Storm.WindDirection", function()
	WindDirection = net.ReadVector()
end)

local PowerOutageUntil = 0
local NextPowerOnSound = 0

net.Receive("MuR.Storm.Thunder", function()
	if not StormActive then return end
	local p = LocalPlayer()
	if not IsValid(p) then return end
	util.ScreenShake(p:GetPos(), math.random(4, 10), 0.3, math.random(1, 2), 8000)
	ThunderFlashUntil = CurTime() + 0.25 + math.Rand(0.0, 0.25)
	local hasPayload = net.ReadBool()
	if hasPayload then
		LastStrikePos = net.ReadVector()
		LastStrikeRadius = net.ReadUInt(12)
		LastStrikeAt = CurTime()
		local lightsOut = net.ReadBool()
		if lightsOut then
			local dur = net.ReadUInt(8)
			PowerOutageUntil = CurTime() + dur
			NextPowerOnSound = PowerOutageUntil
			surface.PlaySound("ambient/energy/power_off" .. math.random(1,2) .. ".wav")
		end
	end
end)

hook.Add("SetupWorldFog", "StormFog", function()
	if not StormActive then return end
	local ply = LocalPlayer()
	local dist = 1400
	if game.GetWorld():GetNW2Bool("MuR_TornadoActive", false) then
		local c = game.GetWorld():GetNW2Vector("MuR_TornadoCenter", Vector(0,0,0))
		local d = ply:GetPos():Distance(c)
		dist = math.Clamp(d * 0.5, 250, 1400)
	end

	local density = 0.99
	local r, g, b = 30, 30, 40

	if PowerOutageUntil > CurTime() then
		dist = 250
		density = 1.0
		r, g, b = 0, 0, 0
	elseif CurTime() - PowerOutageUntil < 1.0 then
		local delta = CurTime() - PowerOutageUntil
		dist = Lerp(delta, 250, dist)
		density = Lerp(delta, 1.0, 0.99)
		r = Lerp(delta, 0, 30)
		g = Lerp(delta, 0, 30)
		b = Lerp(delta, 0, 40)
	end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(0)
	render.FogEnd(dist)
	render.FogMaxDensity(density)
	render.FogColor(r, g, b)
	return true
end)

hook.Add("SetupSkyboxFog", "StormSkyboxFog", function()
	if not StormActive then return end

	local dist = 1400
	local density = 0.99
	local r, g, b = 30, 30, 40

	if PowerOutageUntil > CurTime() then
		dist = 250
		density = 1.0
		r, g, b = 0, 0, 0
	elseif CurTime() - PowerOutageUntil < 1.0 then
		local delta = CurTime() - PowerOutageUntil
		dist = Lerp(delta, 250, dist)
		density = Lerp(delta, 1.0, 0.99)
		r = Lerp(delta, 0, 30)
		g = Lerp(delta, 0, 30)
		b = Lerp(delta, 0, 40)
	end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(0)
	render.FogEnd(dist)
	render.FogMaxDensity(density)
	render.FogColor(r, g, b)
	return true
end)

hook.Add("PostDrawSkyBox", "StormDarkSky", function()
	if not StormActive then return end
	render.OverrideColorWriteEnable(true, true)
	render.SetColorMaterial()
	local a = 255
	if ThunderFlashUntil > CurTime() then a = 80 end
	render.DrawQuadEasy(Vector(0, 0, 0), Vector(0, 0, -1), 32000, 32000, Color(5, 5, 8, a), 0)
	render.OverrideColorWriteEnable(false)
end)

local storm_colormod = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0.03,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 0.92,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

local storm_powerout = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0.02,
	[ "$pp_colour_brightness" ] = -0.05,
	[ "$pp_colour_contrast" ] = 0.9,
	[ "$pp_colour_colour" ] = 0.5,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

hook.Add("RenderScreenspaceEffects", "StormColorMod", function()
	if not StormActive then return end
	if PowerOutageUntil > CurTime() then
		DrawColorModify(storm_powerout)
	else
		DrawColorModify(storm_colormod)
	end
end)

local rainMat = Material("effects/tool_tracer")
local dustMat = Material("sprites/glow04_noz")
local smokeMat = Material("particle/particle_smokegrenade")

hook.Add("PostDrawTranslucentRenderables", "StormEffects", function()
	if not StormActive then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if CurTime() < RainActiveAt then return end
	local eye = ply:EyePos()

	local wind = WindDirection:GetNormalized()
	local t = CurTime()

	render.SetMaterial(rainMat)
	for i = 1, 120 do
		local off = Vector(math.sin(t * 2 + i) * 350, math.cos(t * 1.6 + i) * 350, math.random(100, 500))
		local s = eye + off
		local tr = util.TraceLine({start = s, endpos = s + Vector(0,0,2048), mask = MASK_SOLID_BRUSHONLY})
		if not tr.Hit or tr.HitSky then
			local e = s + wind * 180 + Vector(0, 0, -350)
			local tr2 = util.TraceLine({start = s, endpos = e, mask = MASK_SOLID_BRUSHONLY})
			if tr2.Hit then e = tr2.HitPos end
			render.DrawBeam(s, e, 2, 0, 1, Color(180, 190, 220, 80))
		end
	end

	render.SetMaterial(dustMat)
	for i = 1, 40 do
		local p = eye + Vector(math.sin(t + i * 0.5) * 400, math.cos(t * 0.9 + i * 0.3) * 400, math.random(0, 300))
		local tr = util.TraceLine({start = p, endpos = p + Vector(0,0,2048), mask = MASK_SOLID_BRUSHONLY})
		if not tr.Hit or tr.HitSky then
			local e = p + wind * 120 + Vector(math.sin(t * 3 + i) * 20, math.cos(t * 2.5 + i) * 20, -math.random(10, 60))
			local tr2 = util.TraceLine({start = p, endpos = e, mask = MASK_SOLID_BRUSHONLY})
			if tr2.Hit then e = tr2.HitPos end
			render.DrawSprite(e, math.random(8,16), math.random(8,16), Color(100, 90, 80, 100))
		end
	end

	local tornado = game.GetWorld():GetNW2Bool("MuR_TornadoActive", false)
	if tornado then
		local c = game.GetWorld():GetNW2Vector("MuR_TornadoCenter", Vector(0,0,0))
		local d2 = ply:GetPos():DistToSqr(c)
		if d2 < (2000*2000) then
			render.SetMaterial(smokeMat)
			for i = 1, 30 do
				local ang = (t * 90 + i * (360/30)) % 360
				local r = 200 + i * 10 + math.sin(t * 5 + i) * 50
				local h = i * 40
				local pos2 = c + Vector(math.cos(math.rad(ang)) * r, math.sin(math.rad(ang)) * r, h)
				local dir2 = (WindDirection:GetNormalized() * 0.5 + VectorRand() * 0.5):GetNormalized()
				local len = 100 + math.random(0,50)
				local a1 = pos2
				local a2 = pos2 + dir2 * len + Vector(0,0,math.random(20,60))
				render.DrawBeam(a1, a2, 40, 0, 1, Color(80, 75, 70, 120))
			end
		end
	end

	if LastStrikeAt > 0 and CurTime() - LastStrikeAt < 0.35 then
		local d = DynamicLight(LocalPlayer():EntIndex() + 902)
		if d then
			d.pos = LastStrikePos
			d.r = 180
			d.g = 200
			d.b = 255
			d.brightness = 8
			d.Decay = 2000
			d.Size = LastStrikeRadius
			d.DieTime = CurTime() + 0.15
		end
		render.SetMaterial(dustMat)
		render.DrawSprite(LastStrikePos + Vector(0,0,16), 64, 64, Color(200, 220, 255, 180))
	end
end)

local function StormThink()
	if not StormActive then return end

	if NextPowerOnSound > 0 and CurTime() >= NextPowerOnSound then
		surface.PlaySound("ambient/machines/thumper_startup1.wav")
		NextPowerOnSound = 0
	end

	if CurTime() < RainActiveAt then return end
	if CurTime() < NextAmbientUpdate then return end
	NextAmbientUpdate = CurTime() + 0.4
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local p = ply:GetPos()
	local sky = util.TraceLine({start = p, endpos = p + Vector(0, 0, 2000), filter = ply, mask = MASK_SOLID_BRUSHONLY})
	local outside = sky.HitSky or sky.Fraction > 0.8
	local nearWin = 0
	for i = 1, 8 do
		local a = (i - 1) * (360 / 8)
		local dir = Vector(math.cos(math.rad(a)), math.sin(math.rad(a)), 0)
		local t = util.TraceLine({start = p + Vector(0, 0, 40), endpos = p + dir * 2000, filter = ply, mask = MASK_SOLID})
		if t.Hit and t.HitTexture then
			local n = string.lower(t.HitTexture)
			if string.find(n, "glass") or string.find(n, "window") then nearWin = nearWin + 1 end
		elseif t.HitSky then nearWin = nearWin + 1 end
	end
	local wind = WindDirection:Length()
	local windVol = math.Clamp(wind / 160, 0.2, 1)
	local rainVol = outside and 0.7 or math.min(0.15 * nearWin, 0.5)
	local moanVol = outside and 0 or (nearWin > 0 and 0.35 or 0.15)
	if not RainLoop then RainLoop = CreateSound(ply, "ambient/weather/rumble_rain.wav") end
	if not WindLoop then WindLoop = CreateSound(ply, "ambient/wind/wind_hit2.wav") end
	if RainLoop then RainLoop:PlayEx(rainVol, 90) end
	if WindLoop then WindLoop:PlayEx(windVol + moanVol, 95) end
end

hook.Add("Think", "StormAmbientThink", StormThink)
