local function code()
	local ENT = FindMetaTable("Entity")
	local Cvar = FindMetaTable("ConVar")

	DynSplatterEntGetBloodColor = DynSplatterEntGetBloodColor or ENT.GetBloodColor
	DynSplatterEntSetBloodColor = DynSplatterEntSetBloodColor or ENT.SetBloodColor
	DynSplatterCvarGetInt = DynSplatterCvarGetInt or Cvar.GetInt
	DynSplatterReturnEngineBlood = false

	function ENT:DisableEngineBlood()

		DynSplatterEntSetBloodColor(self, DONT_BLEED)

	end

	function ENT:GetBloodColor()

		if DynSplatterReturnEngineBlood then
			DynSplatterReturnEngineBlood = false
			return DynSplatterEntGetBloodColor(self) or DONT_BLEED
		end

		if self:GetNW2Bool("DynSplatter") then
			return self:GetNW2Int("EnhancedSplatter_BloodColor", -1)
		end

		return DynSplatterEntGetBloodColor(self) or DONT_BLEED

	end

	function ENT:SetBloodColor( col )

		self:SetNW2Int("EnhancedSplatter_BloodColor", col)

		if !self:GetNW2Bool("DynSplatter") then
			DynSplatterEntSetBloodColor(self, col)
		end

	end

	function Cvar:GetInt( ... )

		if self == GetConVar("vj_hlr1_corpse_effects") then return 0 end
		return DynSplatterCvarGetInt(self, ...)

	end

	DynSplatterFullyInitialized = true
end

hook.Add("InitPostEntity", "MuR_BloodSplatter", function()
	timer.Simple(0.5, code)
end)