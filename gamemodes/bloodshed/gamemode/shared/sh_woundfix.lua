if CLIENT then
	if not FLASHLIGHT_WOUND_FIX_ENTS then
		FLASHLIGHT_WOUND_FIX_ENTS = {}
	end

	local function printTableContents()
	end

	local function addToTable(ent)
		if ent:IsPlayer() then
			FLASHLIGHT_WOUND_FIX_ENTS[ent:SteamID()] = ent
		else
			table.insert(FLASHLIGHT_WOUND_FIX_ENTS, ent)
		end

		printTableContents()
	end

	local function removeFromTable(ent)
		table.RemoveByValue(FLASHLIGHT_WOUND_FIX_ENTS, ent)
		printTableContents()
	end

	hook.Add("PreDrawEffects", "PreDrawEffects_FlashlightWoundFix", function()
		if not LocalPlayer():FlashlightIsOn() then return end
		local drawModelCalls = 0

		for _, ent in ipairs(table.Copy(FLASHLIGHT_WOUND_FIX_ENTS)) do

			if not IsValid(ent) then
				removeFromTable(ent)
				continue
			end

			if LocalPlayer():GetPos():DistToSqr(ent:GetPos()) > GetConVar("r_flashlightfar"):GetInt() ^ 2 then continue end

			render.SetBlend(0)
			ent:DrawModel()
			drawModelCalls = drawModelCalls + 1
		end
	end)

	hook.Add("OnEntityCreated", "OnEntityCreated_FlashlightWoundFix", function(ent)
		if ent:IsNPC() or ent:IsNextBot() or ent:GetClass() == "prop_ragdoll" then
			addToTable(ent)
		end
	end)

	hook.Add("CreateClientsideRagdoll", "CreateClientsideRagdoll_FlashlightWoundFix", function(ent, rag)
		removeFromTable(ent)
		addToTable(rag)
	end)

end
