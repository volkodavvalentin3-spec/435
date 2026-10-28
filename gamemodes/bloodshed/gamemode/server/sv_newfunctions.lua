local excludedWeapons = {
    ["tfa_bs_rpg7"] = true,
    ["tfa_bs_glock_t"] = true,
    ["tfa_bs_vp9"] = true,
}

local function GetPlayerTFAWeapon(ply, isSidearm, equippedWeapon)
    if equippedWeapon.Melee then return nil end
    for _, weapon in pairs(ply:GetWeapons()) do
        if weapon.IsTFAWeapon then
            if excludedWeapons[weapon:GetClass()] or weapon == equippedWeapon or weapon.Melee then continue end
            local category = weapon.Category or ""
            if isSidearm and category == "Bloodshed - Sidearms" then
                return weapon
            elseif not isSidearm and category != "Bloodshed - Sidearms" then
                return weapon
            end
        end
    end
    return nil
end

hook.Add("WeaponEquip", "BloodshedWeaponLimit", function(weapon, ply)
    if not IsValid(ply) or not IsValid(weapon) or excludedWeapons[weapon:GetClass()] then return end
    if not weapon.IsTFAWeapon then return true end

    local weaponCategory = weapon.Category or ""
    local isSidearm = weaponCategory == "Bloodshed - Sidearms"

    local currentWeapon = GetPlayerTFAWeapon(ply, isSidearm, weapon)
    if IsValid(currentWeapon) then
        ply:DropWeapon(currentWeapon)
    end
end)
