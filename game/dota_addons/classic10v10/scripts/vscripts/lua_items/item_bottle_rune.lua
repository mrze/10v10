if item_bottle_rune == nil then
    item_bottle_rune = class({})
    
    item_bottle_doubledamage = item_bottle_rune
    item_bottle_doubledamage = item_bottle_rune
    item_bottle_arcane = item_bottle_rune
    item_bottle_bounty = item_bottle_rune
    item_bottle_haste = item_bottle_rune
    item_bottle_illusion = item_bottle_rune
    item_bottle_invisibility = item_bottle_rune
    item_bottle_regeneration = item_bottle_rune
end

function item_bottle_rune:OnSpellStart()
    if not IsServer() then
        return
    end
    local hero = self:GetCaster()
    
    -- apply modifiers
    activateRuneModifiers(self:GetName(), hero, self)
    
    -- Find the inventory slot on caster that contains the bottle that was used
    local bottle_slot = findItemSlot(self, hero)
    if bottle_slot == -1 then
        return
    end
    
    -- create bottle to replace existing bottle
    local newBottle = CreateItem("item_bottle", self:GetOwner(), self:GetOwner())
    
    -- delete the rune bottle and replace with existing bottle
    UTIL_Remove(self)
    
    -- move new bottle to old bottles slot
    replaceItemIntoSlot(hero, newBottle, bottle_slot)
end

