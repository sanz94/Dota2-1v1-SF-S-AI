-- Global variables
----------------------------------------------------------------------------------------------------
local bot = GetBot();

local mutils = require(GetScriptDirectory() ..  "/MyUtility")
local itemsData = require(GetScriptDirectory() .. "/ItemData" )
local itemBuild = require(GetScriptDirectory() .. "/item_purchase_" .. string.gsub(GetBot():GetUnitName(), "npc_dota_hero_", ""))
local build = require(GetScriptDirectory() .. "/builds/item_build_" .. string.gsub(GetBot():GetUnitName(), "npc_dota_hero_", ""))
local inspect = require(GetScriptDirectory() ..  "/inspect")

local getAttackRangeBool = true
local creepBlocking = true
local wardPlaced = false

local nearestCreep
local nearbyCreeps
local enemyHero

local itemsToBuy = itemBuild["tableItemsToBuy"]
local BotAbilityPriority = build["skills"]
local abilities = mutils.InitiateAbilities(bot, {0,1,2,5,3});
local abilityQ = bot:GetAbilityByName( "nevermore_shadowraze1" );
local abilityW = bot:GetAbilityByName( "nevermore_shadowraze2" );
local abilityE = bot:GetAbilityByName( "nevermore_shadowraze3" );

local castQDesire = 0;
local castWDesire = 0;
local castEDesire = 0;
local castRDesire = 0;
local botBattleMode = "neutral"
local meeleCreepAttackTime 
local bonusIAS = 0
----------------------------------------------------------------------------------------------------

-- Hard coded values
----------------------------------------------------------------------------------------------------
local attackRange = 500
local nCastRangeQ = 200
local nCastRangeW = 450
local nCastRangeE = 700	
local razeRadius = 250

local BOT_DESIRE_NONE = 0
local BOT_DESIRE_VERY_LOW = 0.1
local BOT_DESIRE_LOW = 0.25
local BOT_DESIRE_MEDIUM = 0.5
local BOT_DESIRE_HIGH = 0.75
local BOT_DESIRE_VERY_HIGH = 0.9
local BOT_DESIRE_ABSOLUTE = 1.0

local BOT_ANIMATION_MOVING = 1502
local BOT_ANIMATION_IDLE = 1500
local BOT_ANIMATION_LASTHIT = 1504
local BOT_ANIMATION_SPELLCAST = 1503

local T1_TOWER_DPS = 110
local T1_TOWER_POSITION = Vector(473.224609, 389.945801)

local MEELE_CREEP_ATTACKS_PER_SECOND = 1.00
local RANGED_CREEP_ATTACKS_PER_SECOND = 1.00
local SIEGE_CREEP_ATTACKS_PER_SECOND = 3.00
local T1_TOWER_ATTACKS_PER_SECOND = 0.82
local BOT_JUST_OUTSIDE_TOWER_RANGE = 0.638401
local BOT_NEAR_TOWER_POS_1 = Vector(313.466949, 306.219910)
local BOT_NEAR_TOWER_POS_2 = Vector (672.677307, -154.150085)
local BOT_NEAR_TOWER_POS_FLAG = 1

local SF_BASE_DAMAGE_VARAINCE = 3

local RANGE_CREEP_ATTACK_PROJECTILE_SPEED = 900
local TOWER_ATTACK_PROJECTILE_SPEED = 750
local SIEGE_CREEP_ATTACK_PROJECTILE_SPEED = 1100
----------------------------------------------------------------------------------------------------

-- Bot states
----------------------------------------------------------------------------------------------------
local botState = mutils.enum({
    "STATE_IDLE",
    "STATE_HEALING",
    "STATE_TELEPORTING",
    "STATE_MOVING"
})
local state = botState.STATE_IDLE
----------------------------------------------------------------------------------------------------

-- All chat at game start
----------------------------------------------------------------------------------------------------
bot:ActionImmediate_Chat("Sharingan 1v1 Mid SF Bot",true)
bot:ActionImmediate_Chat("This bot is still a work in progress, bugs and feedback are welcome",true)
bot:ActionImmediate_Chat("Rules: No runes, No Sentry ward, No Rain Drops or Soul Ring and no Jungling or wave cutting",true)
bot:ActionImmediate_Chat("First to two kills or destroying tower wins. Good luck and have fun!",true)

----------------------------------------------------------------------------------------------------

-- Function to control courier
----------------------------------------------------------------------------------------------------
function CourierUsageThink()
	if(GetNumCouriers() == 0)
	then
		return
	end
	
	local courier = GetCourier(5)
	
	if(bot:GetStashValue() ~= 0)
	then
		bot:ActionImmediate_Courier( courier, COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS  )
	end

	if(GetCourierState(courier) == COURIER_STATE_IDLE )
	then
		bot:ActionImmediate_Courier( courier, COURIER_ACTION_RETURN )
	end
end
----------------------------------------------------------------------------------------------------

-- Function to level up abilities
----------------------------------------------------------------------------------------------------
function AbilityLevelUpThink()   
	
	local ability_name = BotAbilityPriority[1];
	local ability = GetBot():GetAbilityByName(ability_name);
	if(ability ~= nil and ability:GetLevel() > 0) then
		if #BotAbilityPriority > (25 - bot:GetLevel()) then
			for i=1, (#BotAbilityPriority - (25 - bot:GetLevel())) do
				table.remove(BotAbilityPriority, 1)
			end
		end
	end 
	
    if GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS and
        GetGameState() ~= GAME_STATE_PRE_GAME
    then 
        return
    end
	
    -- Do I have a skill point?
    if (bot:GetAbilityPoints() > 0) then  
        local ability_name = BotAbilityPriority[1];
        -- Can I slot a skill with this skill point?
        if(ability_name ~="-1")
        then
            local ability = GetBot():GetAbilityByName(ability_name);
            -- Check if its a legit upgrade
            if( ability:CanAbilityBeUpgraded() and ability:GetLevel() < ability:GetMaxLevel())  
            then
                local currentLevel = ability:GetLevel();
                bot:ActionImmediate_LevelAbility(BotAbilityPriority[1]);
                if ability:GetLevel() > currentLevel then
                    table.remove(BotAbilityPriority,1)
                else
                    end
            end 
        else
            table.remove(BotAbilityPriority,1)
        end
	end
end
----------------------------------------------------------------------------------------------------

-- Calculate if bot wants to use short razeRadius
----------------------------------------------------------------------------------------------------
local function ConsiderQ(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	local optimalLocation
	local highestDesire = 0
	local botLevel = bot:GetLevel()
	local nDamageQ = abilityQ:GetAbilityDamage();
	local nCastPoint = abilities[1]:GetCastPoint();
	local manaCost   = abilities[1]:GetManaCost();
	local nCastLocation = mutils.GetFaceTowardDistanceLocation( bot, nCastRangeQ )
	
	if  mutils.CanBeCast(abilities[1]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) == false then
		return BOT_DESIRE_NONE;
	end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeQ+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = bot:GetNearbyLaneCreeps(nCastRangeQ+razeRadius, true);
		local locationAoEForQ = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRangeQ, razeRadius, 0, nDamageQ );

		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end

		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius , nCastPoint ) == true then
			return BOT_DESIRE_VERY_HIGH, enemyHero[1]:GetLocation()	
		end
		--if locationAoEForQ.count >= 1 
			--and mutils.isLocationWithinRazeRange(bot, nCastRangeQ, razeRadius, locationAoEForQ.targetloc)
			--and bot:IsFacingLocation(locationAoEForQ.targetloc,10)	then
			--DebugDrawCircle(locationAoEForQ.targetloc, razeRadius, 255, 0, 0)
			--highestDesire = 0.5
			--optimalLocation = locationAoEForQ.targetloc
		--end
	end
	
	return BOT_DESIRE_NONE, optimalLocation
