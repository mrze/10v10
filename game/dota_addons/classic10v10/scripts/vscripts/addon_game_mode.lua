local GOLD_SCALE_FACTOR_INITIAL = 1
local GOLD_SCALE_FACTOR_FINAL = 2.5
local GOLD_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes

local XP_SCALE_FACTOR_INITIAL = 2
local XP_SCALE_FACTOR_FINAL = 2
local XP_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes

local XP_JUNGLE_SCALE_FACTOR_INITIAL = 0.3
local XP_JUNGLE_SCALE_FACTOR_FINAL = 1
local XP_JUNGLE_SCALE_FACTOR_FADEIN_SECONDS = (12 * 60) -- 12 minutes for jungle creeps to have regular xp

local MEGA_CREEP_SCALE_DURATION = 1200 -- scale mega creeps to double over 20 minutes (helps finish long games as mega creeps dont normally scale)

local FOUNTAIN_ITEMS = {"item_monkey_king_bar", "item_maelstrom"}
local FOUNTAIN_BAT = 0.25

local HERO_SELECTION_TIME = 70

if GameMode == nil then
    print("Creating 10v10 game mode")
	GameMode = class({})
end

require('util')
require('timers')
require('illusions')


function Precache(context)
    LinkLuaModifier("modifier_int_steal", "modifier/modifier_int_steal.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_int_stolen", "modifier/modifier_int_stolen.lua", LUA_MODIFIER_MOTION_NONE)
end


function Activate()
    self = GameMode()
	GameRules.AddonTemplate = self
    
	GameRules:SetGoldTickTime(0.3)
    self.currentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL
	self.currentXpScaleFactor = XP_SCALE_FACTOR_INITIAL
	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(GameMode, "FilterModifyGold"), self)
	GameRules:GetGameModeEntity():SetModifyExperienceFilter(Dynamic_Wrap(GameMode, "FilterModifyExperience"), self)
    
	GameRules:SetCustomGameSetupAutoLaunchDelay(5)
	GameRules:LockCustomGameSetupTeamAssignment(true)
	GameRules:EnableCustomGameSetupAutoLaunch(true)
    
    GameRules:SetHeroSelectionTime(HERO_SELECTION_TIME)
    GameRules:SetStrategyTime(0.0)
	GameRules:SetShowcaseTime(0.0)
	GameRules:SetPreGameTime(60.0)
	GameRules:SetPostGameTime(45.0)
	
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 10)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 10)
	
	GameRules:SetStartingGold(625)
	
    -- Runes currently don't appear to be working :/
    GameRules:SetRuneSpawnTime(120)
    
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(GameMode, '_OnConnectFull'), self)
    ListenToGameEvent('npc_spawned', Dynamic_Wrap(GameMode, 'OnNPCSpawned'), self)  
    ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(GameMode, 'OnItemPickedUp'), self)
    ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(GameMode, 'OnGameRulesStateChange'), self)
end

mode = nil

function GameMode:_OnConnectFull()
	if mode == nil then
		print("Setting game mode specific parameters")
	
		mode = GameRules:GetGameModeEntity()

        -- enable backdoor
        mode:SetTowerBackdoorProtectionEnabled(true)
        
        -- Runes currently don't appear to be working :/
        local runes_enabled = false
		mode:SetRuneEnabled(DOTA_RUNE_DOUBLEDAMAGE, runes_enabled)
		mode:SetRuneEnabled(DOTA_RUNE_HASTE, runes_enabled)
		mode:SetRuneEnabled(DOTA_RUNE_ILLUSION, runes_enabled)
		mode:SetRuneEnabled(DOTA_RUNE_INVISIBILITY, runes_enabled)
		mode:SetRuneEnabled(DOTA_RUNE_REGENERATION, runes_enabled)
		mode:SetRuneEnabled(DOTA_RUNE_BOUNTY, runes_enabled)
		mode:SetRuneEnabled(DOTA_RUNE_ARCANE, runes_enabled)
	end
end

function GameMode:OnNPCSpawned(keys)
    if not IsServer() then
        return
    end
	local npc = EntIndexToHScript(keys.entindex)
    
    if npc:IsNeutralUnitType() then
        GameMode:OnNeutralCreepSpawned(npc)

    elseif npc:IsCreep() then
        -- roshan??
        
    elseif npc:IsRealHero() then
		GameMode:OnHeroSpawned(npc)
    else
        -- lane creeps?
        GameMode:OnLaneCreepsSpawned(npc)
	end
end

function GameMode:OnNeutralCreepSpawned(npc)
    -- Scale XP for this neutral creep to be reduced in first few minutes minutes to reduce power jungling
    local curTime = GameRules:GetDOTATime(false, false)
    local xpFracTime = math.min(math.max(curTime / XP_JUNGLE_SCALE_FACTOR_FADEIN_SECONDS, 0), 1)
    local xpFrac = XP_JUNGLE_SCALE_FACTOR_INITIAL + (xpFracTime * (XP_JUNGLE_SCALE_FACTOR_FINAL - XP_JUNGLE_SCALE_FACTOR_INITIAL))
    local newXp = npc:GetDeathXP() * xpFrac
    
    npc:SetDeathXP(newXp)
