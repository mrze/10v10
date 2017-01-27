function PrintTable(t, indent, done)
  if type(t) ~= "table" then return end

  done = done or {}
  done[t] = true
  indent = indent or 0

  local l = {}
  for k, v in pairs(t) do
    table.insert(l, k)
  end

  table.sort(l)
  for k, v in ipairs(l) do
    -- Ignore FDesc
    if v ~= 'FDesc' then
      local value = t[v]

      if type(value) == "table" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..":")
        PrintTable (value, indent + 2, done)
      elseif type(value) == "userdata" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        PrintTable ((getmetatable(value) and getmetatable(value).__index) or getmetatable(value), indent + 2, done)
      else
        if t.FDesc and t.FDesc[v] then
          print(string.rep ("\t", indent)..tostring(t.FDesc[v]))
        else
          print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        end
      end
    end
  end
end


function getAbilityByName(caster, abilityName)
    for i = 0, caster:GetAbilityCount() do
        local ability = caster:GetAbilityByIndex(i)
        if ability:GetAbilityName() == abilityName then
            return ability
        end
    end
    return nil
end


function findItemByName(itemname, inventory)
    local item = -1
    for i = 0, 5 do
        local needle = inventory:GetItemInSlot(i)
        if needle then
            if itemname == needle:GetName() then
                return needle, i
            end
        end
    end
    return nil
end


function findItemSlot(item, inventory)
    for i = 0, 5 do
        local needle = inventory:GetItemInSlot(i)
        if item == needle then
            return i
        end
    end
    return -1
end


function replaceItemIntoSlot(inventory, item, into_slot)
    inventory:AddItem(item)
    local new_slot = findItemSlot(item, inventory)
    if new_slot ~= into_slot then
        inventory:SwapItems(into_slot, new_slot)
    end
end


function randomChoice(collection)
    return collection[RandomInt(1, #collection)]
end


function randomChoice(collection)
    return collection[math.random(#collection)]
end

function spawnRuneAtLocation(rune_type, location, duration, initial_bounty)
    if not IsServer() then
        return
    end
    local rune_item = CreateItem(rune_type, nil, nil)
    rune_item.is_initial_bounty_rune = initial_bounty

    local dd = CreateItemOnPositionForLaunch(location, rune_item)
        
    Timers:CreateTimer(duration, function()
        if not dd:IsNull() then
            UTIL_Remove(dd)
       end
    end)
end


function activateRuneModifiers(runename, caster, rune)
    if runename == "item_rune_invisibility" or runename == "item_bottle_invisibility" then
        caster:EmitSound("Rune.Invis")
        -- todo: fade time indicator
        Timers:CreateTimer(2, function()
            modifier = caster:AddNewModifier(caster, nil, "modifier_rune_invis", {duration=45})
        end)
        
    elseif runename == "item_rune_doubledamage" or runename == "item_bottle_doubledamage" then
        caster:EmitSound("Rune.DD")
        modifier = caster:AddNewModifier(caster, nil, "modifier_rune_doubledamage", {duration=45})
        
    elseif runename == "item_rune_arcane" or runename == "item_bottle_arcane" then
        caster:EmitSound("Rune.Arcane")
        modifier = caster:AddNewModifier(caster, nil, "modifier_rune_arcane", {duration=50})
        
    elseif runename == "item_rune_bounty" or runename == "item_bottle_bounty" then
        caster:EmitSound("Rune.Bounty")
        activateBountyRune(caster, rune)
    
    elseif runename == "item_rune_haste" or runename == "item_bottle_haste" then
        caster:EmitSound("Rune.Haste")
        modifier = caster:AddNewModifier(caster, nil, "modifier_rune_haste", {duration=22})
        
    elseif runename == "item_rune_illusion" or runename == "item_bottle_illusion" then
        caster:EmitSound("Rune.Illusion")
        activateIllusionRune(caster)
    
    elseif runename == "item_rune_regeneration" or runename == "item_bottle_regeneration" then
        caster:EmitSound("Rune.Regen")
        modifier = caster:AddNewModifier(caster, nil, "modifier_rune_regen", {duration=30})
        
    else
        print("Unknown rune name " .. runename)
    end
end


function activateBountyRune(caster, rune)
    local t = GameRules:GetDOTATime(false, true)
    local gold = 100 + (t / 30)
    local xp = 50 + (t / 12)
    
    -- initial bounty rune gives 200 gold and no xp
    if rune.is_initial_bounty_rune then
        gold = 200
        xp = 0
    end
    
    -- greevils greed doubles bounty gold
    if caster:HasAbility("alchemist_goblins_greed") then
        local greed = getAbilityByName(caster, "alchemist_goblins_greed")
        if greed:GetLevel() > 0 then
            gold = gold * 2
        end
    end
    
    caster:ModifyGold(gold, true, 0)
    caster:AddExperience(xp, false, false)

	SendOverheadEventMessage(PlayerResource:GetPlayer(caster:GetPlayerID()), OVERHEAD_ALERT_GOLD, caster, gold, nil)
end

function getFountains()
    local fountains = {Entities:FindByName(nil, "ent_dota_fountain_good"),
                       Entities:FindByName(nil, "ent_dota_fountain_bad")}
    return fountains
end