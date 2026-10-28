local soundCache = {}

local function GetRandomSound(ammoType, envType, distType)
	local basePath = string.format("murdered/reverb/%s/%s/%s", ammoType, envType, distType)

	local cacheKey = basePath
	if not soundCache[cacheKey] then
		soundCache[cacheKey] = {}

		local files, _ = file.Find("sound/" .. basePath .. "/*.wav", "GAME")
		if files and #files > 0 then
			for _, f in ipairs(files) do
				table.insert(soundCache[cacheKey], basePath .. "/" .. f)
			end
		end
	end

	if #soundCache[cacheKey] == 0 then
		return nil
	end

	return "<"..soundCache[cacheKey][math.random(1, #soundCache[cacheKey])]
end

local reverbDelay = 0
net.Receive("MuR.Reverb", function()
	local shootPos = net.ReadVector()
	local ammoType = net.ReadString()
	local envType = net.ReadString()
	local distType = net.ReadString()
	local ent = net.ReadEntity()

	local soundPath = GetRandomSound(ammoType, envType, distType)
	if not soundPath or reverbDelay > CurTime() then return end

	local localPly = LocalPlayer()
	if not IsValid(localPly) then return end

	local dist = localPly:GetPos():Distance(shootPos)
	local volume = 1
	local pitch = math.random(95, 105)
	local soundLevel = 135
	local soundFlags = SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL
	local dsp = 0

	if IsValid(ent) and ent:GetPos():DistToSqr(shootPos) < 10000 and LocalPlayer():GetPos():DistToSqr(shootPos) < 10000 then
		ent:EmitSound(soundPath, soundLevel, pitch, volume, CHAN_AUTO, soundFlags, dsp)
	else
		EmitSound(soundPath, shootPos, 0, CHAN_AUTO, volume, soundLevel,soundFlags, pitch, dsp)
	end
end)
