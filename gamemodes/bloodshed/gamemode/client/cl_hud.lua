MuR.DrawHUD = true
MuR.CutsceneActive = false
MuR.ShowDeathLog = false
MuR.GamemodeCount = 0
MuR.Data = {}
MuR.Data["PoliceState"] = 0
MuR.Data["PoliceArriveTime"] = 0
MuR.Data["ExfilPos"] = Vector()
MuR.Data["HeliArrived"] = false
MuR.Data["SniperArrived"] = false
MuR.Data["TimerActive"] = false
MuR.Data["TimerLeft"] = 0
MuR.Data["EnableDebug"] = false
MuR.Data["Mode24Wave"] = 0
MuR.Data["Mode24Phase"] = "prep"
MuR.Data["Mode24PhaseEnd"] = 0
MuR.TimerPausedTime = 0
MuR.TimerWasPaused = false
hook.Add("Think", "MuR.OtherThingsCL", function()
	MuR.EnableDebug = MuR.Data["EnableDebug"]
end)

MuR.AllyCheckConfig = {
	sameTeam = {
		team1 = true,
	},

	classGroups = {
		police = {"Officer", "ArmoredOfficer", "SWAT", "FBI", "Riot"},
		swat = {"SWAT"},
		terrorists = {"Terrorist2"},
		gangred = {"GangRed"},
		ganggreen = {"GangGreen"},
		mafia = {"Mafia"},
		soldiers = {"Soldier"},
		prisonguards = {"PrisonGuard"},
		fbiops = {"FBIOperative"},
	},

	specialChecks = {
		policeFunction = true,
	}
}

function MuR:ArePlayersAllies(localPly, targetPly)
	local config = MuR.AllyCheckConfig
	local mode = MuR.Mode and MuR.Mode(MuR.GamemodeCount) or {}

	if config.sameTeam.team1 and localPly:Team() == 1 and targetPly:Team() == 1 then
		if MuR.GamemodeCount == 23 and localPly:GetNW2String("Class") == "Prisoner" then
			return false
		end
		return true
	end

	if MuR.GamemodeCount == 26 then
		return localPly:GetNW2String("Class") == "Killer" and targetPly:GetNW2String("Class") == "Killer"
	end

	if (mode.spawn_type == "tdm" or mode.tdm_end_logic) and localPly:Team() == targetPly:Team() then
		return true
	end

	if config.specialChecks.policeFunction and localPly:IsRolePolice() and targetPly:IsRolePolice() then
		return true
	end

	local localClass = localPly:GetNW2String("Class")
	local targetClass = targetPly:GetNW2String("Class")

	for groupName, classes in pairs(config.classGroups) do
		local localInGroup = table.HasValue(classes, localClass)
		local targetInGroup = table.HasValue(classes, targetClass)

		if localInGroup and targetInGroup then
			return true
		end
	end

	if MuR.GamemodeCount == 6 and localPly:Team() == targetPly:Team() then
		return true
	end

	return false
end

net.Receive("MuR.SendDataToClient", function()
	local str = net.ReadString()
	local value = net.ReadTable()[1]
	MuR.Data[str] = value
end)

net.Receive("MuR.PlaySoundOnClient", function()
	local str = net.ReadString()
	surface.PlaySound(str)
end)

local hide = {
	["CHudHealth"] = true,
	["CHudAmmo"] = true,
	["CHudSecondaryAmmo"] = true,
	["CHudBattery"] = true,
	["CHudCrosshair"] = true,
	["CHudDamageIndicator"] = true,
}

local voiceicon = Material("murdered/voice.png", "smooth")
local wantedicon = Material("murdered/wanted.png", "smooth")
local arresticon = Material("murdered/handcuffs.png", "smooth")
local policeicon = Material("murdered/police.png", "mips")
local swaticon = Material("murdered/swat.png", "mips")
local assaulticon = Material("murdered/assault.png", "mips")
local helipadicon = Material("murdered/exfil.png")
local pistolicon = Material("murdered/pistol.png", "smooth")
local brokenicon = Material("murdered/broken.png", "smooth")
local bcircleicon = Material("murdered/blurcircle.png", "smooth")
local stamicon = Material("murdered/run.png", "smooth")
local vinmat = Material("murdered/vin.png", "smooth")
local axonmat = Material("murdered/policelogo.png", "smooth")
local cal1 = Material("ui/9mm.png")
local cal2 = Material("ui/762.png")
local cal3 = Material("ui/556.png")
local cal4 = Material("ui/357.png")
local cal5 = Material("ui/12gauge.png")
local adrenalineAddR = Material("CA/add_r")
local adrenalineAddG = Material("CA/add_g")
local adrenalineAddB = Material("CA/add_b")
local adrenalineBlack = Material("vgui/black")

local function DrawAdrenalineCA(rx, gx, bx, ry, gy, by)
	render.UpdateScreenEffectTexture()
	adrenalineAddR:SetTexture("$basetexture", render.GetScreenEffectTexture())
	adrenalineAddG:SetTexture("$basetexture", render.GetScreenEffectTexture())
	adrenalineAddB:SetTexture("$basetexture", render.GetScreenEffectTexture())

	render.SetMaterial(adrenalineBlack)
	render.DrawScreenQuad()

	render.SetMaterial(adrenalineAddR)
	render.DrawScreenQuadEx(-rx / 2, -ry / 2, ScrW() + rx, ScrH() + ry)

	render.SetMaterial(adrenalineAddG)
	render.DrawScreenQuadEx(-gx / 2, -gy / 2, ScrW() + gx, ScrH() + gy)

	render.SetMaterial(adrenalineAddB)
	render.DrawScreenQuadEx(-bx / 2, -by / 2, ScrW() + bx, ScrH() + by)
end

function We(x)
	return x / 1920 * ScrW()
end

function He(y)
	return y / 1080 * ScrH()
end

hook.Add("HUDShouldDraw", "HideHUD", function(name)
	if hide[name] then return false end
end)

hook.Add("DrawDeathNotice", "DisableKillfeed", function() return 0, 0 end)
hook.Add("PlayerStartVoice", "ImageOnVoice", function(ply)
	return ply == LocalPlayer() and false or not LocalPlayer():IsAdmin() or ply:Alive()
end)

local stamalpha = 0
local stamold = 0

local markupCache = {}
local function GetMarkup(str)
	if not markupCache[str] then
		markupCache[str] = markup.Parse(str)
	end
	return markupCache[str]
end

local cachedTrace
local lastTraceFrame = 0
local function GetCachedTrace(ply)
	if lastTraceFrame ~= FrameNumber() then
		cachedTrace = ply:GetEyeTrace()
		lastTraceFrame = FrameNumber()
	end
	return cachedTrace
end

