hook.Add("PlayerBindPress", "MuR.HostageBindPress", function(ply, bind, pressed)
	if IsValid(ply:GetNW2Entity("HostageAttacker")) then
		if bind == "+jump" then return false end
		return true
	end
end)

local function We(x)
	return x / 1920 * ScrW()
end

local function He(y)
	return y / 1080 * ScrH()
end

hook.Add("HUDPaint", "MuR.HostageHUD", function()
	local ply = LocalPlayer()

	if ply:IsInHostage(true) then
		local victim = ply:GetNW2Entity("HostageVictim")
		if IsValid(victim) then
			local text = MuR.Language["hostage_taken"]
			surface.SetFont("MuR_Font4")
			local w, h = surface.GetTextSize(text)
			surface.SetDrawColor(0, 0, 0, 150)
			surface.DrawRect(ScrW() / 2 - w/2 - 10, ScrH() / 2 + He(150) - h/2 - 5, w + 20, h + 10)
			draw.SimpleText(text, "MuR_Font4", ScrW() / 2, ScrH() / 2 + He(150), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local resist = ply:GetNW2Float("HostageResist", 0)
			if resist > 0 then
				local text2 = MuR.Language["hostage_victim_resisting"]
				surface.SetFont("MuR_Font2")
				local w2, h2 = surface.GetTextSize(text2)
				surface.SetDrawColor(0, 0, 0, 150)
				surface.DrawRect(ScrW() / 2 - w2/2 - 10, ScrH() / 2 + He(190) - h2/2 - 5, w2 + 20, h2 + 10)
				draw.SimpleText(text2, "MuR_Font2", ScrW() / 2, ScrH() / 2 + He(190), Color(255, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				surface.SetDrawColor(0, 0, 0, 150)
				surface.DrawRect(ScrW() / 2 - We(100), ScrH() / 2 + He(220), We(200), He(20))

				surface.SetDrawColor(255, 50, 50, 255)
				surface.DrawRect(ScrW() / 2 - We(100), ScrH() / 2 + He(220), We(200) * (resist / 100), He(20))
			end
		end
	elseif ply:IsInHostage(false) then
		local text = MuR.Language["hostage_you_are_taken"]
		surface.SetFont("MuR_Font4")
		local w, h = surface.GetTextSize(text)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(ScrW() / 2 - w/2 - 10, ScrH() / 2 + He(150) - h/2 - 5, w + 20, h + 10)
		draw.SimpleText(text, "MuR_Font4", ScrW() / 2, ScrH() / 2 + He(150), Color(255, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local text2 = MuR.Language["hostage_spam_space"]
		surface.SetFont("MuR_Font2")
		local w2, h2 = surface.GetTextSize(text2)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(ScrW() / 2 - w2/2 - 10, ScrH() / 2 + He(190) - h2/2 - 5, w2 + 20, h2 + 10)
		draw.SimpleText(text2, "MuR_Font2", ScrW() / 2, ScrH() / 2 + He(190), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local resist = ply:GetNW2Float("HostageResist", 0)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(ScrW() / 2 - We(100), ScrH() / 2 + He(220), We(200), He(20))

		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawRect(ScrW() / 2 - We(100), ScrH() / 2 + He(220), We(200) * (resist / 100), He(20))
	end
end)