end	
----------------------------------------------------------------------------------------------------

-- Calculate if bot wants to use medium raze
----------------------------------------------------------------------------------------------------
local function ConsiderW(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	local optimalLocation
	local highestDesire = 0
	local botLevel = bot:GetLevel()
	local nDamageW = abilityE:GetAbilityDamage();
	local nCastPoint = abilities[2]:GetCastPoint();
	local manaCost   = abilities[2]:GetManaCost();
	local nCastLocation = mutils.GetFaceTowardDistanceLocation( bot, nCastRangeW )

	
	if  mutils.CanBeCast(abilities[2]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) == false then
		return BOT_DESIRE_NONE;
	end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeW+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = bot:GetNearbyLaneCreeps(nCastRangeW+razeRadius, true);
		local locationAoEForW = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRangeW, razeRadius, 0, nDamageW );

		
		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end
		
		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius, nCastPoint ) == true then
			return BOT_DESIRE_VERY_HIGH, enemyHero[1]:GetLocation()	
		end
		
		--if locationAoEForE.count >= 1 
			--and mutils.isLocationWithinRazeRange(bot, nCastRangeW, razeRadius, locationAoEForW.targetloc)
			--and bot:IsFacingLocation(locationAoEForW.targetloc,10)	then
			--DebugDrawCircle(locationAoEForW.targetloc, razeRadius, 0, 255, 0)
			--highestDesire = 0.5
			--optimalLocation = locationAoEForW.targetloc
		--end
	end
	
	return BOT_DESIRE_NONE, optimalLocation
end	
----------------------------------------------------------------------------------------------------

-- Calculate if bot wants to use long raze
----------------------------------------------------------------------------------------------------
local function ConsiderE(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	local optimalLocation
	local highestDesire = 0
	local botLevel = bot:GetLevel()
	local abilityLevel = abilities[3]:GetLevel()
	local abilityDamage = abilities[3]:GetAbilityDamage()
	local castPoint = abilities[3]:GetCastPoint()
	local nDamageE = abilityQ:GetAbilityDamage();
	local nCastPoint = abilities[3]:GetCastPoint();
	local manaCost   = abilities[3]:GetManaCost();
	local nCastLocation = mutils.GetFaceTowardDistanceLocation( bot, nCastRangeE )
	local creepsKilledByRaze = 0
	
	if  mutils.CanBeCast(abilities[3]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) == false or enemyHero == nil or #enemyHero == 0 then
		return BOT_DESIRE_NONE;
	end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeE+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = enemyHero[1]:GetNearbyLaneCreeps(razeRadius, true);
		local locationAoEForE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRangeE, razeRadius, 0, nDamageE );
		
		for _, creep in pairs(enemyCreepsInRazeRadius) do
			if creep:GetHealth() < abilityDamage then
				creepsKilledByRaze = creepsKilledByRaze + 1
			end
		end

		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end
		
		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius , nCastPoint ) == true then
			if (abilityLevel == 1) and creepsKilledByRaze > 0 then
				return BOT_DESIRE_LOW, enemyHero[1]:GetLocation()	
			elseif abilityLevel == 2  and creepsKilledByRaze > 0  then
				return BOT_DESIRE_MEDIUM, enemyHero[1]:GetLocation()	
			elseif abilityLevel == 3 then
				return BOT_DESIRE_VERY_HIGH, enemyHero[1]:GetLocation()	
			elseif abilityLevel == 4 then
				return BOT_DESIRE_VERY_HIGH, enemyHero[1]:GetLocation()	
			end
		end
		
		--if locationAoEForE.count >= 1 
			--and mutils.isLocationWithinRazeRange(bot, nCastRangeE, razeRadius, nClocationAoEForE.targetloc)
			--and bot:IsFacingLocation(locationAoEForE.targetloc,10)	then
			--DebugDrawCircle(locationAoEForE.targetloc, razeRadius, 0, 0, 255)
		    --highestDesire = 0.5
			--optimalLocation = locationAoEForE.targetloc
		--end
	end
	
	return BOT_DESIRE_NONE, optimalLocation
end	
----------------------------------------------------------------------------------------------------

-- Calculate if bot wants to use Requiem
----------------------------------------------------------------------------------------------------
local function ConsiderR()
	if  mutils.CanBeCast(abilities[4]) == false then
		return 0;
	end
	
	if (abilityQ:IsCooldownReady() == false and abilityW:IsCooldownReady()  == false and abilityE:IsCooldownReady() == false) then
		return 1
	end
	
	return 0;
end	
----------------------------------------------------------------------------------------------------

