AddCSLuaFile()
SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Disassembly Tool"
SWEP.Slot = 5
SWEP.WorldModel = "models/murdered/weapons/w_barricadeswep.mdl"
SWEP.ViewModel = "models/murdered/weapons/c_barricadeswep.mdl"
SWEP.WorldModelPosition = Vector(4, -3, 3)
SWEP.WorldModelAngle = Angle(180, 10, 0)
SWEP.ViewModelPos = Vector(0, -1, -1)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 70
SWEP.HoldType = "melee"
SWEP.HitDistance = 56

function SWEP:Deploy(wep)
	self:SetHoldType(self.HoldType)
end

function SWEP:CustomPrimaryAttack()
	local ply = self:GetOwner()
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * self.HitDistance,
		filter = ply,
		mask = MASK_ALL
	})
	local tpos = tr.HitPos
	local ent = tr.Entity
	for k, v in pairs(ents.FindInSphere(tpos, 32)) do
		if (v:GetClass() == "mur_loot_phone" or string.match(v:GetClass(), "tfa") or v:GetClass() == "func_button") and !IsValid(ent.BrokenAtt) then
			ent = v
			break
		end
	end
	print(ent)
	if IsValid(ent) and ent:IsWeapon() and (ent:GetClass() == "mur_loot_phone" or string.match(ent:GetClass(), "tfa")) and !IsValid(ent.BrokenAtt) and !IsValid(ent:GetOwner()) then
		if SERVER then
			ent.BrokenAtt = ply
			ply:EmitSound("physics/concrete/concrete_break2.wav", 50)
		end
		ply:SetAnimation(PLAYER_ATTACK1)
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	elseif IsValid(ent) and ent:GetClass() == "func_button" and !IsValid(ent.BrokenAtt) then
		if SERVER then
			ent.BrokenAtt = ply
			ply:EmitSound("physics/concrete/concrete_break2.wav", 50)
		end
		ply:SetAnimation(PLAYER_ATTACK1)
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	end
end

function SWEP:DrawHUD()
	local ply = self:GetOwner()
	draw.SimpleText(MuR.Language["loot_dis"], "MuR_Font1", ScrW() / 2, ScrH() - He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function SWEP:CustomSecondaryAttack()
end

if SERVER then
	hook.Add("EntityFireBullets", "MuR_CheckWeaponBrokens", function(ent, data)
		if ent:IsPlayer() then
			ent = ent:GetActiveWeapon()
		end
		if ent:GetClass() == "murwep_ragdoll_weapon" and IsValid(ent.Weapon) then
			ent = ent.Weapon
		end
		if IsValid(ent) and ent:IsWeapon() and IsValid(ent.BrokenAtt) and IsValid(ent:GetOwner()) then
			timer.Simple(0.01, function()
				if !IsValid(ent) or !IsValid(ent.BrokenAtt) or !IsValid(ent:GetOwner()) then return end
				ParticleEffect("AC_grenade_explosion_air", ent:GetOwner():EyePos(), Angle(0,0,0))
				util.BlastDamage(ent.BrokenAtt, ent.BrokenAtt, ent:GetOwner():EyePos(), 250, 150)
				MuR:ApplyConcussion(ent:GetOwner():EyePos(), "gas_canister", ent.BrokenAtt)
				MakeExplosionReverb(ent:GetPos())
				sound.Play(")murdered/weapons/grenade/m67_explode.wav", ent:GetPos(), 90, math.random(80,120))
				SafeRemoveEntity(ent, 0.01)
			end)
		end
	end)

	hook.Add("AcceptInput", "MuR_CheckButtonBroken", function(ent, input, activator, caller, value)
		if IsValid(ent) and ent:GetClass() == "func_button" and IsValid(ent.BrokenAtt) and IsValid(activator) and activator:IsPlayer() then
			local explosionPos = ent:GetPos()
			ParticleEffect("AC_grenade_explosion_air", explosionPos, Angle(0,0,0))
			util.BlastDamage(ent.BrokenAtt, ent.BrokenAtt, explosionPos, 200, 200)
			MuR:ApplyConcussion(explosionPos, "gas_canister", ent.BrokenAtt)
			MakeExplosionReverb(ent:GetPos())
			sound.Play(")murdered/weapons/grenade/m67_explode.wav", explosionPos, 90, math.random(80,120))
			SafeRemoveEntity(ent, 0.01)
			return true
		end
	end)
end
SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
