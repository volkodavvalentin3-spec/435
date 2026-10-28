local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local function L(key, fallback)
	return (MuR.Language and MuR.Language[key]) or fallback or key
end

hook.Add("HUDPaint", "MuR.Mode24HUD", function()
	if MuR.GamemodeCount ~= 24 then return end
	if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local w, h = ScrW(), ScrH()

	local wave = MuR.Data["Mode24Wave"] or 0
	local phase = MuR.Data["Mode24Phase"] or "prep"
	local phaseEnd = MuR.Data["Mode24PhaseEnd"] or 0

	local waveText
	if phase == "prep" and phaseEnd > CurTime() then
		local left = math.max(0, math.ceil(phaseEnd - CurTime()))
		waveText = string.format("%s %d — %s: %ds", L("mode24_wave", "WAVE"), wave + 1, L("mode24_prepare", "PREPARING"), left)
	else
		waveText = string.format("%s %d", L("mode24_wave", "WAVE"), wave)
	end

	draw.SimpleTextOutlined(waveText, "MuR_Font2", w / 2, h * 0.06, Color(220, 220, 220, 255),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))

	if ply:GetNW2String("Class") == "PMCCommander" then
		local points = ply:GetNWInt("MuR_Mode24Points", 0)
		draw.SimpleTextOutlined("$" .. points, "MuR_Font3", w / 2, h * 0.06 + He(28), Color(120, 220, 120, 255),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
	end
end)

