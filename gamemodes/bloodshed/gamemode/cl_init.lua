MuR = MuR or {}

function MuR.server()
end

function MuR.shared(path)
    include(path)
end

function MuR.client(path)
    include(path)
end

MuR.shared("shared.lua")

CreateConVar("cl_drawspawneffect", 0)

local delay = 0
hook.Add("Think", "MuR_HideErrorModels", function()
	if delay > CurTime() then return end
	delay = CurTime()+1
	for _, ent in ents.Iterator() do
		if IsValid(ent) and not ent:IsPlayer() and not MuR.IsAI(ent) then
			local mdl = ent:GetModel()
			if mdl == "models/error.mdl" and not ent:GetNoDraw() then
				ent:SetNoDraw(true)
			end
		end
	end
end)
