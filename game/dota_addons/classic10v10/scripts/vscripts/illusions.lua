--[[ ============================================================================================================
	Original Author: Rook, with help from Noya
    Adapted from https://raw.githubusercontent.com/Pizzalol/SpellLibrary/master/game/scripts/vscripts/items/item_manta.lua
================================================================================================================= ]]


function create_illusion(caster, illusion_origin, illusion_incoming_damage, illusion_outgoing_damage, illusion_duration)	
	local player_id = caster:GetPlayerID()
	local caster_team = caster:GetTeam()
	
	local illusion = CreateUnitByName(caster:GetUnitName(), illusion_origin, true, caster, nil, caster_team)  --handle_UnitOwner needs to be nil, or else it will crash the game.
	illusion:SetPlayerID(player_id)
	illusion:SetControllableByPlayer(player_id, true)

	--Level up the illusion to the caster's level.
	local caster_level = caster:GetLevel()
	for i = 1, caster_level - 1 do
		illusion:HeroLevelUp(false)
	end

	--Set the illusion's available skill points to 0 and teach it the abilities the caster has.
	illusion:SetAbilityPoints(0)
	for ability_slot = 0, 15 do
		local individual_ability = caster:GetAbilityByIndex(ability_slot)
		if individual_ability ~= nil then
            local blacklisted_ability = false
            if individual_ability:GetAbilityName() == "meepo_divided_we_stand" then
                blacklisted_ability = true
            end
            
            if not blacklisted_ability then
                local illusion_ability = illusion:FindAbilityByName(individual_ability:GetAbilityName())
                if illusion_ability ~= nil then
                    illusion_ability:SetLevel(individual_ability:GetLevel())
                end
            end
		end
	end

	--Recreate the caster's items for the illusion.
	for item_slot = 0, 5 do
		local individual_item = caster:GetItemInSlot(item_slot)
		if individual_item ~= nil then
			local illusion_duplicate_item = CreateItem(individual_item:GetName(), illusion, illusion)
			illusion:AddItem(illusion_duplicate_item)
		end
	end
	
	-- modifier_illusion controls many illusion properties like +Green damage not adding to the unit damage, not being able to cast spells and the team-only blue particle 
	illusion:AddNewModifier(caster, nil, "modifier_illusion", {duration = illusion_duration, outgoing_damage = illusion_outgoing_damage, incoming_damage = illusion_incoming_damage})
	
	illusion:MakeIllusion()  --Without MakeIllusion(), the unit counts as a hero, e.g. if it dies to neutrals it says killed by neutrals, it respawns, etc.  Without it, IsIllusion() returns false and IsRealHero() returns true.

	return illusion
end


function activateIllusionRune(caster)
    return create_three_illusions(caster, 75, 300, 35, 200, 35)
end

function create_three_illusions(caster, IllusionDuration, IllusionIncomingDamageRanged, IllusionOutgoingDamageRanged, IllusionIncomingDamageMelee, IllusionOutgoingDamageMelee)
	local caster_origin = caster:GetAbsOrigin()
	
	--Illusions are created to the North, South, East, or West of the hero (obviously, both cannot be created in the same direction).
	local illusion1_direction = RandomInt(1, 4)
	local illusion2_direction = (RandomInt(1, 3) + illusion1_direction) % 4  --This will ensure that the illusions will spawn in different directions.
	
	local illusion1_origin = nil
	local illusion2_origin = nil
	
	if illusion1_direction == 1 then  --North
		illusion1_origin = caster_origin + Vector(0, 100, 0)
	elseif illusion1_direction == 2 then  --South
		illusion1_origin = caster_origin + Vector(0, -100, 0)
	elseif illusion1_direction == 3 then  --East
		illusion1_origin = caster_origin + Vector(100, 0, 0)
	else  --West
		illusion1_origin = caster_origin + Vector(-100, 0, 0)
	end
	
	if illusion2_direction == 1 then  --North
		illusion2_origin = caster_origin + Vector(0, 100, 0)
	elseif illusion2_direction == 2 then  --South
		illusion2_origin = caster_origin + Vector(0, -100, 0)
	elseif illusion2_direction == 3 then  --East
		illusion2_origin = caster_origin + Vector(100, 0, 0)
	else  --West
		illusion2_origin = caster_origin + Vector(-100, 0, 0)
	end
	
	--Create the illusions.
	local illusion1 = nil
	local illusion2 = nil
	if caster:IsRangedAttacker() then  --We don't have to worry about illusions switching from melee to ranged or vice versa because they can't use abilities.
		illusion1 = create_illusion(caster, illusion1_origin, IllusionIncomingDamageRanged, IllusionOutgoingDamageRanged, IllusionDuration)
		illusion2 = create_illusion(caster, illusion2_origin, IllusionIncomingDamageRanged, IllusionOutgoingDamageRanged, IllusionDuration)
	else  --caster is melee.
		illusion1 = create_illusion(caster, illusion1_origin, IllusionIncomingDamageMelee, IllusionOutgoingDamageMelee, IllusionDuration)
		illusion2 = create_illusion(caster, illusion2_origin, IllusionIncomingDamageMelee, IllusionOutgoingDamageMelee, IllusionDuration)
	end
	
	--Reset our illusion origin variables because CreateUnitByName might have slightly changed the origin so that the unit won't be stuck.
	illusion1_origin = illusion1:GetAbsOrigin()
	illusion2_origin = illusion2:GetAbsOrigin()
	
	--Make it so all of the units are facing the same direction.
	local caster_forward_vector = caster:GetForwardVector()
	illusion1:SetForwardVector(caster_forward_vector)
	illusion2:SetForwardVector(caster_forward_vector)
	
	--Randomize the positions of the illusions and the real hero.
	local hero_random_origin = RandomInt(1, 3)
	local illusion1_random_origin = (RandomInt(1, 2) + hero_random_origin) % 3  --This will ensure that this variable will be different from hero_random_origin.
	
	if hero_random_origin == 1 then
		caster:SetAbsOrigin(caster_origin)
		if illusion1_random_origin == 2 then
			illusion1:SetAbsOrigin(illusion1_origin)
			illusion2:SetAbsOrigin(illusion2_origin)
		else  --illusion1_random_origin == 3
			illusion1:SetAbsOrigin(illusion2_origin)
			illusion2:SetAbsOrigin(illusion1_origin)
		end
	elseif hero_random_origin == 2 then
		caster:SetAbsOrigin(illusion1_origin)
		if illusion1_random_origin == 1 then
			illusion1:SetAbsOrigin(caster_origin)
			illusion2:SetAbsOrigin(illusion2_origin)
		else  --illusion1_random_origin == 3
			illusion1:SetAbsOrigin(illusion2_origin)
			illusion2:SetAbsOrigin(caster_origin)
		end
	else  --hero_random_origin == 3
		caster:SetAbsOrigin(illusion2_origin)
		if illusion1_random_origin == 1 then
			illusion1:SetAbsOrigin(caster_origin)
			illusion2:SetAbsOrigin(illusion1_origin)
		else  --illusion1_random_origin == 2
			illusion1:SetAbsOrigin(illusion1_origin)
			illusion2:SetAbsOrigin(caster_origin)
		end
	end
	
	caster:RemoveNoDraw()
	
	--Set the health and mana values to those of the real hero.
	local caster_health = caster:GetHealth()
	local caster_mana = caster:GetMana()
	illusion1:SetHealth(caster_health)
	illusion1:SetMana(caster_mana)
	illusion2:SetHealth(caster_health)
	illusion2:SetMana(caster_mana)
end