-- Function called every frame to determine bot positioning
----------------------------------------------------------------------------------------------------
local function heroPosition(nearbyCreeps, enemyCreeps, enemyHero)
	
	local distanceBetweenClosestAndFarthestCreep
	--local closestCreepToEnemyFountain = GetUnitToLocationDistance(nearbyCreeps[i], Vector(-3293.869141, -3455.594727))
	local positionNoCreeps = T1_TOWER_POSITION
	local positionNoEnemyCreeps
	local positionAggro
	local positionNeutral
	local towersInRange =  bot:GetNearbyTowers(700, true)
	local creepsNearTower
	local closestCreepToTower
	local closestCreepToTowerDistance
	
	if nearbyCreeps ~= nil and #nearbyCreeps ~=0 then
		positionNoEnemyCreeps = Vector(nearbyCreeps[1]:GetLocation().x+100, nearbyCreeps[1]:GetLocation().y+100)
	end
	
	print("Bot position: ", GetAmountAlongLane(LANE_MID, bot:GetLocation()).amount)
	if enemyCreeps ~= nil and #enemyCreeps ~=0 then
		distanceBetweenClosestAndFarthestCreep = GetUnitToUnitDistance(enemyCreeps[1], enemyCreeps[#enemyCreeps])
		positionAggro = GetLocationAlongLane(LANE_MID, BOT_JUST_OUTSIDE_TOWER_RANGE)
		positionNeutral =  Vector(enemyCreeps[1]:GetLocation().x+400, enemyCreeps[1]:GetLocation().y+400)
		if GetAmountAlongLane(LANE_MID, positionNeutral).amount > 0.65 then
			positionNeutral = GetLocationAlongLane(LANE_MID, BOT_JUST_OUTSIDE_TOWER_RANGE)
		elseif GetAmountAlongLane(LANE_MID, bot:GetLocation()).amount < 0.53 then
			
			if bot:WasRecentlyDamagedByCreep(0.1) then
				if BOT_NEAR_TOWER_POS_FLAG == 1 then
					positionNeutral = BOT_NEAR_TOWER_POS_1
				else
					positionNeutral = BOT_NEAR_TOWER_POS_2
				end
			end
		end
	end
	
	if bot:WasRecentlyDamagedByTower(0.5) == true then
		return BOT_DESIRE_HIGH, T1_TOWER_POSITION
	end
	
	if towersInRange ~= nil and #towersInRange > 0 then
		local towerLocation = towersInRange[1]:GetLocation()
		if nearbyCreeps == nil or #nearbyCreeps == 0 then
			return BOT_DESIRE_HIGH, T1_TOWER_POSITION
		end
		for _, creep in pairs(nearbyCreeps) do
			if GetUnitToUnitDistance(creep,  towersInRange[1]) < closestCreepToTowerDistance then
				closestCreepToTower = creep
				closestCreepToTowerDistance = GetUnitToUnitDistance(creep,  towersInRange[1])
			end
		end
		if #nearbyCreeps >= 3 and (GetUnitToUnitDistance(towersInRange[1], closestCreepToTower) < GetUnitToUnitDistance(bot, towersInRange[1])) then
			return BOT_DESIRE_NONE
		else
			if (GetUnitToLocationDistance(bot, T1_TOWER_POSITION) > 100) then
				return BOT_DESIRE_HIGH, T1_TOWER_POSITION
			end
		end
	end
	
	if botBattleMode == "defend" and #enemyHero ~= 0 then
		local distanceToExitDamageRadius = 700 - (mutils.GetLocationToLocationDistance(bot:GetLocation(), enemyHero[1]:GetLocation()))
		local timeToExitDamageRadius 
		
		if GetUnitToUnitDistance(enemyHero[1], bot) > 950 then
			return BOT_DESIRE_LOW, positionNeutral 
		end
		
		if enemyHero[1]:GetCurrentMovementSpeed() >= bot:GetCurrentMovementSpeed() then
			return BOT_DESIRE_VERY_HIGH,  Vector(enemyHero[1]:GetLocation().x+700,enemyHero[1]:GetLocation().y+700)
		else
			timeToExitDamageRadius = distanceToExitDamageRadius / (bot:GetCurrentMovementSpeed() - enemyHero[1]:GetCurrentMovementSpeed())
			if(GetUnitToUnitDistance(bot, enemyHero[1]) < 700 and mutils.GetUnitsDamageToEnemyForTimePeriod(enemyHero[1], bot, timeToExitDamageRadius, abilities) > bot:GetHealth()) then
				return BOT_DESIRE_VERY_HIGH,  Vector(enemyHero[1]:GetLocation().x+700, enemyHero[1]:GetLocation().y+700)
			end
		end
	end
		
	if enemyCreeps ~= nil and #enemyCreeps > 0 then
		distanceBetweenClosestAndFarthestCreep = GetUnitToUnitDistance(enemyCreeps[1], enemyCreeps[#enemyCreeps])
		if (distanceBetweenClosestAndFarthestCreep > 500) and botBattleMode == "aggro" then
				return BOT_DESIRE_LOW, positionNeutral
		else
				return BOT_DESIRE_LOW, positionNeutral
		end
	elseif nearbyCreeps ~= nil and #nearbyCreeps > 0 then
		if (GetUnitToLocationDistance(bot,  Vector(nearbyCreeps[1]:GetLocation().x+100, nearbyCreeps[1]:GetLocation().y+100)) > 50) then
			return BOT_DESIRE_LOW, positionNoEnemyCreeps
		end
	else
		if (GetUnitToLocationDistance(bot,  positionNoCreeps) > 50) then
			return BOT_DESIRE_MEDIUM, positionNoCreeps
		end
	end
	return BOT_DESIRE_NONE
end
----------------------------------------------------------------------------------------------------

-- Function called every frame for helping the bot last hitting
----------------------------------------------------------------------------------------------------
local function heroLastHit(enemyHero, nearbyCreeps, enemyCreeps, botAttackDamage)

	local alliedCreepTarget = mutils.GetWeakestUnit(nearbyCreeps);
	local enemyCreepTarget = mutils.GetWeakestUnit(enemyCreeps);
	
	local meeleCreepCumulativeDamage = 0
	local meeleCreepWhichKillsIndex = 0
	local enemyCreepsHittingTarget = {}
	local alliedCreepsHittingTarget = {}
	local allyUnitWhichKillsIndex = 0
	local enemyUnitpWhichKillsIndex = 0
	
	if enemyCreepTarget == nil and alliedCreepTarget == nil then
		return BOT_DESIRE_NONE
	else
		if enemyCreepTarget ~= nil then
			local heroHittingTargetCreep = nil
			local unitsHittingTargetCreep = {}
			local distanceBetweenCreepAndBot = GetUnitToUnitDistance(bot, enemyCreepTarget)
			local timeForBotAttackToLand = 0
			local doesBotHaveToTurnToHitCreep, turnTime = mutils.DoesBotHaveToTurnToHitCreep(bot, enemyCreepTarget)
			local projectiles = enemyCreepTarget:GetIncomingTrackingProjectiles()
			
			print("Bot current damage: ", bot:GetAttackDamage() * bot:GetAttackCombatProficiency(enemyCreepTarget) * mutils.getDamageMultipler(enemyCreepTarget))
			
			if (distanceBetweenCreepAndBot > 535.5) then
				if doesBotHaveToTurnToHitCreep == true then
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + ((distanceBetweenCreepAndBot - 535.5) / bot:GetCurrentMovementSpeed()) + mutils.getAttackPointBasedOnIAS(bot) + turnTime
				else
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + ((distanceBetweenCreepAndBot - 535.5) / bot:GetCurrentMovementSpeed()) + mutils.getAttackPointBasedOnIAS(bot)
				end
			else
				if doesBotHaveToTurnToHitCreep == true then
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + mutils.getAttackPointBasedOnIAS(bot) + turnTime
				else
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + mutils.getAttackPointBasedOnIAS(bot)
				end
			end
			
			print("Time for bot attack to land: ", timeForBotAttackToLand)
								
			for _, projectile in pairs(projectiles) do
				if (projectile.caster:IsTower() == true) then
					table.insert(unitsHittingTargetCreep, projectile.caster)
				end
				if (projectile.caster:IsHero() == true) then
					heroHittingTargetCreep = projectile.caster
				end
			end
			
			if nearbyCreeps ~= nil and #nearbyCreeps ~= 0 then
				for _, creep in pairs(nearbyCreeps) do
					if (creep:GetAttackTarget() == enemyCreepTarget) then
						table.insert(unitsHittingTargetCreep, creep)
					end
				end
			end
			
			if unitsHittingTargetCreep ~= nil and #unitsHittingTargetCreep > 0 then
				table.sort(unitsHittingTargetCreep, function(creep1, creep2)
					local creep1Type
					local creep2Type
					local creep1Time
					local creep2Time
					
					creep1Type = mutils.GetCreepType(creep1)
					creep2Type = mutils.GetCreepType(creep2)
				
					if creep1Type == "meele" then
						creep1Time = creep1:GetLastAttackTime() + MEELE_CREEP_ATTACKS_PER_SECOND 
					elseif creep1Type == "ranged" then
						creep1Time = creep1:GetLastAttackTime() + RANGED_CREEP_ATTACKS_PER_SECOND + GetUnitToUnitDistance(enemyCreepTarget, creep1) / creep1:GetAttackProjectileSpeed()
					elseif creep1Type == "siege" then
						creep1Time = creep1:GetLastAttackTime() + SIEGE_CREEP_ATTACKS_PER_SECOND  + GetUnitToUnitDistance(enemyCreepTarget, creep1) / creep1:GetAttackProjectileSpeed()
					elseif creep1Type == "tower" then
						creep1Time = creep1:GetLastAttackTime() + T1_TOWER_ATTACKS_PER_SECOND + GetUnitToUnitDistance(enemyCreepTarget, creep1) / creep1:GetAttackProjectileSpeed()
					end
					
					if creep2Type == "meele" then
						creep2Time = creep2:GetLastAttackTime() + MEELE_CREEP_ATTACKS_PER_SECOND 
					elseif creep2Type == "ranged" then
						creep2Time = creep2:GetLastAttackTime() + RANGED_CREEP_ATTACKS_PER_SECOND + GetUnitToUnitDistance(enemyCreepTarget, creep2) / creep2:GetAttackProjectileSpeed()
					elseif creep2Type == "siege" then
						creep2Time = creep2:GetLastAttackTime() + SIEGE_CREEP_ATTACKS_PER_SECOND + GetUnitToUnitDistance(enemyCreepTarget, creep2) / creep2:GetAttackProjectileSpeed()
					elseif creep2Type == "tower" then
						creep2Time = creep2:GetLastAttackTime() + T1_TOWER_ATTACKS_PER_SECOND + GetUnitToUnitDistance(enemyCreepTarget, creep2) / creep2:GetAttackProjectileSpeed()
					end
					
					
					return creep1Time < creep2Time
				end)
				
				local totalDamage = 0
			
				local i = 1
				while (allyUnitWhichKillsIndex == 0) do
				  
					local index
					local loopTimes = 0
					if i > #unitsHittingTargetCreep then
						index = math.fmod(i, #unitsHittingTargetCreep)
						if index == 0 then
							index = #unitsHittingTargetCreep
						end

					else
						index = i
					end
					
					if i > #unitsHittingTargetCreep then
						loopTimes = math.floor(i/#unitsHittingTargetCreep) + 1
					else
						loopTimes = 1
					end
					
					if i > #unitsHittingTargetCreep then
						local creepType = mutils.GetCreepType(unitsHittingTargetCreep[index])
						if creepType == "meele" then
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime()  + (loopTimes * MEELE_CREEP_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						elseif creepType == "ranged" then
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime() +  GetUnitToUnitDistance(enemyCreepTarget, unitsHittingTargetCreep[index]) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() + (loopTimes * RANGED_CREEP_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						elseif creepType == "siege" then
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime()  + GetUnitToUnitDistance(enemyCreepTarget, unitsHittingTargetCreep[index]) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed()  + (loopTimes * SIEGE_CREEP_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						else
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime() + GetUnitToUnitDistance(enemyCreepTarget, unitsHittingTargetCreep[index]) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() + (loopTimes * T1_TOWER_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						end
					
					end
					
					print("Total damage before : ", totalDamage)
					print("Creep attack: ", unitsHittingTargetCreep[index]:GetAttackDamage())
					print("Creep health before: ", enemyCreepTarget:GetHealth() - totalDamage)

					totalDamage = totalDamage + (unitsHittingTargetCreep[index]:GetAttackDamage() * unitsHittingTargetCreep[index]:GetAttackCombatProficiency(enemyCreepTarget) * mutils.getDamageMultipler(enemyCreepTarget))
					print("Total damage after : ", totalDamage)
					print("Creep health after: ", enemyCreepTarget:GetHealth() - totalDamage)


				
					if ((enemyCreepTarget:GetHealth() - totalDamage) <  ((bot:GetAttackDamage() - SF_BASE_DAMAGE_VARAINCE)* bot:GetAttackCombatProficiency(enemyCreepTarget) * mutils.getDamageMultipler(enemyCreepTarget))) then
						allyUnitWhichKillsIndex = i
						break
					end
				  
				  i = i + 1
				end
				
				
				
				if allyUnitWhichKillsIndex ~= nil and allyUnitWhichKillsIndex ~= 0 then
					local loopTimes = 0
					local index = 0
					if allyUnitWhichKillsIndex > #unitsHittingTargetCreep then
						index = math.fmod(i, #unitsHittingTargetCreep)
						if index == 0 then
							index = #unitsHittingTargetCreep
						end
					else
						index = allyUnitWhichKillsIndex
					end
					
					if allyUnitWhichKillsIndex > #unitsHittingTargetCreep then
						loopTimes = math.floor(allyUnitWhichKillsIndex/#unitsHittingTargetCreep) + 1
					else
						loopTimes = 1
					end

					local timeTakenForAttackToLand
					
					local creepType = mutils.GetCreepType(unitsHittingTargetCreep[index])
					
					if creepType == "meele" then
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime()  + (MEELE_CREEP_ATTACKS_PER_SECOND * (loopTimes)))
					elseif creepType == "ranged" then
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime()  + (RANGED_CREEP_ATTACKS_PER_SECOND * loopTimes)) + (GetUnitToUnitDistance(unitsHittingTargetCreep[index], enemyCreepTarget) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() )
					elseif creepType == "siege" then
						
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime() + (SIEGE_CREEP_ATTACKS_PER_SECOND * loopTimes)) +  (GetUnitToUnitDistance(unitsHittingTargetCreep[index], enemyCreepTarget) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() )
					elseif creepType == "tower" then
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime()+ (T1_TOWER_ATTACKS_PER_SECOND * loopTimes)) +  (GetUnitToUnitDistance(unitsHittingTargetCreep[index], enemyCreepTarget) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() )
					else
						timeTakenForAttackToLand = nil
					end
					
					print("Time for creep attack to land: ", timeTakenForAttackToLand - GameTime())
								
					if timeTakenForAttackToLand ~= nil and (timeTakenForAttackToLand < (GameTime() + timeForBotAttackToLand)) then
						print("LH2")
						return BOT_DESIRE_MEDIUM, enemyCreepTarget
					end
				end		
			end
		end
			
		if alliedCreepTarget ~= nil then
			local heroHittingTargetCreep = nil
			local unitsHittingTargetCreep = {}
			local distanceBetweenCreepAndBot = GetUnitToUnitDistance(bot, alliedCreepTarget)
			local timeForBotAttackToLand = 0
			local doesBotHaveToTurnToHitCreep, turnTime = mutils.DoesBotHaveToTurnToHitCreep(bot, alliedCreepTarget)
			local projectiles = alliedCreepTarget:GetIncomingTrackingProjectiles()
			
			if (distanceBetweenCreepAndBot > 535.5) then
				if doesBotHaveToTurnToHitCreep == true then
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + ((distanceBetweenCreepAndBot - 535.5) / bot:GetCurrentMovementSpeed()) + mutils.getAttackPointBasedOnIAS(bot) + turnTime
				else
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + ((distanceBetweenCreepAndBot - 535.5) / bot:GetCurrentMovementSpeed()) + mutils.getAttackPointBasedOnIAS(bot)
				end
			else
				if doesBotHaveToTurnToHitCreep == true then
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + mutils.getAttackPointBasedOnIAS(bot) + turnTime
				else
					timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + mutils.getAttackPointBasedOnIAS(bot)
				end
			end
								
			for _, projectile in pairs(projectiles) do
				if (projectile.caster:IsTower() == true) then
					table.insert(unitsHittingTargetCreep, projectile.caster)
				end
				if (projectile.caster:IsHero() == true) then
					heroHittingTargetCreep = projectile.caster
				end
			end
			
			if enemyCreeps ~= nil and #enemyCreeps ~= 0 then
				for _, creep in pairs(enemyCreeps) do
					if (creep:GetAttackTarget() == alliedCreepTarget) then
						table.insert(unitsHittingTargetCreep, creep)
					end
				end
			end
			
			if unitsHittingTargetCreep ~= nil and #unitsHittingTargetCreep > 0 then
				table.sort(unitsHittingTargetCreep, function(creep1, creep2)
					local creep1Type
					local creep2Type
					local creep1Time
					local creep2Time
					
					creep1Type = mutils.GetCreepType(creep1)
					creep2Type = mutils.GetCreepType(creep2)
				
					if creep1Type == "meele" then
						creep1Time = creep1:GetLastAttackTime() + MEELE_CREEP_ATTACKS_PER_SECOND 
					elseif creep1Type == "ranged" then
						creep1Time = creep1:GetLastAttackTime() + RANGED_CREEP_ATTACKS_PER_SECOND + GetUnitToUnitDistance(alliedCreepTarget, creep1) / creep1:GetAttackProjectileSpeed()
					elseif creep1Type == "siege" then
						creep1Time = creep1:GetLastAttackTime() + SIEGE_CREEP_ATTACKS_PER_SECOND  + GetUnitToUnitDistance(alliedCreepTarget, creep1) / creep1:GetAttackProjectileSpeed()
					elseif creep1Type == "tower" then
						creep1Time = creep1:GetLastAttackTime() + T1_TOWER_ATTACKS_PER_SECOND + GetUnitToUnitDistance(alliedCreepTarget, creep1) / creep1:GetAttackProjectileSpeed()
					end
					
					if creep2Type == "meele" then
						creep2Time = creep2:GetLastAttackTime() + MEELE_CREEP_ATTACKS_PER_SECOND 
					elseif creep2Type == "ranged" then
						creep2Time = creep2:GetLastAttackTime() + RANGED_CREEP_ATTACKS_PER_SECOND + GetUnitToUnitDistance(alliedCreepTarget, creep2) / creep2:GetAttackProjectileSpeed()
					elseif creep2Type == "siege" then
						creep2Time = creep2:GetLastAttackTime() + SIEGE_CREEP_ATTACKS_PER_SECOND + GetUnitToUnitDistance(alliedCreepTarget, creep2) / creep2:GetAttackProjectileSpeed()
					elseif creep2Type == "tower" then
						creep2Time = creep2:GetLastAttackTime() + T1_TOWER_ATTACKS_PER_SECOND + GetUnitToUnitDistance(alliedCreepTarget, creep2) / creep2:GetAttackProjectileSpeed()
					end
					
					
					return creep1Time < creep2Time
				end)
			
				local totalDamage = 0
				
				local i = 1
				while (allyUnitWhichKillsIndex == 0) do
				  
					local index
					local loopTimes = 0
					if i > #unitsHittingTargetCreep then
						index = math.fmod(i, #unitsHittingTargetCreep)
						if index == 0 then
							index = #unitsHittingTargetCreep
						end

					else
						index = i
					end
					
					if i > #unitsHittingTargetCreep then
						loopTimes = math.floor(i/#unitsHittingTargetCreep) + 1
					else
						loopTimes = 1
					end
					
					if i > #unitsHittingTargetCreep then
						local creepType = mutils.GetCreepType(unitsHittingTargetCreep[index])
						if creepType == "meele" then
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime()  + (loopTimes * MEELE_CREEP_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						elseif creepType == "ranged" then
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime() +  GetUnitToUnitDistance(alliedCreepTarget, unitsHittingTargetCreep[index]) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() + (loopTimes * RANGED_CREEP_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						elseif creepType == "siege" then
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime()  + GetUnitToUnitDistance(alliedCreepTarget, unitsHittingTargetCreep[index]) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed()  + (loopTimes * SIEGE_CREEP_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						else
							if ((unitsHittingTargetCreep[index]:GetLastAttackTime() + GetUnitToUnitDistance(alliedCreepTarget, unitsHittingTargetCreep[index]) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() + (loopTimes * T1_TOWER_ATTACKS_PER_SECOND)) - GameTime() >= timeForBotAttackToLand+2) then
								break
							end
						end
					
					end
					
					totalDamage = totalDamage + (unitsHittingTargetCreep[index]:GetAttackDamage() * unitsHittingTargetCreep[index]:GetAttackCombatProficiency(alliedCreepTarget) * mutils.getDamageMultipler(alliedCreepTarget))
				
					if ((alliedCreepTarget:GetHealth() - totalDamage) <  ((bot:GetAttackDamage() - SF_BASE_DAMAGE_VARAINCE)* bot:GetAttackCombatProficiency(alliedCreepTarget) * mutils.getDamageMultipler(alliedCreepTarget))) then
						enemyUnitpWhichKillsIndex = i
						break
					end
				  
				  i = i + 1
				end
				
				
				
				if enemyUnitpWhichKillsIndex ~= nil and enemyUnitpWhichKillsIndex ~= 0 then
					local loopTimes = 0
					local index = 0
					if enemyUnitpWhichKillsIndex > #unitsHittingTargetCreep then
						index = math.fmod(i, #unitsHittingTargetCreep)
						if index == 0 then
							index = #unitsHittingTargetCreep
						end
					else
						index = enemyUnitpWhichKillsIndex
					end
					
					if enemyUnitpWhichKillsIndex > #unitsHittingTargetCreep then
						loopTimes = math.floor(enemyUnitpWhichKillsIndex/#unitsHittingTargetCreep) + 1
					else
						loopTimes = 1
					end

					local timeTakenForAttackToLand
					
					local creepType = mutils.GetCreepType(unitsHittingTargetCreep[index])
					
					if creepType == "meele" then
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime()  + (MEELE_CREEP_ATTACKS_PER_SECOND * (loopTimes)))
					elseif creepType == "ranged" then
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime()  + (RANGED_CREEP_ATTACKS_PER_SECOND * loopTimes)) + (GetUnitToUnitDistance(unitsHittingTargetCreep[index], alliedCreepTarget) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() )
					elseif creepType == "siege" then
						
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime() + (SIEGE_CREEP_ATTACKS_PER_SECOND * loopTimes)) +  (GetUnitToUnitDistance(unitsHittingTargetCreep[index], alliedCreepTarget) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() )
					elseif creepType == "tower" then
						 timeTakenForAttackToLand = (unitsHittingTargetCreep[index]:GetLastAttackTime()+ (T1_TOWER_ATTACKS_PER_SECOND * loopTimes)) +  (GetUnitToUnitDistance(unitsHittingTargetCreep[index], alliedCreepTarget) / unitsHittingTargetCreep[index]:GetAttackProjectileSpeed() )
					else
						timeTakenForAttackToLand = nil
					end

					if timeTakenForAttackToLand ~= nil and (timeTakenForAttackToLand < (GameTime() + timeForBotAttackToLand)) then
						return BOT_DESIRE_MEDIUM, alliedCreepTarget
					end
				end		
			end
		end
	end
	
	if enemyCreeps ~= nil and #enemyCreeps > 0 then
		for i=1,#enemyCreeps,1 do
			if enemyCreeps[i]:GetHealth() < ((bot:GetAttackDamage() - bot:GetBaseDamageVariance()) * bot:GetAttackCombatProficiency(enemyCreeps[i]) * mutils.getDamageMultipler(enemyCreeps[i])) then
				print("LH1")
				return BOT_DESIRE_MEDIUM, enemyCreeps[i]
			end
		end
	end
	
	if nearbyCreeps ~= nil and #nearbyCreeps > 0 then
		for i=1,#nearbyCreeps,1 do
			if nearbyCreeps[i]:GetHealth() < ((bot:GetAttackDamage() - bot:GetBaseDamageVariance()) * bot:GetAttackCombatProficiency(nearbyCreeps[i]) * mutils.getDamageMultipler(nearbyCreeps[i])) then
				return BOT_DESIRE_MEDIUM, nearbyCreeps[i]
			end
		end
	end
			
			
	return BOT_DESIRE_NONE
end
----------------------------------------------------------------------------------------------------

-- Function called every frame to determine what items to buy
----------------------------------------------------------------------------------------------------
local function heroBattleThink(enemyHero, nearbyCreeps)
	
	if #enemyHero == 0 then
		return BOT_DESIRE_NONE
	end
		
	local towersInRange = bot:GetNearbyTowers( 700, true )
	local enemyMeeleCreepsDamage = 0
	local enemyRangeCreepsDamage = 0
	local alliedMeeleCreepsDamage = 0
	local alliedRangeCreepsDamage = 0
	local alliedTowersDamage = 0
	local enemyTowersDamage = 0
	
	local enemyMeeleCreepsNearBot = bot:GetNearbyLaneCreeps( 125, true )
	if #enemyMeeleCreepsNearBot > 0 then
		for _, creep in pairs(enemyMeeleCreepsNearBot) do
			enemyMeeleCreepsDamage = creep:GetAttackDamage() * creep:GetAttackCombatProficiency(bot) * mutils.getDamageMultipler(bot)
		end
	end
	
	local enemyRangeCreepsHittingBot = 0
	
	local botProjectiles = bot:GetIncomingTrackingProjectiles()
	if (#botProjectiles ~= 0) then
		for index, projectile in pairs(botProjectiles) do
			if mutils.GetCreepType(projectile.caster) == "ranged" then
				enemyRangeCreepsHittingBot = enemyRangeCreepsHittingBot + 1
				enemyRangeCreepsDamage = projectile.caster:GetAttackDamage() * projectile.caster:GetAttackCombatProficiency(bot) * mutils.getDamageMultipler(bot)
			elseif mutils.GetCreepType(projectile.caster) == "tower" then
				enemyTowersDamage = projectile.caster:GetAttackDamage() * projectile.caster:GetAttackCombatProficiency(bot) * mutils.getDamageMultipler(bot)
			end
		end
	end
	
	local enemyCreepsDamage = alliedMeeleCreepsDamage + alliedRangeCreepsDamage
	
	local alliedMeeleCreepsNearEnemy = enemyHero[1]:GetNearbyLaneCreeps( 125, true )
	if #alliedMeeleCreepsNearEnemy > 0 then
		for _, creep in pairs(enemyMeeleCreepsNearBot) do
			alliedMeeleCreepsDamage = creep:GetAttackDamage() * creep:GetAttackCombatProficiency(enemyHero[1]) * mutils.getDamageMultipler(enemyHero[1])
		end
	end
	
	local alliedRangeCreepsHittingEnemy = 0
	
	local enemyProjectiles = enemyHero[1]:GetIncomingTrackingProjectiles()
	if (#enemyProjectiles ~= 0) then
		for index, projectile in pairs(enemyProjectiles) do
			if mutils.GetCreepType(projectile.caster) == "ranged" then
				alliedRangeCreepsHittingEnemy = alliedRangeCreepsHittingEnemy + 1
				alliedRangeCreepsDamage = projectile.caster:GetAttackDamage() * projectile.caster:GetAttackCombatProficiency(enemyHero[1]) * mutils.getDamageMultipler(enemyHero[1])
			elseif  mutils.GetCreepType(projectile.caster) == "tower" then
				alliedTowersDamage = projectile.caster:GetAttackDamage() * projectile.caster:GetAttackCombatProficiency(enemyHero[1]) * mutils.getDamageMultipler(enemyHero[1])
			end
		end
	end
	
	local alliedCreepsDPS = (alliedMeeleCreepsDamage * MEELE_CREEP_ATTACKS_PER_SECOND) + (alliedRangeCreepsDamage * RANGED_CREEP_ATTACKS_PER_SECOND) + (alliedTowersDamage * T1_TOWER_ATTACKS_PER_SECOND)
	local enemyCreepsDPS = (enemyMeeleCreepsDamage * MEELE_CREEP_ATTACKS_PER_SECOND) + (enemyRangeCreepsDamage * RANGED_CREEP_ATTACKS_PER_SECOND) + (enemyTowersDamage * T1_TOWER_ATTACKS_PER_SECOND)

	local botAttacksPerSecond = 1/bot:GetAttackSpeed()
	local botMagicalDamgage, botSpellCastingTime = mutils.GetBotSpellDamage(bot, enemyHero[1], abilities)
	local botDPS = (bot:GetAttackDamage() * botAttacksPerSecond) + botMagicalDamgage
	
	local enemyAttacksPerSecond = 1/enemyHero[1]:GetAttackSpeed()
	local enemyMagicalDamgage, enemySpellCastingTime = mutils.GetEnemySpellDamage(bot, enemyHero[1], abilities)
	local enemyDPS = (enemyHero[1]:GetAttackDamage() * botAttacksPerSecond) + enemyMagicalDamgage
	
	local timeToKillEnemy = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS)
	local timeToKillBot = bot:GetHealth() / (enemyDPS + enemyCreepsDPS)
	
	print("Time to kill bot : ", timeToKillBot)
	print("Time to kill enemy : ", timeToKillEnemy)
	
	print("Enemy dmage: ", enemyDPS)
	print("Bot dmge:" , botDPS)
	
	local timeForBotToDie = bot:GetHealth() / (enemyDPS + enemyCreepsDPS)
	local timeForEnemeyToDie = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS)
	
	if enemyHero[1]:GetHealth() < bot:GetHealth() then
		if #enemyMeeleCreepsNearBot == 0 then
			botBattleMode = "aggro"
		elseif (enemyDPS + enemyCreepsDPS) < (botDPS + alliedCreepsDPS) then
			botBattleMode = "aggro"
		else
			botBattleMode = "neutral"
		end
	elseif bot:GetHealth() < enemyHero[1]:GetHealth() and timeForBotToDie < timeForEnemeyToDie then
		botBattleMode = "defend"
	elseif timeForBotToDie > timeForEnemeyToDie then
		botBattleMode = "aggro"
	else
		botBattleMode = "neutral"
	end
	
	print("Current mode: ", botBattleMode)
	
	if towersInRange ~= nil and #towersInRange > 0 then
		local timeToKillBotUnderTower = bot:GetHealth() / (enemyDPS + T1_TOWER_DPS+ enemyCreepsDPS)
		if (timeToKillBotUnderTower < timeToKillEnemy) or timeToKillEnemy > 2 then
			return BOT_DESIRE_NONE
		else
			return BOT_DESIRE_VERY_HIGH, enemyHero[1]
		end
	end
	
	local pvpDistance = GetUnitToUnitDistance(bot, enemyHero[1])
	--if #enemyHero == 0 or (mutils.CanBeCast(abilities[1]) == true and enemyHero[1]:HasModifier("modifier_nevermore_shadowraze_debuff") == true) then
		--return BOT_DESIRE_NONE
	--end

	
	if bot:WasRecentlyDamagedByTower(0.1) and towersInRange ~= nil and #towersInRange > 0 then
		local towerToBotDistance = GetUnitToUnitDistance(bot, towersInRange[1])
		if #nearbyCreeps > 0 then
			local closestCreepToTower = (towersInRange[1]:GetNearbyLaneCreeps(700, true))[1]
			if closestCreepToTower < towerToBotDistance then
				return BOT_DESIRE_VERY_HIGH, nearbyCreeps[1]
			end
		else
			return BOT_DESIRE_NONE
		end
	end
	
	if (botDPS * 5.0) > enemyHero[1]:GetHealth() then
		
		if (timeToKillEnemy < timeToKillBot) then
			return BOT_DESIRE_ABSOLUTE, enemyHero[1]
		else
			return BOT_DESIRE_NONE
		end
	end
	
	if (enemyDPS * 3.0) > bot:GetHealth() and timeToKillBot < timeToKillEnemy then
		return BOT_DESIRE_NONE
	end

	if botBattleMode == "neutral" then
		if bot:WasRecentlyDamagedByAnyHero(0.1) and ((botDPS+alliedCreepsDPS) > (enemyDPS+enemyCreepsDPS)) then
			return BOT_DESIRE_MEDIUM, enemyHero[1]
		else
			botBattleMode = "defend"
			return BOT_DESIRE_NONE
		end
	end
	
	if botBattleMode == "aggro" then
		local timeToKillBot = bot:GetHealth() / (enemyDPS + enemyCreepsDPS)
		local timeToKillEnemy = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS) 
		if timeToKillBot > timeToKillEnemy then
			return BOT_DESIRE_HIGH, enemyHero[1]
		else
			return BOT_DESIRE_NONE
		end
	end
	
	local botAnimActivity = bot:GetAnimActivity()
	print("Anim: ", botAnimActivity)
	--if (botAnimActivity == BOT_ANIMATION_IDLE) then
		--print("Attacking because bot is idle")
		--return BOT_DESIRE_HIGH, enemyHero[1]
	--end
		
	return BOT_DESIRE_NONE
end
----------------------------------------------------------------------------------------------------

-- Function called every frame to determine bot spell usage
----------------------------------------------------------------------------------------------------
local function AbilityUsageThink(botLevel, botAttackDamage, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	
	local manaBasedDesire = 0
	local levelBasedDesire = 0
	local currentBotLocation = bot:GetLocation()
	
	if mutils.CantUseAbility(bot) or mutils.hasManaToCastSpells(botLevel, botManaLevel) == false then
		return BOT_DESIRE_NONE
	end
	
	--Desire to cast spells based on current hero level
	if botLevel == 1 then
		levelBasedDesire = 0.5
	end
	
	--Desire to cast spells based on current mana level
	if (botManaPercentage >= 90) then
		manaBasedDesire = manaBasedDesire + 0.5
	elseif (botManaPercentage >= 60) then
		manaBasedDesire = manaBasedDesire + 0.4
	elseif (botManaPercentage >= 30) then
		manaBasedDesire = manaBasedDesire + 0.3
	end
		
	castQDesire, optimalLocationQ = ConsiderQ(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage);
	castWDesire, optimalLocationW = ConsiderW(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage);
	castEDesire, optimalLocationE = ConsiderE(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage);
	castRDesire = ConsiderR(enemy);
	
	if castRDesire > 0 then
		return BOT_DESIRE_LOW, abilities[4]
	end
	
	if castQDesire > 0 then
		
		local newXLocationQ = 0
		local newYLocationQ = 0
		
		local horizontalDistanceBetweenPoints = math.max(optimalLocationQ.x, currentBotLocation.x) - math.min(optimalLocationQ.x - currentBotLocation.x)
		local verticalDistanceBetweenPoints = math.max(optimalLocationQ.y, currentBotLocation.y) - math.min(optimalLocationQ.y - currentBotLocation.y)
		
		newXLocationQ = horizontalDistanceBetweenPoints * 0.01
		newYLocationQ = verticalDistanceBetweenPoints * 0.01
		
		if currentBotLocation.x > optimalLocationQ.x then
			newXLocationQ = currentBotLocation.x - (horizontalDistanceBetweenPoints * 0.001)
		elseif currentBotLocation.x < optimalLocationQ.x then
			newXLocationQ = currentBotLocation.x + (horizontalDistanceBetweenPoints * 0.001)
		else
			newXLocationQ = currentBotLocation.x
		end
		
			
		if currentBotLocation.y > optimalLocationQ.y then
			newYLocationQ = currentBotLocation.y - (verticalDistanceBetweenPoints * 0.001)
		elseif currentBotLocation.y < optimalLocationQ.y then
			newYLocationQ = currentBotLocation.y + (verticalDistanceBetweenPoints * 0.001)
		else
			newYLocationQ = currentBotLocation.y
		end
		
		if (bot:IsFacingLocation( optimalLocationQ, 50 )) then
			return castQDesire, Vector(newXLocationQ, newYLocationQ), abilities[1]
		end
	end
	
	if castWDesire > 0 then

		local newXLocationW = 0
		local newYLocationW = 0
		
		local horizontalDistanceBetweenPoints = math.max(optimalLocationW.x, currentBotLocation.x) - math.min(optimalLocationW.x - currentBotLocation.x)
		local verticalDistanceBetweenPoints = math.max(optimalLocationW.y, currentBotLocation.y) - math.min(optimalLocationW.y - currentBotLocation.y)
		
		newXLocationW = horizontalDistanceBetweenPoints * 0.001
		newYLocationW = verticalDistanceBetweenPoints * 0.001
		
		if currentBotLocation.x > optimalLocationW.x then
			newXLocationW = currentBotLocation.x - (horizontalDistanceBetweenPoints * 0.001)
		elseif currentBotLocation.x < optimalLocationW.x then
			newXLocationW = currentBotLocation.x + (horizontalDistanceBetweenPoints * 0.001)
		else
			newXLocationW = currentBotLocation.x
		end
		
			
		if currentBotLocation.y > optimalLocationW.y then
			newYLocationW = currentBotLocation.y - (verticalDistanceBetweenPoints * 0.001)
		elseif currentBotLocation.y < optimalLocationW.y then
			newYLocationW = currentBotLocation.y + (verticalDistanceBetweenPoints * 0.001)
		else
			newYLocationW = currentBotLocation.y
		end
			
		if (bot:IsFacingLocation( optimalLocationW, 25 )) then
			return castWDesire, Vector(newXLocationW, newYLocationW), abilities[2]			
		end
	end
	
	if castEDesire > 0 then
	
		local newXLocationE = 0
		local newYLocationE = 0
		
		local horizontalDistanceBetweenPoints = math.max(optimalLocationE.x, currentBotLocation.x) - math.min(optimalLocationE.x - currentBotLocation.x)
		local verticalDistanceBetweenPoints = math.max(optimalLocationE.y, currentBotLocation.y) - math.min(optimalLocationE.y - currentBotLocation.y)
		
		newXLocationE = horizontalDistanceBetweenPoints * 0.001
		newYLocationE = verticalDistanceBetweenPoints * 0.001
		
		if currentBotLocation.x > optimalLocationE.x then
			newXLocationE = currentBotLocation.x - (horizontalDistanceBetweenPoints * 0.001)
		elseif currentBotLocation.x < optimalLocationE.x then
			newXLocationE = currentBotLocation.x + (horizontalDistanceBetweenPoints * 0.001)
		else
			newXLocationE = currentBotLocation.x
		end
		
			
		if currentBotLocation.y > optimalLocationE.y then
			newYLocationE = currentBotLocation.y - (verticalDistanceBetweenPoints * 0.001)
		elseif currentBotLocation.y < optimalLocationE.y then
			newYLocationE = currentBotLocation.y + (verticalDistanceBetweenPoints * 0.001)
		else
			newYLocationE = currentBotLocation.y
		end
		
		if (bot:IsFacingLocation( optimalLocationE, 10 )) then
			return castEDesire, Vector(newXLocationE, newYLocationE), abilities[3]
		end
	end
	return BOT_DESIRE_NONE
end

----------------------------------------------------------------------------------------------------
-- Function called every frame to determine if and what item(s) to use
----------------------------------------------------------------------------------------------------
local function ItemUsageThink(botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
  -- Using Faerie Fire when needed is top priority
  if botHealthLevel <= 85 then
    faerieFire = mutils.GetItemFaerieFire(bot)
    if mutils.IsItemUsable(bot, faerieFire) then
      bot:Action_UseAbility(faerieFire.item)
      return botState.STATE_HEALING
    elseif mutils.IsItemInBackpack(bot, faerieFire) then
      bot:ActionImmediate_SwapItems(1, faerieFire.slot)
    end
  end

  local itemToUse = nil

  -- Using Salve or Mango when needed
  local state = nil
  if botHealthPercentage <= 0.6 then
    itemToUse = mutils.GetItemFlask(bot)
    state = botState.STATE_HEALING
  elseif botManaPercentage <= 0.6 then
    itemToUse = mutils.GetItemMango(bot)
    state = botState.STATE_IDLE
  end

  if mutils.IsItemUsable(bot, itemToUse) then
    bot:Action_UseAbilityOnEntity(itemToUse.item, bot)
    return state
  elseif mutils.IsItemInBackpack(bot, itemTosUe) then
    bot:ActionImmediate_SwapItems(1, itemToUse.slot)
  end

  -- TP to T1 if we are in base
  -- The assumption here is that this method will be called only after game starts
  -- (i.e., creeps started)
  local tpScroll = mutils.GetItemTPScroll(bot)
  if bot:DistanceFromFountain() <= 5 and tpScroll ~= nil then
    -- Special 'valid' item check for item_tpscroll
    if tpScroll.slot == 15 then
      print("using tp_scroll from "..tostring(bot:DistanceFromFountain()).." on location: "..tostring(mutils.GetT1Location()))
      bot:Action_UseAbilityOnLocation(tpScroll.item, mutils.GetT1Location())
      return botState.STATE_TELEPORTING
    end
  end

  return botState.STATE_IDLE
end

----------------------------------------------------------------------------------------------------

-- Function that is called every frame, does a complete bot takeover
function Think()
    if bot:IsUsingAbility() == true then
		return
	end

	
	-- Initializations
	-----------------------------------------------------------
	dotaTime = DotaTime()
	botAttackDamage = bot:GetAttackDamage()
	attackSpeed = bot:GetAttackSpeed()
	enemyHero = bot:GetNearbyHeroes( 1600, true, BOT_MODE_NONE)
	botLevel = bot:GetLevel()
	botManaLevel = bot:GetMana()
	botManaPercentage = botManaLevel/bot:GetMaxMana()
	botHealthLevel = bot:GetHealth()
  botHealthPercentage = botHealthLevel/bot:GetMaxHealth()
	nearbyCreeps =  bot:GetNearbyLaneCreeps( 1600, false )
	enemyCreeps = bot:GetNearbyLaneCreeps( 1600, true )
	-----------------------------------------------------------

	-- PreGame
	-----------------------------------------------------------
	if DotaTime() < 0 then

     itemWard = mutils.GetItemWard(bot);
    if itemWard.item == nil then
       wardPlaced = true
    else
       wardPlaced = false
    end
    if wardPlaced == false then
      if mutils.IsItemUsable(bot, itemWard) then
         bot:Action_UseAbilityOnLocation(itemWard.item, Vector(-286.881836, 100.408691, 1115.548218))
      elseif mutils.IsItemInBackpack(bot, itemWard) then
         bot:ActionImmediate_SwapItems(1, itemWard.slot)
      end
		else
			mutils.moveToT3Tower(bot)
			return
		end
	end
	-----------------------------------------------------------

	-- First creep block
	-----------------------------------------------------------
	if dotaTime > 0 and creepBlocking == true then
		creepBlocking = mutils.blockCreepWave(bot, enemyHero, enemyCreeps, nearbyCreeps)
		return
	end
	-----------------------------------------------------------

	-- Brain of the bot
	-----------------------------------------------------------
	if dotaTime > 30 or creepBlocking == false then
    newState = ItemUsageThink(botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
    if mutils.IsHealing(bot) then
      newState = botState.STATE_HEALING
    elseif mutils.IsTeleporting(bot) then
      newState = botState.STATE_TELEPORTING
    end

    if state ~= newState then
       state = newState
       print("State changed to: "..tostring(state.name))
    end

    CourierUsageThink()
		AbilityLevelUpThink()

    if state == botState.STATE_TELEPORTING then
      print("doing nothing because teleporting")
      return
    end

		local lastHitDesire, lastHitTarget = heroLastHit(enemyHero, nearbyCreeps, enemyCreeps, botAttackDamage)
		local battleDesire, battleTarget = heroBattleThink(enemyHero, nearbyCreeps)
		local abilityUseDesire, abilityMoveLocation, abilityToUse = AbilityUsageThink(botLevel, botAttackDamage, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
    -- TODO: Move to a safe position when state is STATE_HEALING
		local moveDesire, moveLocation = heroPosition(nearbyCreeps, enemyCreeps, enemyHero)
		
		print("AbilityUseDesire -> ", abilityUseDesire)
		print("BattleDesire -> ", battleDesire)
		print("MoveDesire -> ", moveDesire)
		print("LastHitDesire -> ", lastHitDesire)
		
		if mutils.IsAbilityUseDesireGreatest(lastHitDesire, battleDesire, abilityUseDesire, moveDesire) then
			print("--------------- USING ABILITY ---------------")
			bot:Action_MoveDirectly(enemyHero[1]:GetLocation())
			bot:Action_UseAbility(abilityToUse)
			return
		end
		
		if mutils.IsBattleDesireGreatest(lastHitDesire, battleDesire, abilityUseDesire, moveDesire) then
			print("--------------- BATTLING ---------------")
			bot:Action_AttackUnit(battleTarget, true)
			return
		end
		
		if mutils.IsMoveDesireGreatest(lastHitDesire, battleDesire, abilityUseDesire, moveDesire) then
			print("--------------- MOVING ---------------")
			bot:Action_MoveDirectly(moveLocation)
			return
		end
		
		if mutils.IsLastHitDesireGreatest(lastHitDesire, battleDesire, abilityUseDesire, moveDesire) then
			print("--------------- LAST HITTING ---------------")
			bot:Action_AttackUnit(lastHitTarget, true)
			return
		end
		print("--------------- IDLE ---------------")
	-----------------------------------------------------------
end