local function discoverTracks(letter)
	local files = file.Find("sound/murdered/theme/amb/" .. letter .. "*.ogg", "GAME")
	local out = {}
	for _, f in ipairs(files) do
		out[#out + 1] = "sound/murdered/theme/amb/" .. f
	end
	return out
end

local trackPools = {
	c = discoverTracks("c"),
	a = discoverTracks("a"),
	l = discoverTracks("l")
}

local function poolFor(state)
	local pool = trackPools[state]
	if pool and #pool > 0 then return pool end
	return trackPools.a
end

local currentTrack = nil
local trackChannel = nil
local currentState = "a"
local nextMusicSwitch = 0
local mdelay = 0

local function PlayMusic(track)
	if trackChannel then
		trackChannel:SetVolume(0)
		trackChannel:Stop()
	end

	sound.PlayFile(track, "noplay", function(station)
		if IsValid(station) then
			station:SetVolume(0)
			station:Play()
			trackChannel = station
		end
	end)
end

local function SelectMusic()
	if mdelay > CurTime() then return end
	mdelay = CurTime() + 0.1

	local tracks = poolFor(currentState)
	if #tracks == 0 then return end

	local selected = tracks[math.random(#tracks)]

	if selected ~= currentTrack and CurTime() >= nextMusicSwitch then
		nextMusicSwitch = CurTime() + 1

		if trackChannel then
			local fadeOutTime = 1
			local fadeTimer = 0
			local targetVolume = IsValid(trackChannel) and trackChannel:GetVolume() or 0

			hook.Add("Think", "Mode24MusicFadeOut", function()
				if not IsValid(trackChannel) then
					hook.Remove("Think", "Mode24MusicFadeOut")
					return
				end

				fadeTimer = fadeTimer + FrameTime()
				local volume = math.max(targetVolume * (1 - fadeTimer / fadeOutTime), 0)
				trackChannel:SetVolume(volume)

				if volume <= 0 then
					trackChannel:Stop()
					hook.Remove("Think", "Mode24MusicFadeOut")

					sound.PlayFile(selected, "noplay", function(station)
						if IsValid(station) then
							currentTrack = selected
							station:SetVolume(0)
							station:Play()
							trackChannel = station
						end
					end)
				end
			end)
		else
			currentTrack = selected
			PlayMusic(currentTrack)
		end
	end
end

local function IsHeavyLosses()
	local active, total = 0, 0
	local commanderDown = false

	for _, ply in player.Iterator() do
		total = total + 1

		local down = not ply:Alive() or ply:GetNW2Bool("MuR.Dying", false) or ply:GetNW2Bool("IsUnconscious", false)
		if not down then active = active + 1 end

		if ply:GetNW2String("Class") == "PMCCommander" and down then
			commanderDown = true
		end
	end

	if total == 0 then return false end

	return commanderDown or (active / total) <= 0.4
end

local function UpdateMusicState()
	local combatActive = MuR.Data["Mode24Phase"] == "combat"
	local heavy = IsHeavyLosses()

	local newState = heavy and "l" or (combatActive and "c" or "a")
	if newState ~= currentState then
		currentState = newState
		SelectMusic()
	end
end

hook.Add("Think", "Mode24MusicSystem", function()
	if MuR.GamemodeCount ~= 24 then
		if IsValid(trackChannel) then
			trackChannel:Stop()
			trackChannel = nil
		end
		return
	end

	UpdateMusicState()

	if IsValid(trackChannel) and (trackChannel:GetState() == 0 or trackChannel:GetState() == 2) then
		SelectMusic()
	end

	if IsValid(trackChannel) then
		local targetVolume = GetConVar("snd_musicvolume"):GetFloat() * 0.75
		local currentVolume = trackChannel:GetVolume()
		if currentVolume < targetVolume then
			trackChannel:SetVolume(math.min(currentVolume + FrameTime(), targetVolume))
		elseif currentVolume > targetVolume then
			trackChannel:SetVolume(math.max(currentVolume - FrameTime(), targetVolume))
		end
	else
		SelectMusic()
	end
end)

--------------------------------------------------------------------------------
-- Рация: меню подкрепления
--------------------------------------------------------------------------------

--
-- Список павших приходит с сервера уже отфильтрованным: клиенту незачем решать,
-- кто считается мёртвым, а серверу всё равно перепроверять на выборе.
--
net.Receive("MuR.Mode24Radio", function()
	local price = net.ReadUInt(32)
	local count = net.ReadUInt(8)

	local dead = {}
	for i = 1, count do
		local ply = net.ReadEntity()
		if IsValid(ply) and ply:IsPlayer() then dead[#dead + 1] = ply end
	end

	if #dead == 0 then return end

	local frame = vgui.Create("DFrame")
	frame:SetSize(We(420), He(90 + #dead * 44))
	frame:SetTitle("")
	frame:Center()
	frame:MakePopup()
	frame.Paint = function(_, w, h)
		surface.SetDrawColor(12, 12, 14, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(70, 70, 76, 255)
		surface.DrawOutlinedRect(0, 0, w, h)

		draw.SimpleText(L("mode24_radio_title", "CALL REINFORCEMENT"), "MuR_Font2",
			We(14), He(10), Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(L("mode24_radio_hint", "Cost per man:") .. " $" .. price, "MuR_Font1",
			We(14), He(38), Color(150, 150, 155), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local list = vgui.Create("DScrollPanel", frame)
	list:SetPos(We(10), He(62))
	list:SetSize(We(400), He(#dead * 44))

	for _, ply in ipairs(dead) do
		local row = list:Add("DButton")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, He(6))
		row:SetTall(He(38))
		row:SetText("")

		row.Paint = function(self, w, h)
			local points = LocalPlayer():GetNWInt("MuR_Mode24Points", 0)
			local afford = points >= price

			surface.SetDrawColor(self:IsHovered() and 40 or 26, 26, 30, 255)
			surface.DrawRect(0, 0, w, h)

			local name = IsValid(ply) and ply:Nick() or "?"
			draw.SimpleText(name, "MuR_Font1", We(12), h / 2,
				afford and Color(225, 225, 225) or Color(120, 120, 120),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(afford and (L("mode24_radio_call", "CALL IN") .. "  $" .. price)
				or L("mode24_radio_nomoney", "NOT ENOUGH"), "MuR_Font1", w - We(12), h / 2,
				afford and Color(120, 220, 120) or Color(190, 90, 90),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		row.DoClick = function()
			if not IsValid(ply) then return end
			if LocalPlayer():GetNWInt("MuR_Mode24Points", 0) < price then return end

			net.Start("MuR.Mode24Reinforce")
			net.WriteEntity(ply)
			net.SendToServer()

			frame:Close()
		end
	end
end)