end

local mega_creep_scaling_start = nil
function GameMode:OnLaneCreepsSpawned(creep)
    local name = creep:GetUnitName()
    local mega_creeps = {npc_dota_creep_goodguys_melee_upgraded_mega = true,
                         npc_dota_creep_badguys_melee_upgraded_mega = true,
                         npc_dota_creep_goodguys_ranged_upgraded_mega = true,
                         npc_dota_creep_badguys_ranged_upgraded_mega = true}
                         
    local curTime = GameRules:GetDOTATime(false, false)
    if mega_creeps[name] then
        if mega_creep_scaling_start == nil then
            mega_creep_scaling_start = curTime
        end
        
        local mega_creep_elapsed = curTime - mega_creep_scaling_start
        local scaling = 1 + math.min(math.max((mega_creep_elapsed / 1200), 0), 1)
        
        creep:SetMaxHealth(creep:GetMaxHealth() * scaling)
        creep:SetBaseDamageMin(creep:GetBaseDamageMin() * scaling)
        creep:SetBaseDamageMax(creep:GetBaseDamageMax() * scaling)
    end
end

function GameMode:OnHeroSpawned(hero)
    local player_id = hero:GetPlayerID()
    
    Timers:CreateTimer(0.1, function()
        -- Update silencer int steal to use custom modifier
        if hero:HasModifier("modifier_silencer_int_steal") then
            hero:RemoveModifierByName("modifier_silencer_int_steal")

            if not hero:HasModifier("modifier_int_steal") then
                hero:AddNewModifier(hero, nil, "modifier_int_steal", {steal_range = 925, steal_amount = 1})
			end
        end
    end)
end

function GameMode:OnGameRulesStateChange(keys)
    local newState = GameRules:State_Get()

    if newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
        GameMode:HeroSelection()

    elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        GameMode:OnGameInProgress()
    end
end

function GameMode:HeroSelection()
    if not IsServer() then
        return
    end

    -- radiant bots
    local bots = false
    if bots then
        Tutorial:AddBot("npc_dota_hero_drow_ranger", '', '', true) -- 2
        Tutorial:AddBot("npc_dota_hero_faceless_void", '', '', true) -- 3
        Tutorial:AddBot("npc_dota_hero_morphling", '', '', true) -- 4
        Tutorial:AddBot("npc_dota_hero_sven", '', '', true) -- 5
        Tutorial:AddBot("npc_dota_hero_storm_spirit", '', '', true) -- 6
        Tutorial:AddBot("npc_dota_hero_tidehunter", '', '', true) -- 7
        Tutorial:AddBot("npc_dota_hero_tiny", '', '', true) -- 8
        Tutorial:AddBot("npc_dota_hero_windrunner", '', '', true) -- 9
        Tutorial:AddBot("npc_dota_hero_huskar", '', '', true) -- 10
        
        -- dire bots
        Tutorial:AddBot("npc_dota_hero_viper", '', '', false)  -- 1
        Tutorial:AddBot("npc_dota_hero_dazzle", '', '', false) -- 2
        Tutorial:AddBot("npc_dota_hero_crystal_maiden", '', '', false) -- 3
        Tutorial:AddBot("npc_dota_hero_enigma", '', '', false) -- 4
        Tutorial:AddBot("npc_dota_hero_juggernaut", '', '', false) -- 5
        Tutorial:AddBot("npc_dota_hero_lina", '', '', false) -- 6
        Tutorial:AddBot("npc_dota_hero_lion", '', '', false) -- 7
        Tutorial:AddBot("npc_dota_hero_mirana", '', '', false) -- 8
        Tutorial:AddBot("npc_dota_hero_witch_doctor", '', '', false) -- 9
        Tutorial:AddBot("npc_dota_hero_jakiro", '', '', false) -- 10
    end
    
    -- issue a warning in chat about hero random occurring
    local force_random_time = (HERO_SELECTION_TIME - 10.1)
    for i, duration in ipairs({20, 15, 10, 5}) do
        Timers:CreateTimer(force_random_time - duration, function()
            if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_HERO_SELECTION then
                return
            end
            
            local skip_warning = true
            for player_id = 0, 19 do
                if PlayerResource:IsValidPlayer(player_id) then
                    if not PlayerResource:HasSelectedHero(player_id) then
                        skip_warning = false
                    end
                end
            end
            
            if not skip_warning then
                Say(nil, "Players without a hero selected in " .. duration .. " seconds will automatically random", true)
            end
        end)
    end
    
    -- perform random for any hero not picked
    -- this has to occur before the random time runs out (10 seconds before end of pick time)
    Timers:CreateTimer(force_random_time, function()
        for player_id = 0, 19 do
            if PlayerResource:IsValidPlayer(player_id) then
                local player = PlayerResource:GetPlayer(player_id)
                if not PlayerResource:HasSelectedHero(player_id) then
                    player:MakeRandomHeroSelection()
                    PlayerResource:SetCanRepick(player_id, false)
                    PlayerResource:SetHasRandomed(player_id)
                end
            end
        end
    end)
