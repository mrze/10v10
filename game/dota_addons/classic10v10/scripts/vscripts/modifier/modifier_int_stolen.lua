if modifier_int_stolen == nil then
    modifier_int_stolen = class({})
end

function modifier_int_stolen:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_int_stolen:GetTexture()
    return "silencer_glaives_of_wisdom"
end

function modifier_int_stolen:IsHidden()
    return false
end

function modifier_int_stolen:IsDebuff()
    return true
end

function modifier_int_stolen:IsPurgable()
    return false
end

function modifier_int_stolen:RemoveOnDeath()
	return false
end

function modifier_int_stolen:AllowIllusionDuplicate()
	return false
end

function modifier_int_stolen:OnCreated(kv)
    print("Modifier int stolen called")
    if not IsServer() then
        return
    end

    print("Created stolen modifier" .. kv.stolen)
	self:SetStackCount(kv.stolen)
end
