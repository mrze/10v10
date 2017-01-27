if modifier_int_steal == nil then
    modifier_int_steal = class({})
end

function modifier_int_steal:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_int_steal:GetTexture()
    return "silencer_glaives_of_wisdom"
end

function modifier_int_steal:OnCreated(kv)
    if IsServer() then
        self.distance = kv.maxdistance or 925
        self.steal = kv.steal or 1
    end
end

function modifier_int_steal:IsDebuff()
    return false
end

function modifier_int_steal:IsPurgable()
    return false
end


function modifier_int_steal:RemoveOnDeath()
	return false
end

function modifier_int_steal:AllowIllusionDuplicate()
	return false
end

function modifier_int_steal:DeclareFunctions()
    local funcs = {
        MODIFIER_EVENT_ON_DEATH
    }

    return funcs
end

function modifier_int_steal:OnDeath(kv)
    if not IsServer() then
        return
    end
    
    -- unit that died must be hero
    local died = kv.unit
    if not died:IsRealHero() then
        return
    end
    
    -- unit with this buff must be real hero
    if not self:GetParent():IsRealHero() then
        return
    end
    
    -- doesn't apply to self
    if died == self:GetParent() then
        return
    end
    
    -- doesn't apply to allies
    if died:GetTeam() == self:GetParent():GetTeam() then
        return
    end
    
    -- must be in range or killed by parent of this buff
    in_range = (self:GetParent():GetAbsOrigin() - died:GetAbsOrigin()):Length2D() <= self.distance
    killed_by_parent = kv.attacker == self:GetParent()
    if not in_range and not killed_by_parent then
        return
    end
    
    -- Only reduce target to 1 base attr
    local stolen = 0
    if died:GetBaseIntellect() > 1 then
        if died:GetBaseIntellect() > self.steal + 1 then
            died:SetBaseIntellect(died:GetBaseIntellect() - self.steal)
            stolen = self.steal
            died:CalculateStatBonus()
        else
            local old = died:GetBaseIntellect()
            died:SetBaseIntellect(1)
            local new = died:GetBaseIntellect()
            stolen = old - new
        end
    end
    
    -- No point doing rest if no int stolen
    -- (particles above head doesn't work if 0 is passed in)
    if stolen <= 0 then
        return
    end

    -- particle on silencer showing bonus int
    local stolen_str = math.floor(stolen)
    local life_time = 2.0
    local digits = string.len(stolen_str) + 1
    local numParticle = ParticleManager:CreateParticle("particles/msg_fx/msg_miss.vpcf", PATTACH_OVERHEAD_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(numParticle, 1, Vector(10, stolen_str, 0))
    ParticleManager:SetParticleControl(numParticle, 2, Vector(life_time, digits, 0))
    ParticleManager:SetParticleControl(numParticle, 3, Vector(100, 100, 255))
    
    
    -- Update silencer stats
    self:GetParent():SetBaseIntellect(self:GetParent():GetBaseIntellect() + stolen)
    self:SetStackCount(self:GetStackCount() + stolen)
    self:GetParent():CalculateStatBonus()
    
    -- debuff on target showing total int stolen
    -- Can only seem to set new modifiers when alive?
    -- This could be broken if a hero dies very quickly before buff can be set
    Timers:CreateTimer(function()
        if not died:HasModifier("modifier_int_stolen") then            
            modifier = died:AddNewModifier(died, nil, "modifier_int_stolen", {stolen = stolen})
            if modifier == nil then
                return 1
            end
        else
            local modifier = died:FindModifierByName("modifier_int_stolen")
            modifier:SetStackCount(modifier:GetStackCount() + stolen)
        end
    end)
end