hook.Add("HUDPaint", "MurderedHUD", function()
	local ply = LocalPlayer()
	local guilt = ply:GetNW2Float("Guilt", 0)

	if guilt >= 90 then
		local alpha = math.cos(CurTime() * 4) * 255

		if alpha < 0 then
			alpha = alpha * -1
		end

		draw.SimpleText(MuR.Language["guiltwarning"], "MuR_Font2", ScrW() / 2, ScrH() / 2 - He(300), Color(200, 200 - ((guilt / 100) * 200), 200 - ((guilt / 100) * 200), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end

	if MuR.DrawHUD and ply:Alive() and !MuR:GetClient("blsd_nohud") then
		if ply:GetNW2String("Class") == "Zombie" then
			surface.SetDrawColor(100, 0, 0, 50)
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		else
			if MuR.Data["ExfilPos"] and MuR.Data["PoliceState"] == 8 then
				if MuR.Data["ExfilPos"]:DistToSqr(ply:GetPos()) < 40000 then
					local alpha = math.abs(math.cos(CurTime() * 2) * 255)
					draw.SimpleText(MuR.Language["evac_zone"], "MuR_Font3", ScrW()/2, He(100), Color(200, 200, 20, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end

				local pos = (MuR.Data["ExfilPos"] + Vector(0,0,32)):ToScreen()
				surface.SetMaterial(helipadicon)
				surface.SetDrawColor(255,255,255,200)
				surface.DrawTexturedRect(pos.x - 24, pos.y - 24, 48, 48)
				draw.SimpleText(math.floor(ply:GetPos():Distance(MuR.Data["ExfilPos"]) / 80) .. "m", "MuR_Font1", pos.x + 20, pos.y, Color(255,255,255,200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		local tr = GetCachedTrace(ply).Entity

		if IsValid(tr) and tr:GetPos():DistToSqr(ply:GetPos()) < 10000 and !ply:GetNW2Bool("IsUnconscious", false) then
			local name = tr:GetNWString("Name", "")
			local candraw = ply:GetNW2Entity("RD_EntCam") ~= tr

			if tr:IsPlayer() and tr:GetNW2String("Class") == "Zombie" then
				candraw = false
			end
			if table.HasValue(MuR.LootableProps, tr:GetModel()) then
				local parsed = GetMarkup("<font=MuR_Font0><colour=255,255,255>E<colour=200,200,0>" .. MuR.Language["ragdoll_use"])
				parsed:Draw(ScrW() / 2, ScrH() / 2 + He(30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if candraw then
				if tr:GetClass() == "prop_ragdoll" and tr:GetNWString("Name", "") != ""then
					local parsed = GetMarkup("<font=MuR_Font0><colour=255,255,255>E<colour=200,200,0>" .. MuR.Language["ragdoll_use"])
					parsed:Draw(ScrW() / 2, ScrH() / 2 + He(30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end

				draw.SimpleText(name, "MuR_Font5", ScrW() / 2, ScrH() / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if tr:GetNW2Bool("BreakableThing") and tr.Health and tr:Health() > 0 then
				local parsed = GetMarkup("<font=MuR_Font1><colour=255,255,255>" .. MuR.Language["strength"] .. "<colour=200," .. math.floor((tr:Health() / tr:GetMaxHealth()) * 200) .. "," .. math.floor((tr:Health() / tr:GetMaxHealth()) * 200) .. ">" .. math.floor((tr:Health() / tr:GetMaxHealth()) * 100) .. "%")
				parsed:Draw(ScrW() / 2, ScrH() / 2 + He(30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if ply:IsRolePolice() then
				local tr2 = tr:IsPlayer() and tr or tr:GetNW2Entity("Owner", tr)
				local icon = false
				if tr2:GetNW2Float("ArrestState") == 2 then
					icon = pistolicon
				elseif tr2:GetNW2Float("ArrestState") == 1 then
					icon = arresticon
				end
				if icon then
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(icon)
					surface.DrawTexturedRect(ScrW() / 2 - We(32), ScrH() / 2 + He(32), We(64), He(64))
				end
			end
		end

		local hunger = ply:GetNW2Float("Hunger")

		if hunger < 20 then
			draw.SimpleText(MuR.Language["hungermax"], "MuR_Font2", ScrW() / 2, ScrH() - He(10), Color(200, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		elseif hunger < 50 then
			draw.SimpleText(MuR.Language["hungermedium"], "MuR_Font2", ScrW() / 2, ScrH() - He(10), Color(200, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		elseif hunger < 80 then
			draw.SimpleText(MuR.Language["hungersmall"], "MuR_Font2", ScrW() / 2, ScrH() - He(10), Color(225, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end

		if ply:IsKiller() then
			local stab = ply:GetNW2Float("Stability")
			local stage = 0

			if stab < 60 then
				draw.SimpleText(MuR.Language["stability_message"], "MuR_Font1", We(20), ScrH() - He(10), Color(200, 20, 20, math.abs(math.sin(CurTime()*2)*255)), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end

			if stab < 10 then
				for i = 1, math.random(16,24) do
					draw.SimpleText(MuR.Language["kill_them"], "MuR_Font3", We(math.random(-100, ScrW()+100)), He(math.random(-100, ScrH()+100)), Color(200, 20, 20, math.abs(math.sin(CurTime()*4)*255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				if math.random(1,50) == 1 then
					ply:ViewPunchClient(AngleRand(-5,5))
				end
				surface.SetDrawColor(20,0,0,math.abs(math.sin(CurTime()*4)*255))
				surface.SetMaterial(vinmat)
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			elseif stab < 25 then
				for i = 1, math.random(8,16) do
					draw.SimpleText(MuR.Language["kill_them"], "MuR_Font2", We(math.random(-100, ScrW()+100)), He(math.random(-100, ScrH()+100)), Color(220, 160, 160, math.abs(math.sin(CurTime()*3)*255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				if math.random(1,75) == 1 then
					ply:ViewPunchClient(AngleRand(-3,3))
				end
				surface.SetDrawColor(10,0,0,math.abs(math.sin(CurTime()*3)*200))
				surface.SetMaterial(vinmat)
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			elseif stab < 40 then
				for i = 1, math.random(4,8) do
					draw.SimpleText(MuR.Language["kill_them"], "MuR_Font1", We(math.random(-100, ScrW()+100)), He(math.random(-100, ScrH()+100)), Color(255, 255, 255, math.abs(math.sin(CurTime()*2)*255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				if math.random(1,100) == 1 then
					ply:ViewPunchClient(AngleRand(-1,1))
				end
				surface.SetDrawColor(0,0,0,math.abs(math.sin(CurTime()*2)*150))
				surface.SetMaterial(vinmat)
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			elseif stab < 60 then
				for i = 1, math.random(1,4) do
					draw.SimpleText(MuR.Language["kill_them"], "MuR_Font1", We(math.random(-100, ScrW()+100)), He(math.random(-100, ScrH()+100)), Color(255, 255, 255, math.abs(math.sin(CurTime())*20)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end

			local parsed = GetMarkup("<font=MuR_Font2><colour=255,255,255>"..MuR.Language["stability"].."<colour=200," .. math.floor(stab/100 * 200) .. "," .. math.floor(stab/100 * 200) .. ">" .. math.floor(stab) .. "%")
			parsed:Draw(20, ScrH() - He(30), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end

		stamold = Lerp(0.01, stamold, LocalPlayer():GetNW2Float('Stamina'))
		local stam = stamold/100

		if stam < 0.99 then
			stamalpha = math.Clamp(stamalpha + FrameTime(), 0, 1)
		else
			stamalpha = math.Clamp(stamalpha - FrameTime(), 0, 1)
		end

		surface.SetMaterial(stamicon)
		surface.SetDrawColor(200, 100 * stam + 50, 0, 255 * stamalpha)
		surface.DrawTexturedRect(ScrW() - We(45), ScrH() / 2 - He(180), We(20), He(20))
		surface.SetDrawColor(20, 20, 20, 200 * stamalpha)
		surface.DrawRect(ScrW() - We(40), ScrH() / 2 - He(150), We(8), He(300))
		surface.SetDrawColor(200, 100 * stam + 50, 0, 255 * stamalpha)
		surface.DrawRect(ScrW() - We(38), ScrH() / 2 - He(148), We(4), He(296 * stam))

		if ply:GetNW2Bool("LegBroken") then
			surface.SetMaterial(brokenicon)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(ScrW() - We(48), ScrH() / 2 - He(290), We(36), He(36))
			local alpha = math.cos(CurTime() * 4) * 255

			if alpha < 0 then
				alpha = alpha * -1
			end

			draw.SimpleText(MuR.Language["legbroken"], "MuR_Font2", ScrW() - We(55), ScrH() / 2 - He(272), Color(180, 0, 0, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
	if !MuR:GetClient("blsd_nohud") then
		if MuR.Data["PoliceState"] == 1 then
			local time = MuR.Data["PoliceArriveTime"] - CurTime() + 0.5
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(policeicon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(20 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			local red = math.cos(CurTime() * 6) > 0
			local alpha = math.cos(CurTime() * 10) * 200

			if alpha < 0 then
				alpha = alpha * -1
			end

			if red then
				surface.SetDrawColor(25, 25, 200, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(15 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			else
				surface.SetDrawColor(200, 25, 25, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(30 + math.cos(CurTime() * 4) * 8), He(10 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			end

			draw.SimpleText(MuR.Language["policearecoming"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 8), He(70 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(time, "%02i:%02i"), "MuR_Font2", We(140 + math.cos(CurTime() * 4) * 8), He(90 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		elseif MuR.Data["PoliceState"] == 2 then
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(policeicon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 4), He(20 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			local red = math.cos(CurTime() * 6) > 0
			local alpha = math.cos(CurTime() * 10) * 200

			if alpha < 0 then
				alpha = alpha * -1
			end

			if red then
				surface.SetDrawColor(25, 25, 200, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 4), He(15 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			else
				surface.SetDrawColor(200, 25, 25, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(30 + math.cos(CurTime() * 4) * 4), He(10 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			end

			draw.SimpleText(MuR.Language["policearehere"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 4), He(70 + math.sin(CurTime() * 4) * 4), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		elseif MuR.Data["PoliceState"] == 3 then
			local time = MuR.Data["PoliceArriveTime"] - CurTime() + 0.5
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(swaticon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(20 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			local red = math.cos(CurTime() * 6) > 0
			local alpha = math.cos(CurTime() * 10) * 175

			if alpha < 0 then
				alpha = alpha * -1
			end

			if red then
				surface.SetDrawColor(25, 25, 200, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(10 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			else
				surface.SetDrawColor(200, 25, 25, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(30 + math.cos(CurTime() * 4) * 8), He(5 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			end

			draw.SimpleText(MuR.Language["swatarecoming"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 8), He(70 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(time, "%02i:%02i"), "MuR_Font2", We(140 + math.cos(CurTime() * 4) * 8), He(90 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		elseif MuR.Data["PoliceState"] == 4 then
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(swaticon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 4), He(20 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			local red = math.cos(CurTime() * 6) > 0
			local alpha = math.cos(CurTime() * 10) * 175

			if alpha < 0 then
				alpha = alpha * -1
			end

			if red then
				surface.SetDrawColor(25, 25, 200, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 4), He(10 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			else
				surface.SetDrawColor(200, 25, 25, alpha)
				surface.SetMaterial(bcircleicon)
				surface.DrawTexturedRect(We(30 + math.cos(CurTime() * 4) * 4), He(5 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			end

			draw.SimpleText(MuR.Language["swatarehere"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 4), He(70 + math.sin(CurTime() * 4) * 4), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		elseif MuR.Data["PoliceState"] == 5 then
			local time = MuR.Data["PoliceArriveTime"] - CurTime() + 0.5
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(assaulticon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(20 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			draw.SimpleText(MuR.Language["policeassault1"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 8), He(70 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(time, "%02i:%02i"), "MuR_Font2", We(140 + math.cos(CurTime() * 4) * 8), He(90 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if time < 42 then
				MuR:PlayMusic("murdered/theme/assault_theme.mp3")
			end
		elseif MuR.Data["PoliceState"] == 6 then
			local alpha = math.abs(math.sin(CurTime() * 2) * 255)
			local text = " / "..MuR.Language["policeassault"].." / "

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(assaulticon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 4), He(20 + math.sin(CurTime() * 4) * 4), We(96), He(96))
			draw.SimpleText(MuR.Language["policeassault2"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 4), He(70 + math.sin(CurTime() * 4) * 4), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.WordBox(4, ScrW()/2, He(40), text, "MuR_Font3", Color(160, 140, 0, 150), Color(220, 200, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			MuR:PlayMusic("murdered/theme/assault_theme.mp3")
		elseif MuR.Data["PoliceState"] == 7 then
			local time = MuR.Data["PoliceArriveTime"] - CurTime() + 0.5
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(helipadicon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(20 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			draw.SimpleText(MuR.Language["evac1"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 8), He(70 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(time, "%02i:%02i"), "MuR_Font2", We(140 + math.cos(CurTime() * 4) * 8), He(90 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if time < 50 then
				MuR:PlayMusic("murdered/theme/evac_theme.mp3")
			else
				MuR:PlayMusic("murdered/theme/zombie_theme.mp3")
			end
		elseif MuR.Data["PoliceState"] == 8 then
			local time = MuR.Data["PoliceArriveTime"] - CurTime() + 0.5
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(helipadicon)
			surface.DrawTexturedRect(We(20 + math.cos(CurTime() * 4) * 8), He(20 + math.sin(CurTime() * 4) * 8), We(96), He(96))
			draw.SimpleText(MuR.Language["evac2"], "MuR_Font3", We(140 + math.cos(CurTime() * 4) * 8), He(70 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(time, "%02i:%02i"), "MuR_Font2", We(140 + math.cos(CurTime() * 4) * 8), He(90 + math.sin(CurTime() * 4) * 8), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			if not MuR.ShowDeathLog then
				MuR:PlayMusic("")
			end
		end

		if ply:GetObserverMode() > 0 and !MuR.CutsceneActive then
			if IsValid(ply:GetObserverTarget()) then
				draw.SimpleText(MuR.Language["spectating:"], "MuR_Font1", ScrW() / 2, ScrH() / 2 + He(170), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(ply:GetObserverTarget():Nick(), "MuR_Font4", ScrW() / 2, ScrH() / 2 + He(200), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			local parsed = markup.Parse("<font=MuR_Font2><colour=255,255,255>"..MuR.Language["spectate_1"])
			parsed:Draw(ScrW() / 2, ScrH() - He(200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local parsed = markup.Parse("<font=MuR_Font1><colour=255,255,255>Space<colour=200,200,0>"..MuR.Language["spectate_2"])
			parsed:Draw(ScrW() / 2, ScrH() - He(170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local parsed = markup.Parse("<font=MuR_Font1><colour=255,255,255>LMB<colour=200,200,0>"..MuR.Language["spectate_3"])
			parsed:Draw(ScrW() / 2, ScrH() - He(150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local parsed = markup.Parse("<font=MuR_Font1><colour=255,255,255>RMB<colour=200,200,0>"..MuR.Language["spectate_4"])
			parsed:Draw(ScrW() / 2, ScrH() - He(130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if ply:IsSpeaking() then
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(voiceicon)
			surface.DrawTexturedRect(We(20), ScrH() - He(250), We(72), He(72))
		end

		if player.GetCount() == 1 and !MuR.EnableDebug and !ply:Alive() then
			draw.SimpleText(MuR.Language["waitingplayers"], "MuR_Font6", ScrW() / 2, ScrH() - He(100), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if ply:IsRolePolice() and ply:Alive() and MuR.GamemodeCount != 14 then
			local DateTime = os.date("%d/%m/%Y | %H : %M : %S", os.time())

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(axonmat)
			surface.DrawTexturedRect(ScrW() - We(150), He(8), We(128), He(128))

			draw.SimpleText("REC", "MuR_Font1", ScrW() - We(325), He(30), Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local alpha = (math.sin(RealTime() * math.pi / 0.40) + 1) * 250.5
			draw.RoundedBox(100, ScrW() - We(306), He(20), We(8), He(8), Color(255,0,0,alpha))

			draw.SimpleText("AXON BODY 3 ™", "MuR_Font1", ScrW() - We(160), He(30), Color(255,255,255,255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(DateTime, "MuR_Font1", ScrW() - We(340), He(90), Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			surface.SetFont("MuR_Font1")
			surface.SetTextColor(255, 255, 255)
			surface.SetTextPos(ScrW() - We(340), He(50))
			surface.DrawText("Officer \t|\t" ..  ply:GetNWString("Name"))
		end

		if MuR.Data["TimerActive"] and MuR.Data["TimerLeft"] and MuR.GamemodeCount != 14 then
			local isPaused = MuR.Data["TimerPaused"] or false
			local timeLeft = MuR.Data["TimerLeft"]

			if isPaused then
				if not MuR.TimerWasPaused then
					MuR.TimerPausedTime = timeLeft
					MuR.TimerWasPaused = true
				end
				timeLeft = MuR.TimerPausedTime
			else
				MuR.TimerWasPaused = false
			end

			if timeLeft > 0 then
				local minutes = math.floor(timeLeft / 60)
				local seconds = math.floor(timeLeft % 60)
				local timeText = string.format("%02d:%02d", minutes, seconds)

				local color = Color(255, 255, 255, 255)

				if isPaused then
					local alpha = math.abs(math.sin(CurTime() * 3) * 255)
					color = Color(255, 165, 0, alpha)
					timeText = timeText
				elseif timeLeft <= 15 then
					local alpha = math.abs(math.sin(CurTime() * 5) * 255)
					color = Color(255, 50, 50, alpha)
				elseif timeLeft <= 60 then
					color = Color(255, 255, 50, 255)
				end

				surface.SetFont("MuR_Font4")
				local w, h = surface.GetTextSize(timeText)

				local bgColor = Color(0, 0, 0, 150)
				if isPaused then
					bgColor = Color(50, 25, 0, 180)
				end

				draw.RoundedBox(8, ScrW() / 2 - w / 2 - 10, He(10), w + 20, h + 5, bgColor)
				draw.SimpleText(timeText, "MuR_Font4", ScrW() / 2, He(30), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end)

local lastAlive = false
local adr = 0
local tab = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "MuR_ColorHP", function()
	local client = LocalPlayer()
	if not IsValid(client) then return end

	local alive = client:Alive()
	local ft = FrameTime()

	if alive and not lastAlive then

		tab["$pp_colour_addr"] = 0
		tab["$pp_colour_colour"] = 1
		tab["$pp_colour_contrast"] = 1
	end
	lastAlive = alive

	if not alive or client:GetNW2Bool("IsUnconscious", false) then
		tab["$pp_colour_addr"] = math.Approach(tab["$pp_colour_addr"], 0, ft * 2)
		tab["$pp_colour_colour"] = math.Approach(tab["$pp_colour_colour"], 1, ft * 2)
		tab["$pp_colour_contrast"] = math.Approach(tab["$pp_colour_contrast"], 1, ft * 2)
		DrawColorModify(tab)
		if not alive then client:SetDSP(0) end
		return
	end

	local health = client:Health()
	local maxHealth = client:GetMaxHealth()

	if health < 40 then
		tab["$pp_colour_colour"] = Lerp(ft * 2, tab["$pp_colour_colour"], math.Clamp(health / 40, 0, 1))
		tab["$pp_colour_addr"] = Lerp(ft * 2, tab["$pp_colour_addr"], (40 - health) / 100)
	else
		tab["$pp_colour_colour"] = Lerp(ft * 2, tab["$pp_colour_colour"], math.Clamp((health / maxHealth) / 1.25 + 0.2, 0.1, 1))
		tab["$pp_colour_addr"] = Lerp(ft * 2, tab["$pp_colour_addr"], 0)
	end

	if client:GetNW2Bool("GeroinUsed") then
		tab["$pp_colour_colour"] = 5
	end

	local hasAdrenaline = client:GetNW2Float("AdrenalineEnd", 0) > CurTime()
	adr = Lerp(ft * 3, adr, hasAdrenaline and 1 or 0)
	tab["$pp_colour_addg"] = Lerp(ft * 6, tab["$pp_colour_addg"], 0)

	if hasAdrenaline then
		tab["$pp_colour_contrast"] = Lerp(ft * 4, tab["$pp_colour_contrast"], 1.12)
		tab["$pp_colour_colour"] = Lerp(ft * 4, tab["$pp_colour_colour"], 1.18)
	end

	local pain = (1 - (health / maxHealth)) * 100
	if client:GetNW2Bool("LegBroken") then pain = pain + 20 end
	if client:GetNW2Float("BleedLevel", 0) > 2 then pain = pain + 20 end

	if pain > 80 then
		DrawMotionBlur(0.1, 0.5, 0.01)
		local shake = (pain - 80) * 0.05
		client:SetViewPunchAngles(Angle(math.Rand(-shake, shake), math.Rand(-shake, shake), 0))
	end

	local shockLevel = client:GetNW2Int("ShockLevel", client:GetNW2Bool("ShockState", false) and 2 or 0)
	if shockLevel > 0 then
		DrawMotionBlur(0.1, 0.55 + shockLevel * 0.2, 0.01)
		tab["$pp_colour_contrast"] = Lerp(ft * 0.5, tab["$pp_colour_contrast"], 1.05 + shockLevel * 0.08)
		client:SetDSP(14)
	else
		tab["$pp_colour_contrast"] = Lerp(ft * 2, tab["$pp_colour_contrast"], 1)
		client:SetDSP(0)
	end

	DrawColorModify(tab)
end)

hook.Add("RenderScreenspaceEffects", "MuR.AdrenalineRushFX", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or adr <= 0.01 then return end

	local t = CurTime()
	local pulse = 0.5 + math.sin(t * 11) * 0.5
	local swayX = math.sin(t * 17) * adr
	local swayY = math.cos(t * 14) * adr
	local offset = adr * (1.5 + pulse * 4.5)

	DrawAdrenalineCA(
		offset * 2.4 + swayX * 3.2,
		swayX * 0.3,
		-offset * 2.4 + swayX * -3.2,
		offset * 1.1 + swayY * 1.8,
		swayY * 0.2,
		-offset * 1.1 + swayY * -1.8
	)

	DrawSharpen(0.4 + adr * 0.5, 0.18 + pulse * 0.08)
end)

net.Receive("MuR.ResetPain", function()
	tab["$pp_colour_addr"] = 0
	tab["$pp_colour_addg"] = 0
	tab["$pp_colour_addb"] = 0
	tab["$pp_colour_brightness"] = 0
	tab["$pp_colour_contrast"] = 1
	tab["$pp_colour_colour"] = 1
	tab["$pp_colour_mulr"] = 0
	tab["$pp_colour_mulg"] = 0
	tab["$pp_colour_mulb"] = 0
	adr = 0
	lastAlive = true

	if IsValid(LocalPlayer()) then
		LocalPlayer():SetDSP(0)
		LocalPlayer():SetViewPunchAngles(Angle(0, 0, 0))
	end
end)

local musicname = ""
local currentchannel = nil
function MuR:PlayMusic(music1)
	local music = "sound/"..music1
	if music1 ~= "" then
		local disable = true
		if IsValid(currentchannel) and (currentchannel:GetState() == 2 or currentchannel:GetState() == 0) then
			disable = false
		end
		if musicname == music1 and disable then
			return
		else
			if IsValid(currentchannel) then
				currentchannel:Stop()
				currentchannel = nil
			end
			timer.Simple(1, function()
				sound.PlayFile(music, "noblock", function(station, s1, s2)
					if IsValid(station) then
						station:Play()
						station:SetVolume(GetConVar("snd_musicvolume"):GetFloat())
						currentchannel = station
					end
				end)
			end)
		end

		musicname = music1
	else
		musicname = ""
		if IsValid(currentchannel) then
			currentchannel:Stop()
			currentchannel = nil
		end
	end
end
hook.Add("Think", "MuR.MusicVolume", function()
	if IsValid(currentchannel) then
		currentchannel:SetVolume(GetConVar("snd_musicvolume"):GetFloat())
	end
end)

local function ShowAnnounce(type, ent)
	if MuR.EnableDebug then return end

	local pos = -100
	local start = true
	local text = ""
	local font = "MuR_Font3"

	if type == "you_killer" then
		text = MuR.Language["announce_traitor"]
	elseif type == "you_defender" then
		text = MuR.Language["announce_defender"]
	elseif type == "you_zombie" then
		text = MuR.Language["announce_zombie"]
	elseif type == "innocent_kill" then
		text = MuR.Language["announce_innokill"]
		font = "MuR_Font2"
		surface.PlaySound("npc/attack_helicopter/aheli_damaged_alarm1.wav")
	elseif type == "innocent_att_kill" then
		text = MuR.Language["announce_attkill"]
		font = "MuR_Font2"
	elseif type == "money_cancel" then
		text = MuR.Language["announce_moneycancel"]
		font = "MuR_Font2"
	elseif type == "spawn_damage" then
		text = MuR.Language["announce_spawndamage"]
		font = "MuR_Font2"
		surface.PlaySound("ambient/alarms/warningbell1.wav")
	elseif type == "officer_spawn" then
		text = MuR.Language["announce_officerspawn"]
		font = "MuR_Font2"
	elseif type == "arrested" then
		text = MuR.Language["announce_arrested"]
		font = "MuR_Font2"
	elseif type == "officer_killer" then
		text = MuR.Language["announce_officerguilt"]
		font = "MuR_Font2"
	elseif type == "officerguilt2" then
		text = MuR.Language["announce_officerguilt2"]
		font = "MuR_Font2"
	elseif type == "headhunter_kill" then
		text = MuR.Language["headhunter_kill"]
		font = "MuR_Font2"
		surface.PlaySound("murdered/vgui/buy.wav")
	elseif type == "headhunter_killed" then
		text = MuR.Language["headhunter_killed"]
		font = "MuR_Font2"
	end

	timer.Simple(6, function()
		start = false
	end)

	hook.Add("HUDPaint", "ShowAnnounceMuR", function()
		if start then
			pos = math.Clamp(pos + FrameTime() / 0.001, -100, 300)
		else
			pos = math.Clamp(pos - FrameTime() / 0.001, -100, 300)

			if pos == -100 then
				hook.Remove("HUDPaint", "ShowAnnounceMuR")
			end
		end

		draw.SimpleText(text, font, ScrW() / 2, He(pos), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end)
end

net.Receive("MuR.Announce", function()
	local str = net.ReadString()
	ShowAnnounce(str)
end)

local function Internal_ShowMessage(type, ent, callback)
	local alpha = 0
	local start = true
	local text = ""
	local font = "MuR_Font1"

	local phrase = MuR:GetPhrase(type)
	if phrase and phrase ~= "" then
		text = phrase
		font = "MuR_Font1"
		if type == "weapon_break" or type == "mindcontroller_used" then
			font = "MuR_Font2"
		end
	elseif type == "geroin_use" then
		text = MuR.Language["message_heroinuse"]
		font = "MuR_Font1"
	elseif type == "geroin_use_target" then
		text = MuR.Language["message_targetheroinuse"]
		font = "MuR_Font1"
	elseif type == "cyanide_use_target" then
		text = MuR.Language["message_targetcyanideuse"]
		font = "MuR_Font1"
	elseif type == "poison_use" then
		text = MuR.Language["message_poisonuse"]
		font = "MuR_Font1"
	elseif type == "ied_connected" then
		text = MuR.Language["loot_ied_4"]
		font = "MuR_Font1"
	elseif type == "targetbredogenuse" then
		text = MuR.Language["message_targetbredogenuse"]
		font = "MuR_Font1"
	elseif type == "mindcontroller_used" then
		text = MuR.Language["message_mindcontroller_used"]
		font = "MuR_Font3"
	else
		text = MuR.Language["message_"..type] or ""
		font = "MuR_Font1"
	end

	timer.Simple(5, function()
		start = false
	end)

	hook.Add("HUDPaint", "ShowMessageMuR", function()
		if not LocalPlayer():Alive() then
			hook.Remove("HUDPaint", "ShowMessageMuR")
			if callback then callback() end
			return
		end

		if start then
			alpha = math.Clamp(alpha + FrameTime() / 0.002, 0, 255)
		else
			alpha = math.Clamp(alpha - FrameTime() / 0.002, 0, 255)

			if alpha == 0 then
				hook.Remove("HUDPaint", "ShowMessageMuR")
				if callback then callback() end
			end
		end

		if !MuR:GetClient("blsd_nohud") then
			surface.SetFont(font)
			local tw, th = surface.GetTextSize(text)
			local bx, by = ScrW() / 2, ScrH() / 2 + He(200)
			local padding = He(8)

			surface.SetDrawColor(0, 0, 0, alpha * 0.5)
			surface.DrawRect(bx - tw/2 - padding, by - th/2 - padding, tw + padding*2, th + padding*2)

			draw.SimpleText(text, font, bx, by, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end)
end

MuR.ActiveMessages2 = MuR.ActiveMessages2 or {}
local layerScales = {1.0, 1/1.5, 1/2, 1/2.5, 1/3}

local function Internal_ShowMessage2(type, callback)
	local text = ""
	local font = "MuR_Font2"
	local speed = 0.02

	local phrase = MuR:GetPhrase(type)
	if phrase and phrase ~= "" then
		text = phrase
		font = "MuR_Font1"
		if type == "highbleed" or type == "criticalbleed" or type == "artery" or type == "artery_hit" or type == "brain_hit" or type == "heart_hit" or type == "neck_hit" or type == "spine_hit" or type == "artery_neck_hit" or type == "artery_heart_hit" or type == "liver_hit" or type == "lung_hit" or type == "eye_hit" or type == "stomach_hit" or type == "internal_hit" or type == "artery_arm_hit" or type == "artery_leg_hit" or type == "rib_hit" or type == "leg_fracture" or type == "arm_fracture" or type == "jaw_fracture" or type == "pelvis_fracture" then
			font = "MuR_Font2"
		end
		if type == "leg_dislocation" or type == "arm_dislocation" or type == "jaw_dislocation" or type == "dislocation_fixed" or type == "dislocation_fail" then
			font = "MuR_Font1"
		end
        if type == "unconscious_state" or type == "random_unconscious" then
            font = "MuR_Font3"
        end
	elseif type == "neck_hit" or type == "lung_hit" or type == "heart_hit" or type == "artery_neck_hit" or type == "artery_heart_hit" then
		text = MuR:GetPhrase("sharp_pain")
		font = "MuR_Font2"
	elseif type == "leg_hit" or type == "arm_hit" or type == "down_hit" then
		text = MuR:GetPhrase("audible_pain")
		font = "MuR_Font1"
	elseif type == "brain_hit" then
		text = MuR:GetPhrase("braindamage")
		font = "MuR_Font3"
	elseif type == "concussion_hit" then
		text = MuR:GetPhrase("slight_braindamage")
		font = "MuR_Font1"
	elseif type == "shock_state" then
		text = MuR:GetPhrase("fear_phrases")
		font = "MuR_Font2"
	elseif type == "broken_bone" or type == "rib_hit" then
		text = MuR:GetPhrase("broken_limb")
		font = "MuR_Font2"
	else
		text = MuR.Language[type] or ""
		font = "MuR_Font1"
	end

	if text == "" then text = "..." end

	local ply = LocalPlayer()
	if IsValid(ply) then
		if ply:GetNW2Float("AdrenalineEnd", 0) > CurTime() then
			speed = 0.012
		else
			local hp = ply:Health() / math.max(ply:GetMaxHealth(), 1)
			if hp <= 0.4 or ply:GetNW2Bool("HardBleed", false) or ply:GetNW2Float("BleedLevel", 0) >= 2 or ply:GetNW2Int("ShockLevel", 0) >= 2 or ply:GetNW2Int("ConsciousLevel", 0) >= 2 or ply:GetNW2Float("ConcussionEnd", 0) > CurTime() then
				speed = 0.04
			end
		end
	end

	local chars = {}
	for p, c in utf8.codes(text) do table.insert(chars, utf8.char(c)) end

    local msg = {
        text = text,
        font = font,
        chars = chars,
        charCount = #chars,
        revealSpeed = speed,
        startTime = CurTime(),
        start = true,
        vanishStart = nil
    }

    table.insert(MuR.ActiveMessages2, 1, msg)
    if #MuR.ActiveMessages2 > 5 then
        table.remove(MuR.ActiveMessages2)
    end

	timer.Simple(5, function()
        msg.start = false
        msg.vanishStart = CurTime()
    end)

    if callback then callback() end
end

hook.Add("HUDPaint", "ShowMessageMuR2_Layered", function()
    if MuR:GetClient("blsd_nohud") then return end
    if #MuR.ActiveMessages2 == 0 then return end
	if not LocalPlayer():Alive() then
		MuR.MessageQueue = {}
		MuR.MessageActive = false
		MuR.ActiveMessages2 = {}
		return
	end

    local bx, by = ScrW() / 2, ScrH() / 2 + He(250)
    local padding = He(8)
    local hideSpeed = 0.02

    for i = #MuR.ActiveMessages2, 1, -1 do
        local msg = MuR.ActiveMessages2[i]
        local scale = layerScales[i] or 0
        local revealSpeed = msg.revealSpeed or 0.02
        if scale <= 0 then
            table.remove(MuR.ActiveMessages2, i)
            continue
        end

        local shown = 0
        if msg.start then
            shown = math.min(math.floor((CurTime() - msg.startTime) / revealSpeed) + 1, msg.charCount)
        else
            if msg.vanishStart then
                local gone = math.floor((CurTime() - msg.vanishStart) / hideSpeed)
                shown = math.max(msg.charCount - gone, 0)
            else
                shown = msg.charCount
            end
        end

        if shown <= 0 and not msg.start then
            table.remove(MuR.ActiveMessages2, i)
            continue
        end

        local partial = ""
        for j = 1, shown do
            if msg.chars[j] then partial = partial .. msg.chars[j] end
        end

        surface.SetFont(msg.font)
        local tw, th = surface.GetTextSize(partial)

        local yOffset = 0
        for k = 1, i - 1 do
            yOffset = yOffset + (He(40) * layerScales[k])
        end
        local y = by - yOffset

        surface.SetDrawColor(0, 0, 0, 100 * scale)
        surface.DrawRect(bx - (tw*scale)/2 - padding*scale, y - (th*scale)/2 - padding*scale, tw*scale + padding*2*scale, th*scale + padding*2*scale)

        drawTextRotated(partial, msg.font, bx, y, Color(255, 255, 255, 255 * scale), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0, scale, scale)
    end
end)

MuR.MessageQueue = MuR.MessageQueue or {}
MuR.MessageActive = false

local function ProcessQueue()
	if not LocalPlayer():Alive() then
		MuR.MessageQueue = {}
		MuR.MessageActive = false
		MuR.ActiveMessages2 = {}
		hook.Remove("HUDPaint", "ShowMessageMuR")
		return
	end

	if MuR.MessageActive then return end
	if #MuR.MessageQueue == 0 then return end

	local msg = table.remove(MuR.MessageQueue, 1)
	MuR.MessageActive = true

	if msg.func == "ShowMessage" then
		Internal_ShowMessage(msg.type, msg.ent, function()
			MuR.MessageActive = false
			ProcessQueue()
		end)
	elseif msg.func == "ShowMessage2" then
		Internal_ShowMessage2(msg.type, function()
			MuR.MessageActive = false
			ProcessQueue()
		end)
	end
end

local function ShowMessage(type, ent)
	table.insert(MuR.MessageQueue, {func = "ShowMessage", type = type, ent = ent})
	ProcessQueue()
end

net.Receive("MuR.Message", function()
	local str = net.ReadString()
	ShowMessage(str)
end)

local function ShowMessage2(type)
	if not LocalPlayer():Alive() then
		MuR.MessageQueue = {}
		MuR.MessageActive = false
		MuR.ActiveMessages2 = {}
		return
	end

	table.insert(MuR.MessageQueue, {func = "ShowMessage2", type = type})
	ProcessQueue()
end

net.Receive("MuR.Message2", function()
	local str = net.ReadString()
	if not LocalPlayer():Alive() then
		MuR.MessageQueue = {}
		MuR.MessageActive = false
		MuR.ActiveMessages2 = {}
		return
	end

	ShowMessage2(str)
end)

local notifyTypeMap = {
	[0] = NOTIFY_GENERIC,
	[1] = NOTIFY_HINT,
	[2] = NOTIFY_ERROR,
	[3] = NOTIFY_ERROR
}

local notifySoundMap = {
	[0] = "garrysmod/content_downloaded.wav",
	[1] = "buttons/button15.wav",
	[2] = "buttons/button10.wav",
	[3] = "buttons/button10.wav"
}

net.Receive("MuR.Notify", function()
	if MuR:GetClient("blsd_nohud") then return end
	local text = net.ReadString()
	local level = net.ReadUInt(3)
	local trimmed = string.Trim(text or "")
	if trimmed == "" then return end
	level = math.Clamp(level or 0, 0, 3)
	local notifyType = notifyTypeMap[level] or NOTIFY_GENERIC
	notification.AddLegacy(trimmed, notifyType, 4)
	local snd = notifySoundMap[level]
	if snd then surface.PlaySound(snd) end
end)

local nextBleedNotify = 0
local lastBleedStage = -1
hook.Add("Think", "MuR.BleedMessageNotifier", function()
	if MuR:GetClient("blsd_nohud") then return end
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local minor = ply:GetNW2Int("MinorBleedWounds", 0)
	local deep = ply:GetNW2Int("DeepBleedWounds", 0)
	local arterial = ply:GetNW2Int("ArterialBleedWounds", 0)
	local arterialFlags = ply:GetNW2Bool("Artery_Neck", false) or ply:GetNW2Bool("Artery_Heart", false)
		or ply:GetNW2Bool("Artery_ArmLeft", false) or ply:GetNW2Bool("Artery_ArmRight", false)
		or ply:GetNW2Bool("Artery_LegLeft", false) or ply:GetNW2Bool("Artery_LegRight", false)
	local stage = 0

	if arterial > 0 or arterialFlags then
		stage = 4
	elseif deep >= 2 then
		stage = 3
	elseif deep >= 1 then
		stage = 2
	elseif minor >= 1 then
		stage = 1
	end
	if stage == 0 then
		lastBleedStage = 0
		return
	end
	local t = CurTime()
	if stage ~= lastBleedStage then
		nextBleedNotify = 0
		lastBleedStage = stage
	end
	if t < nextBleedNotify then return end
	local key
	if stage == 1 then key = "smallbleed" elseif stage == 2 then key = "mediumbleed" elseif stage == 3 then key = "highbleed" elseif stage == 4 then key = "criticalbleed" end
	if key then
		ShowMessage2(key)
		local base = 14 - stage * 2
		nextBleedNotify = t + base + math.Rand(0,4)
	end
end)

local function Countdown(num, type)
	local alpha = 255
	if MuR.EnableDebug then return end
	for i = 0, num - 1 do
		timer.Simple(i, function()
			alpha = 255
			surface.PlaySound("buttons/lightswitch2.wav")

			hook.Add("HUDPaint", "MuRHUDTimer", function()
				alpha = math.max(alpha - FrameTime() / 0.004, 0)

				if alpha == 0 then
					hook.Remove("HUDPaint", "MuRHUDTimer")
				end

				draw.SimpleTextOutlined(num - i, "MuR_Font6", ScrW() / 2, He(250), Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0, alpha))
			end)
		end)
	end
end

net.Receive("MuR.Countdown", function()
	local f = net.ReadFloat()
	Countdown(f)
end)

local killerBloodIcon = Material("murdered/blood.png", "smooth")
local killerStartScreenAt

hook.Add("HUDPaint", "MuR.KillerSpawnWait", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:GetNW2Bool("MuR.AwaitingKillerSpawn") then return end
	if killerStartScreenAt and CurTime() - killerStartScreenAt < 12 then return end

	local w, h = ScrW(), ScrH()

	surface.SetDrawColor(0, 0, 0)
	surface.DrawRect(0, 0, w, h)

	local remain = math.ceil(math.max(lp:GetNW2Float("MuR.KillerSpawnAt", 0) - CurTime(), 0))
	local text = string.format(MuR.Language["killer_spawn_in"] or "%d", remain)

	local iconSize = He(52)
	surface.SetMaterial(killerBloodIcon)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(w / 2 - iconSize / 2, He(540) - iconSize - He(20), iconSize, iconSize)

	draw.SimpleTextOutlined(text, "MuR_Font6", w / 2, He(540), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)

hook.Add("AdjustMouseSensitivity", "Murdered", function(speed)
	if LocalPlayer():IsSprinting() and not LocalPlayer():GetNW2Entity("RD_Ent") then return 0.3 end
end)

local viewbob_speed = 10
local viewbob_amount = 0.01
local viewbob_offset = 0
local last_velocity = 0

hook.Add("CalcView", "ViewBob", function(ply, pos, angles, fov)
	if MuR.CutsceneActive then return end

	local wep = ply:GetActiveWeapon()
	local allow = true
	if IsValid(wep) or IsValid(ply:GetNW2Entity("RD_EntCam")) or ply:GetSVAnimation() ~= "" or !IsValid(ply:GetActiveWeapon()) then allow = false end

	if ply:Alive() and not ply:ShouldDrawLocalPlayer() and allow then
		local velocity = ply:GetVelocity():Length()
		local head_z = 0
		local eyes = ply:GetAttachment(ply:LookupAttachment("eyes"))
		local draws = false
		head_z = math.Clamp(eyes.Ang.z/5, -45, 45)

		if velocity > 0 and last_velocity == 0 then
			viewbob_offset = 0
		end

		last_velocity = velocity

		viewbob_offset = viewbob_offset + (viewbob_speed * FrameTime())
		local bob_x = math.sin(viewbob_offset) * viewbob_amount * last_velocity
		local bob_y = math.cos(viewbob_offset) * viewbob_amount * last_velocity
		angles.roll = angles.roll + bob_y / 2
		angles.x = angles.x + bob_x / 4
		angles.z = head_z

		local view = {}
		view.origin = pos
		view.angles = angles
		view.fov = fov
		view.drawviewer = draws

		return view
	end
end)

hook.Add("HUDPaint", "MuR_ShowcaseTeammates", function()
	if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") then return end
	if MuR.GamemodeCount == 5 or MuR.GamemodeCount == 14 or MuR.GamemodeCount == 19 or MuR.GamemodeCount == 15 or MuR.GamemodeCount == 25 then return end

	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end

	local lpPos = lp:GetPos()
	local time = CurTime()

	for _, ply in player.Iterator() do
		if ply == lp then continue end
		if not ply:Alive() then continue end

		local isAlly = MuR:ArePlayersAllies(lp, ply)
		local isTarget = IsValid(lp:GetNW2Entity("CurrentTarget")) and lp:GetNW2Entity("CurrentTarget") == ply
		local isSpectating = lp:GetObserverMode() > 0 and lp:GetObserverTarget() ~= ply

		if not isAlly and not isTarget and not isSpectating then continue end

		local plyPos = ply:GetPos()
		local dist = lpPos:Distance(plyPos)
		local eyePos = ply:EyePos() + Vector(0, 0, 10)
		local screenPos = eyePos:ToScreen()

		if not screenPos.visible then continue end

		local canSee = lp:IsLineOfSightClear(ply)
		local sx, sy = screenPos.x, screenPos.y

		if isSpectating then
			draw.SimpleTextOutlined(ply:Nick(), "MuR_FontDef", sx, sy, Color(225, 225, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0))
			continue
		end

		if not canSee then continue end

		if isAlly then
			local hp = ply:Health()
			local maxHp = ply:GetMaxHealth()
			local hpFrac = math.Clamp(hp / maxHp, 0, 1)
			local name = ply:GetNWString("Name", ply:Nick())
			local distMeters = math.floor(dist / 40)

			local pulseAlpha = 200 + math.sin(time * 3) * 55
			local baseAlpha = math.Clamp(255 - dist * 0.05, 100, 255)

			local hpColor
			if hpFrac > 0.6 then
				hpColor = Color(60, 200, 60, baseAlpha)
			elseif hpFrac > 0.3 then
				hpColor = Color(220, 180, 40, baseAlpha)
			else
				hpColor = Color(220, 60, 60, pulseAlpha)
			end

			local bgColor = Color(0, 0, 0, baseAlpha * 0.5)
			local frameColor = Color(60, 180, 60, baseAlpha * 0.8)

			local barW, barH = 40, 1
			local barX, barY = sx - barW / 2, sy - 24

			if MuR.GamemodeCount == 6 or MuR.GamemodeCount == 18 then
				surface.SetDrawColor(bgColor)
				surface.DrawRect(barX - 1, barY - 1, barW + 2, barH + 2)

				surface.SetDrawColor(frameColor)
				surface.DrawOutlinedRect(barX - 1, barY - 1, barW + 2, barH + 2, 1)

				surface.SetDrawColor(hpColor)
				surface.DrawRect(barX, barY, barW * hpFrac, barH)
			end

			draw.SimpleTextOutlined(name, "MuR_Font1", sx, sy, Color(200, 255, 200, baseAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, baseAlpha * 0.8))

			local roleText = MuR.Language["teammate"] or "ALLY"
			draw.SimpleText(roleText, "MuR_FontDef", sx, sy, Color(60, 180, 60, baseAlpha * 0.7), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			if dist > 400 then
				draw.SimpleText(distMeters .. "m", "MuR_FontDef", sx, sy + 12, Color(150, 150, 150, baseAlpha * 0.6), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
		end

		if isTarget then
			local pulseScale = 1 + math.sin(time * 4) * 0.1
			local targetAlpha = 180 + math.sin(time * 6) * 75
			local targetColor = Color(255, 195, 0, targetAlpha)

			local size = 16 * pulseScale

			surface.SetDrawColor(targetColor)
			surface.DrawLine(sx - size, sy, sx - size / 2, sy)
			surface.DrawLine(sx + size / 2, sy, sx + size, sy)
			surface.DrawLine(sx, sy - size, sx, sy - size / 2)
			surface.DrawLine(sx, sy + size / 2, sx, sy + size)

			draw.SimpleText(MuR.Language["target"] or "TARGET", "MuR_Font1", sx, sy + 24, targetColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end
end)

hook.Add("PreDrawHalos", "DrawLootHalo", function()
	if !MuR:GetClient("blsd_nohud") then return end
	local ply = LocalPlayer()
	local pos = ply:GetPos()
	local entsInRange = ents.FindInSphere(pos, 128)
	local lootEnts, wepsEnts = {}, {}

	for i = 1, #entsInRange do
		local ent = entsInRange[i]

		if string.match(ent:GetClass(), "mur_") and not IsValid(ent:GetOwner()) and not ent:GetNoDraw() then
			if ent.Melee or ent:IsWeapon() and ent:GetMaxClip1() > 0 then
				table.insert(wepsEnts, ent)
			else
				table.insert(lootEnts, ent)
			end
		end
	end

	halo.Add(lootEnts, Color(200, 200, 0), 2, 2, 1, true, false)
	halo.Add(wepsEnts, Color(255, 0, 0), 2, 2, 1, true, false)
end)

function MuR:ShowStartScreen(gamemode, class)
	if MuR.EnableDebug then return end
    MuR.DrawHUD = false

    local themeSound = "murdered/theme/theme_gamemode" .. gamemode .. ".mp3"
    if not file.Exists("sound/" .. themeSound, "GAME") then
        themeSound = "murdered/theme/theme_gamemode1.mp3"
    end
    surface.PlaySound(themeSound)

	if gamemode == 2 and class == "Shooter" then
		RunConsoleCommand("stopsound")
	end
    MuR.GamemodeCount = gamemode
    local ply = LocalPlayer()

    if not class then
        class = ply:GetNW2String("Class")
    end

	local gamemodeDel, gamemodeDelNum = CurTime(), math.random(0,1)
	local gamemodeBG = Material("murdered/modes/gamemode" .. gamemode .. ".png", "")
	local gamemodeBG2 = Material("murdered/modes/gamemode" .. gamemode .. "h.png", "")
	local gamemodeData = {name = "gamename"..gamemode, desc = "gamedesc"..gamemode}
	if gamemodeBG:IsError() and gamemode != 14 then
		gamemodeBG = Material("murdered/black.png", "")
		gamemodeBG2 = Material("murdered/black.png", "")
	end

    local alpha = 300
    local alphago = false
    local lerppos = -We(400)
    local needlerppos = 0
    local rotationAngle = 0
    local pulseEffect = 0
    local versionY = -He(100)
    local versionScale = 0
    local particles = {}

    for i = 1, 30 do
        particles[i] = {
            x = math.random(0, ScrW()),
            y = math.random(0, ScrH()),
            size = math.random(1, 4),
            speed = math.random(10, 30),
            alpha = math.random(50, 150)
        }
    end

    local roleData = MuR:GetRole(class) or MuR:GetRole("Civilian")
    local classData = {
        name = roleData.langName,
        color = roleData.color,
        desc = roleData.desc,
        other = roleData.other or ""
    }
	local sizeX, sizeY = ScrW()*1.1, ScrH()*1.1
	local size2X, size2Y = ScrW(), ScrH()
	local stX, stY = (ScrW()-sizeX)/2, (ScrH()-sizeY)/2
	local offX, offY = stX, stY
	local off2X, off2Y = 0, 0

    timer.Simple(10, function()
        alphago = true
        needlerppos = We(250)
    end)

    hook.Add("HUDPaint", "MurderedStartScreen", function()
        local curTime = CurTime()

		if gamemode == 14 and gamemodeDel < CurTime() then
			gamemodeDel = CurTime()+0.4
			gamemodeDelNum = math.abs(gamemodeDelNum-1)
			gamemodeBG = Material("murdered/modes/gamemode14_" .. gamemodeDelNum .. ".png", "")
		end

        if alphago then
            alpha = math.min(alpha + FrameTime() / 0.005, 255)
            lerppos = Lerp(FrameTime()/4, lerppos, needlerppos)
            versionY = Lerp(FrameTime()/3, versionY, He(500))
            versionScale = Lerp(FrameTime()/3, versionScale, 1)
        else
            alpha = math.max(alpha - FrameTime() / 0.015, 0)
            lerppos = Lerp(FrameTime(), lerppos, needlerppos)
            versionY = Lerp(FrameTime()/2, versionY, He(530))
            versionScale = Lerp(FrameTime()/2, versionScale, 0.85)
        end

        rotationAngle = math.sin(curTime * 0.5) * 2
        pulseEffect = math.sin(curTime * 3) * 5

        local classname = MuR.Language[classData.name]
        local otherdesc = MuR.Language[classData.other] or ""
        local desc = MuR.Language[classData.desc]
        local color = classData.color
        local gamename = MuR.Language[gamemodeData.name]
        local gamedesc = MuR.Language[gamemodeData.desc]

        local pulsingColor = color

        local titleColorPulse = Color(
            200 + math.sin(curTime*3)*25,
            175 + math.cos(curTime*3)*25,
            math.abs(math.sin(curTime*2.5))*25,
            255
        )

		local scrW, scrH = ScrW(), ScrH()
		local t = CurTime()

		local bg_sway = 30
		local bg_speed_x = 0.4
		local bg_speed_y = 0.6

		local char_sway = 60
		local char_speed_x = 0.5
		local char_speed_y = 0.5

		local idealX = (scrW - sizeX) / 2 + math.sin(t * bg_speed_x) * bg_sway
		local idealY = (scrH - sizeY) / 2 + math.cos(t * bg_speed_y) * bg_sway

		offX = math.Clamp(idealX, scrW - sizeX, 0)
		offY = math.Clamp(idealY, scrH - sizeY, 0)

		local ideal2X = (scrW - size2X) / 2 + math.sin(t * char_speed_x) * char_sway
		local ideal2Y = (scrH - size2Y) / 2 + math.cos(t * char_speed_y) * char_sway

		off2X = math.Clamp(ideal2X, -scrW/4, scrW/4)
		off2Y = math.Clamp(ideal2Y, 0, scrH/4)

		surface.SetDrawColor(0, 0, 0)
		surface.DrawRect(0, 0, scrW, scrH)

		surface.SetMaterial(gamemodeBG)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(offX, offY, sizeX, sizeY)

		surface.SetMaterial(gamemodeBG2)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(off2X, off2Y, size2X, size2Y)

        surface.SetDrawColor(pulsingColor.r, pulsingColor.g, pulsingColor.b, 5)
        surface.SetMaterial(vinmat)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

        for i = 1, #particles do
            local p = particles[i]
            p.y = (p.y + p.speed * FrameTime()) % ScrH()

            surface.SetDrawColor(color.r, color.g, color.b, p.alpha)
            surface.DrawRect(p.x, p.y, p.size, p.size)
        end

        local centerX = ScrW() / 2 + lerppos

        local gamemodeFullText = MuR.Language["startscreen_gamemode"] .. gamename
        drawTextRotated(gamemodeFullText, "MuR_Font6",
            centerX,
            ScrH() / 2 - He(450) + math.sin(curTime*1.5)*He(8),
            titleColorPulse,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            rotationAngle)

		local col = Color(255, 255, 255, 220 + pulseEffect*10)
		if gamemode == 9 then
			col = Color(0, 0, 0, 200 + pulseEffect*10)
		end
		drawTextRotated(gamedesc, "MuR_Font2",
            centerX + math.cos(curTime)*We(10),
            ScrH() / 2 - He(400) + math.sin(curTime)*He(5),
            col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			rotationAngle)

        local roleY = ScrH() / 2 - He(60 + pulseEffect)
        draw.SimpleText(MuR.Language["startscreen_role"], "MuR_Font5",
            centerX, roleY, col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local sizeMultiplier = 1.0 + math.abs(math.sin(curTime*2))*0.1
        local classX = centerX
        local classY = ScrH() / 2

        drawTextRotated(classname, "MuR_Font6",
            classX, classY,
            pulsingColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            math.sin(curTime*0.7)*3,
            sizeMultiplier, sizeMultiplier)

        if otherdesc ~= "" then
            drawTextRotated(otherdesc, "MuR_Font2",
                centerX,
                ScrH() / 2 + He(35),
                Color(150, 150, 250, 200 + math.sin(curTime*2)*55),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
				math.sin(curTime*0.7)*3,
				sizeMultiplier, sizeMultiplier)
        end

        draw.SimpleText(desc, "MuR_Font2",
            centerX,
            ScrH() / 2 + He(350) + math.sin(curTime)*He(8),
            color_white,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        surface.SetDrawColor(0, 0, 0, alpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end)

    timer.Simple(12, function()
        if IsValid(ply) then
            ply:ScreenFade(SCREENFADE.IN, color_black, 1, 0)
        end

        MuR.DrawHUD = true
        hook.Remove("HUDPaint", "MurderedStartScreen")
    end)
end

function drawTextRotated(text, font, x, y, color, alignX, alignY, angle, scaleX, scaleY)
	render.PushFilterMag( TEXFILTER.ANISOTROPIC )
    render.PushFilterMin( TEXFILTER.ANISOTROPIC )

    scaleX = scaleX or 1
    scaleY = scaleY or scaleX

    local m = Matrix()
	m:Translate(Vector(x, y, 0))
    m:SetAngles(Angle(0, angle, 0))
    m:SetScale(Vector(scaleX, scaleY, 1))

	surface.SetFont(font)
	local w, h = surface.GetTextSize(text)
	m:Translate(Vector( -w / 2, -h / 2, 0 ))

    cam.PushModelMatrix(m, true)
        draw.SimpleText(text, font, w/2, h/2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.PopModelMatrix()

	render.PopFilterMag()
    render.PopFilterMin()
end

net.Receive("MuR.StartScreen", function()
	local float = net.ReadFloat()
	local str = net.ReadString()
	killerStartScreenAt = CurTime()
	MuR:ShowStartScreen(float, str)
end)

net.Receive("MuR.SyncGamemode", function()
	MuR.GamemodeCount = net.ReadInt(8)
end)

function GM:HUDDrawTargetID()
end

function GM:HUDDrawPickupHistory()
end

local function CreateFonts()
	surface.CreateFont("MuR_FontDef", {
		font = "ChicagoFLF",
		extended = true,
		size = He(12),
		antialias = true
	})

	surface.CreateFont("MuR_Font0", {
		font = "ChicagoFLF",
		extended = true,
		size = He(12),
		antialias = true
	})

	surface.CreateFont("MuR_Font1", {
		font = "ChicagoFLF",
		extended = true,
		size = He(16),
		antialias = true
	})

	surface.CreateFont("MuR_Font2", {
		font = "ChicagoFLF",
		extended = true,
		size = He(24),
		antialias = true
	})

	surface.CreateFont("MuR_Font3", {
		font = "ChicagoFLF",
		extended = true,
		size = He(32),
		antialias = true
	})

	surface.CreateFont("MuR_Font4", {
		font = "ChicagoFLF",
		extended = true,
		size = He(40),
		antialias = true
	})

	surface.CreateFont("MuR_Font5", {
		font = "ChicagoFLF",
		extended = true,
		size = He(48),
		antialias = true
	})

	surface.CreateFont("MuR_Font6", {
		font = "ChicagoFLF",
		extended = true,
		size = He(56),
		antialias = true
	})

	surface.CreateFont("MuR_Font_NZ1", {
		font = "Exo",
		extended = true,
		size = He(24),
		antialias = true
	})

	surface.CreateFont("MuR_Font_NZ2", {
		font = "Exo",
		extended = true,
		size = He(32),
		antialias = true
	})

	surface.CreateFont("MuR_Font_NZ3", {
		font = "Exo",
		extended = true,
		size = He(40),
		antialias = true
	})

	surface.CreateFont("MuR_Font_NZ5", {
		font = "Exo",
		extended = true,
		size = He(56),
		antialias = true
	})

	surface.CreateFont("MuR_Font_NZ_Big", {
		font = "Brutalworld",
		extended = true,
		size = He(172),
		antialias = true
	})

end
CreateFonts()
hook.Add("OnScreenSizeChanged", "MuR.Fonts", function()
	CreateFonts()
end)