end


function GameMode:OnGameInProgress()
    local rune_height_modifier = Vector(0, 0, 0)
    local rune_duration = 120

    -- give fountain some abilities to avoid camping
    for i, fountain in pairs(getFountains()) do
        for i, itemName in pairs(FOUNTAIN_ITEMS) do
            fountain:AddItem(CreateItem(itemName, fountain, fountain))
        end
        fountain:SetBaseAttackTime(FOUNTAIN_BAT)
    end
    
    
    -- bounty runes
    Timers:CreateTimer(0, function()
        local curTime = GameRules:GetDOTATime(false, false)
        local initial_bounty = false
        if curTime < 1 then
            initial_bounty = true
        end
    
        local bounty_rune_spawners = Entities:FindAllByName("dota_item_rune_spawner_bounty")
        for i, bounty_rune_spawner in pairs(bounty_rune_spawners) do
            spawnRuneAtLocation("item_rune_bounty", bounty_rune_spawner:GetCenter() + rune_height_modifier, rune_duration, initial_bounty)
        end
        return rune_duration
    end)
    
    -- spawning powerup runes
    local last_powerup_rune = nil
    Timers:CreateTimer(rune_duration, function()
        local powerup_runes = {"item_rune_doubledamage", 
                               "item_rune_arcane",
                               "item_rune_haste",
                               --"item_rune_illusion", -- a bit buggy at the moment
                               "item_rune_invisibility",
                               "item_rune_regeneration"}
                               
        -- make sure the type of rune always rotates
        local next_rune_spawn = randomChoice(powerup_runes)
        while last_powerup_rune == next_rune_spawn do
            next_rune_spawn = randomChoice(powerup_runes)
        end
        last_powerup_rune = next_rune_spawn
        
        local powerup_rune_spawners = Entities:FindAllByName("dota_item_rune_spawner_powerup")
        local next_spawn_location = randomChoice(powerup_rune_spawners)
        spawnRuneAtLocation(next_rune_spawn, next_spawn_location:GetCenter() + rune_height_modifier, rune_duration, false)
        return rune_duration
    end)
    
    
    Timers:CreateTimer(0, function()
        -- Every 10 seconds, recalculate the gold/xp scale factor
    	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            local curTime = GameRules:GetDOTATime(false, false)
            local goldFracTime = math.min(math.max(curTime / GOLD_SCALE_FACTOR_FADEIN_SECONDS, 0), 1)
            local xpFracTime = math.min(math.max(curTime / XP_SCALE_FACTOR_FADEIN_SECONDS, 0), 1)
            self.currentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL + (goldFracTime * (GOLD_SCALE_FACTOR_FINAL - GOLD_SCALE_FACTOR_INITIAL))
            self.currentXpScaleFactor = XP_SCALE_FACTOR_INITIAL + (xpFracTime * (XP_SCALE_FACTOR_FINAL - XP_SCALE_FACTOR_INITIAL))
        end
        return 10
    end)
end

function GameMode:FilterModifyGold(filterTable)
	filterTable["gold"] = self.currentGoldScaleFactor * filterTable["gold"]
	return true
end

function GameMode:FilterModifyExperience(filterTable)
	filterTable["experience"] = self.currentXpScaleFactor * filterTable["experience"]
	return true
end

function GameMode:OnItemPickedUp(keys)
    if not IsServer() then
        return
    end
    local rune_to_bottle = {item_rune_doubledamage = "item_bottle_doubledamage", 
                            item_rune_arcane = "item_bottle_arcane",
                            item_rune_bounty = "item_bottle_bounty",
                            item_rune_haste = "item_bottle_haste",
                            item_rune_illusion = "item_bottle_illusion",
                            item_rune_invisibility = "item_bottle_invisibility",
                            item_rune_regeneration = "item_bottle_regeneration"}

    local hero = nil
    if keys.UnitEntityIndex then
        -- dont care about non heroes
        return
    elseif keys.HeroEntityIndex then
        hero = EntIndexToHScript(keys.HeroEntityIndex)
    end

    local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
    local player = PlayerResource:GetPlayer(keys.PlayerID)
    local runename = keys.itemname

    -- not a rune, don't care
    if not rune_to_bottle[runename] then
        return
    end
    
    -- fill bottle
    local activate_rune = true
    local bottle, bottle_slot = findItemByName("item_bottle", hero)
    if bottle then
        activate_rune = false
    end

    
    -- activate immediately
    if activate_rune then
        activateRuneModifiers(runename, hero, itemEntity)
    else
        if rune_to_bottle[runename] then
            hero:EmitSound("Bottle.Cork")
            local runeBottle = CreateItem(rune_to_bottle[runename], hero, hero)
            runeBottle.is_initial_bounty_rune = itemEntity.is_initial_bounty_rune
            UTIL_Remove(bottle)
            replaceItemIntoSlot(hero, runeBottle, bottle_slot)
        end
    end
end
