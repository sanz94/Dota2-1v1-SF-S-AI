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

local T1_TOWER_DPS = 100
local T1_TOWER_POSITION = Vector(473.224609, 389.945801)
----------------------------------------------------------------------------------------------------

-- Bot states
----------------------------------------------------------------------------------------------------
local botState = mutils.enum({
    "STATE_IDLE",
    "STATE_HEALING",
    "STATE_TELEPORTING",
    "STATE_MOVING"
})
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
	
	if  mutils.CanBeCast(abilities[1]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) then
		return 0;
	end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeQ+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = bot:GetNearbyLaneCreeps(nCastRangeQ+razeRadius, true);
		local locationAoEForQ = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRangeQ, razeRadius, 0, nDamageQ );

		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end

		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius -30, nCastPoint ) then
			return 1, enemyHero[1]:GetLocation()	
		end
		--if locationAoEForQ.count >= 1 
			--and mutils.isLocationWithinRazeRange(bot, nCastRangeQ, razeRadius, locationAoEForQ.targetloc)
			--and bot:IsFacingLocation(locationAoEForQ.targetloc,10)	then
			--DebugDrawCircle(locationAoEForQ.targetloc, razeRadius, 255, 0, 0)
			--highestDesire = 0.5
			--optimalLocation = locationAoEForQ.targetloc
		--end
	end
	
	return highestDesire, optimalLocation
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

	
	if  mutils.CanBeCast(abilities[2]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) then
		return 0;
	end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeW+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = bot:GetNearbyLaneCreeps(nCastRangeW+razeRadius, true);
		local locationAoEForW = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRangeW, razeRadius, 0, nDamageW );

		
		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end
		
		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius -30, nCastPoint ) then
			return 1, enemyHero[1]:GetLocation()	
		end
		
		--if locationAoEForE.count >= 1 
			--and mutils.isLocationWithinRazeRange(bot, nCastRangeW, razeRadius, locationAoEForW.targetloc)
			--and bot:IsFacingLocation(locationAoEForW.targetloc,10)	then
			--DebugDrawCircle(locationAoEForW.targetloc, razeRadius, 0, 255, 0)
			--highestDesire = 0.5
			--optimalLocation = locationAoEForW.targetloc
		--end
	end
	
	return highestDesire, optimalLocation
end	
----------------------------------------------------------------------------------------------------

-- Calculate if bot wants to use long raze
----------------------------------------------------------------------------------------------------
local function ConsiderE(botLevel, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	local optimalLocation
	local highestDesire = 0
	local botLevel = bot:GetLevel()
	local nDamageE = abilityQ:GetAbilityDamage();
	local nCastPoint = abilities[3]:GetCastPoint();
	local manaCost   = abilities[3]:GetManaCost();
	local nCastLocation = mutils.GetFaceTowardDistanceLocation( bot, nCastRangeE )
	
	if  mutils.CanBeCast(abilities[3]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) then
		return 0;
	end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeE+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = bot:GetNearbyLaneCreeps(nCastRangeE+razeRadius, true);
		local locationAoEForE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRangeE, razeRadius, 0, nDamageE );

		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end
		
		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius -30, nCastPoint ) then
			print("Return")
			return 1, enemyHero[1]:GetLocation()	
		end
		
		--if locationAoEForE.count >= 1 
			--and mutils.isLocationWithinRazeRange(bot, nCastRangeE, razeRadius, nClocationAoEForE.targetloc)
			--and bot:IsFacingLocation(locationAoEForE.targetloc,10)	then
			--DebugDrawCircle(locationAoEForE.targetloc, razeRadius, 0, 0, 255)
		    --highestDesire = 0.5
			--optimalLocation = locationAoEForE.targetloc
		--end
	end
	
	return highestDesire, optimalLocation
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
	local positionNoCreeps = T1_TOWER_POSITION
	local positionNoEnemyCreeps
	local positionAggro
	local positionNeutral
	if nearbyCreeps ~= nil and #nearbyCreeps ~=0 then
		positionNoEnemyCreeps = Vector(nearbyCreeps[1]:GetLocation().x+100, nearbyCreeps[1]:GetLocation().y+100)
	end
	if enemyCreeps ~= nil and #enemyCreeps ~=0 then
		distanceBetweenClosestAndFarthestCreep = GetUnitToUnitDistance(enemyCreeps[1], enemyCreeps[#enemyCreeps])
		positionAggro = Vector(enemyCreeps[#enemyCreeps]:GetLocation().x+(distanceBetweenClosestAndFarthestCreep/2), enemyCreeps[#enemyCreeps]:GetLocation().y+(distanceBetweenClosestAndFarthestCreep/2))
		positionNeutral =  Vector(enemyCreeps[1]:GetLocation().x+400, enemyCreeps[1]:GetLocation().y+400)
	end
	
	if bot:WasRecentlyDamagedByTower(3) then
		if #nearbyCreeps > 1 then
			return BOT_DESIRE_NONE
		else
			if (GetUnitToLocationDistance(bot, T1_TOWER_POSITION) > 100) then
				return BOT_DESIRE_VERY_HIGH, T1_TOWER_POSITION
			end
		end
	end
	if botBattleMode == "defend" and #enemyHero ~= 0 then
		local distanceToExitDamageRadius = 950 - (mutils.GetLocationToLocationDistance(bot:GetLocation(), enemyHero[1]:GetLocation()))
		local timeToExitDamageRadius 
		if distanceToExitDamageRadius >= 0 then
			timeToExitDamageRadius = distanceToExitDamageRadius / bot:GetCurrentMovementSpeed()
		else
			timeToExitDamageRadius = 0
		end
		
		print("CHECK", enemyHero[1]:GetEstimatedDamageToTarget(true, bot, timeToExitDamageRadius, DAMAGE_TYPE_ALL))
		if(GetUnitToUnitDistance(bot, enemyHero[1]) < 950 and enemyHero[1]:GetEstimatedDamageToTarget(true, bot, timeToExitDamageRadius, DAMAGE_TYPE_ALL) > bot:GetHealth()) then
			if (GetUnitToLocationDistance(bot,  Vector(enemyHero[1]:GetLocation().x+955, enemyHero[1]:GetLocation().y+955)) > 50) then
				return BOT_DESIRE_VERY_HIGH,  Vector(enemyHero[1]:GetLocation().x+955, enemyHero[1]:GetLocation().y+955)
			end
		end
	end
		
	if enemyCreeps ~= nil and #enemyCreeps > 0 then
		distanceBetweenClosestAndFarthestCreep = GetUnitToUnitDistance(enemyCreeps[1], enemyCreeps[#enemyCreeps])
		if (distanceBetweenClosestAndFarthestCreep > 500) and botBattleMode == "aggro" then
			if (GetUnitToLocationDistance(bot, positionAggro) > 100) then
				return BOT_DESIRE_MEDIUM, positionAggro
			end
		else
			if (GetUnitToLocationDistance(bot, Vector(enemyCreeps[1]:GetLocation().x+400, enemyCreeps[1]:GetLocation().y+400)) > 100) then
				return BOT_DESIRE_MEDIUM, positionNeutral
			end
		end
	elseif nearbyCreeps ~= nil and #nearbyCreeps > 0 then
		if (GetUnitToLocationDistance(bot,  Vector(nearbyCreeps[1]:GetLocation().x+100, nearbyCreeps[1]:GetLocation().y+100)) > 50) then
			return BOT_DESIRE_MEDIUM, positionNoEnemyCreeps
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
	
	local numberOfEnemyMeeleCreeps = 0
	local numberOfAlliedMeeleCreeps = 0
	
	if enemyCreepTarget == nil and alliedCreepTarget == nil then
		return BOT_DESIRE_NONE
	else
		if enemyCreepTarget ~= nil then
			
			local distanceBetweenCreepAndBot = GetUnitToUnitDistance(bot, enemyCreepTarget)
			local timeForBotAttackToLand = 0
			if (distanceBetweenCreepAndBot > 500) then
				 timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + ((distanceBetweenCreepAndBot - 500) / bot:GetCurrentMovementSpeed()) + bot:GetAttackPoint() 
			else
				 timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + bot:GetAttackPoint()  
			end
			local projectiles = enemyCreepTarget:GetIncomingTrackingProjectiles()
			for _,creep in pairs(nearbyCreeps) do
				if creep:IsFacingLocation(enemyCreepTarget:GetLocation(), 10) then
					numberOfAlliedMeeleCreeps = numberOfAlliedMeeleCreeps + 1
				end
				
				local totalProjectilesDamage = 0
				local projectileWhichKillsIndex = 0
				if (#projectiles ~= 0) then
					for index, projectile in pairs(projectiles) do
						totalProjectilesDamage = totalProjectilesDamage + projectile.caster:GetAttackDamage()
					
						if ((enemyCreepTarget:GetHealth() - totalProjectilesDamage) <= botAttackDamage) then
							projectileWhichKillsIndex = index
							break
						end
					end
				end
				
				if projectileWhichKillsIndex ~= nil and projectileWhichKillsIndex ~= 0 then
					local timeTakenForProjectileToLand = (mutils.GetLocationToLocationDistance(enemyCreepTarget:GetLocation(), projectiles[projectileWhichKillsIndex].location) / projectiles[projectileWhichKillsIndex].caster:GetAttackProjectileSpeed()) 
					if (timeTakenForProjectileToLand <= timeForBotAttackToLand) then
						print("LH2")
						return BOT_DESIRE_MEDIUM, enemyCreepTarget
					end
				end
				
			end
			if #projectiles == 0 then					
				if enemyCreepTarget:GetHealth() < botAttackDamage + (numberOfAlliedMeeleCreeps * 0.5) then
					print("LH3")
					return BOT_DESIRE_MEDIUM, enemyCreepTarget
				end
			end
		end
			
		if alliedCreepTarget ~= nil then
			local distanceBetweenCreepAndBot = GetUnitToUnitDistance(bot, alliedCreepTarget)
			local timeForBotAttackToLand = 0
			if (distanceBetweenCreepAndBot > 500) then
				 timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + ((distanceBetweenCreepAndBot - 500) / bot:GetCurrentMovementSpeed()) + bot:GetAttackPoint() 
			else
				 timeForBotAttackToLand = (distanceBetweenCreepAndBot / bot:GetAttackProjectileSpeed()) + bot:GetAttackPoint()  
			end
			local projectiles = alliedCreepTarget:GetIncomingTrackingProjectiles()
			for _,creep in pairs(enemyCreeps) do
				local creepDistance = GetUnitToUnitDistance(alliedCreepTarget,creep)
				if creep:IsFacingLocation(alliedCreepTarget:GetLocation(), 10) then
					numberOfEnemyMeeleCreeps = numberOfEnemyMeeleCreeps + 1
				end
				
				local totalProjectilesDamage = 0
				local projectileWhichKillsIndex = 0
				if (#projectiles ~= 0) then
					for index, projectile in pairs(projectiles) do
						totalProjectilesDamage = totalProjectilesDamage + projectile.caster:GetAttackDamage()
						if ((alliedCreepTarget:GetHealth() - totalProjectilesDamage) <= botAttackDamage) then
							projectileWhichKillsIndex = index
						end
					end
				end
				
				if projectileWhichKillsIndex ~= nil and projectileWhichKillsIndex ~= 0 then
					local timeTakenForProjectileToLand = (mutils.GetLocationToLocationDistance(alliedCreepTarget:GetLocation(), projectiles[projectileWhichKillsIndex].location) / projectiles[projectileWhichKillsIndex].caster:GetAttackProjectileSpeed()) 
					if (timeTakenForProjectileToLand <= timeForBotAttackToLand) then
						return BOT_DESIRE_MEDIUM, alliedCreepTarget
					end
				end
				
			end
			
			if #projectiles == 0 then
				if enemyCreeps ~= nil and #enemyCreeps > 0 then
					for i=1,#enemyCreeps,1 do
						if enemyCreeps[i]:GetHealth() < botAttackDamage + (numberOfEnemyMeeleCreeps * 0.5) then
							return BOT_DESIRE_MEDIUM, enemyCreeps[i]
						end
					end
				end
			end
			
		end
	end
	
	if enemyCreeps ~= nil and #enemyCreeps > 0 then
		for i=1,#enemyCreeps,1 do
			if enemyCreeps[i]:GetHealth() < botAttackDamage then
				print("LH1")
				return BOT_DESIRE_MEDIUM, enemyCreeps[i]
			end
		end
	end
	
	if nearbyCreeps ~= nil and #nearbyCreeps > 0 then
		for i=1,#nearbyCreeps,1 do
			if nearbyCreeps[i]:GetHealth() < botAttackDamage then
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
	local meeleCreepCurrentDamage = 0
	local rangeCreepCurrentDamage = 0
	
	local enemyMeeleCreepsNearBot = bot:GetNearbyLaneCreeps( 100, true )
	if #enemyMeeleCreepsNearBot > 0 then
		meeleCreepCurrentDamage = enemyMeeleCreepsNearBot[1]:GetAttackDamage()
	end
	
	local enemyRangeCreepsHittingBot = 0
	
	local botProjectiles = bot:GetIncomingTrackingProjectiles()
	if (#botProjectiles ~= 0) then
		for index, projectile in pairs(botProjectiles) do
			if projectile.caster:IsCreep() and projectile.caster:GetMaxHealth() < 900 then
				enemyRangeCreepsHittingBot = enemyRangeCreepsHittingBot + 1
				rangeCreepCurrentDamage = projectile.caster:GetAttackDamage()
			end
		end
	end
	
	local enemyCreepsDPS = (#enemyMeeleCreepsNearBot * meeleCreepCurrentDamage) + (enemyRangeCreepsHittingBot * rangeCreepCurrentDamage)
	
	
	local alliedMeeleCreepsNearEnemy = enemyHero[1]:GetNearbyLaneCreeps( 100, true )
	if #alliedMeeleCreepsNearEnemy > 0 then
		meeleCreepCurrentDamage = alliedMeeleCreepsNearEnemy[1]:GetAttackDamage()
	end
	
	local alliedRangeCreepsHittingEnemy = 0
	
	local enemyProjectiles = enemyHero[1]:GetIncomingTrackingProjectiles()
	if (#enemyProjectiles ~= 0) then
		for index, projectile in pairs(enemyProjectiles) do
			if projectile.caster:IsCreep() and projectile.caster:GetMaxHealth() < 900 then
				alliedRangeCreepsHittingEnemy = alliedRangeCreepsHittingEnemy + 1
				rangeCreepCurrentDamage = projectile.caster:GetAttackDamage()
			end
		end
	end
	
	local alliedCreepsDPS = (#alliedMeeleCreepsNearEnemy * meeleCreepCurrentDamage) + (alliedRangeCreepsHittingEnemy * rangeCreepCurrentDamage)
	
	local botAttacksPerSecond = 1/bot:GetAttackSpeed()
	local botDPS = bot:GetAttackDamage() * botAttacksPerSecond
	
	local enemyAttacksPerSecond = 1/enemyHero[1]:GetAttackSpeed()
	local enemyDPS = enemyHero[1]:GetAttackDamage() * botAttacksPerSecond
	
	local enemyHeroEstimatedDamage = enemyHero[1]:GetEstimatedDamageToTarget( true, bot, 3, DAMAGE_TYPE_ALL )
	local botEstimatedDamage = bot:GetEstimatedDamageToTarget( true, enemyHero[1], 3, DAMAGE_TYPE_ALL )
	
	local timeForBotToDie = bot:GetHealth() / (enemyDPS + enemyCreepsDPS)
	local timeForEnemeyToDie = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS)
	
	if enemyHero[1]:GetHealth() < bot:GetHealth() then
		if #enemyMeeleCreepsNearBot == 0 then
			botBattleMode = "aggro"
		elseif (enemyDPS + enemyCreepsDPS) <= (botDPS + alliedCreepsDPS) then
			botBattleMode = "aggro"
		else
			botBattleMode = "neutral"
		end
	elseif bot:GetHealth() < enemyHero[1]:GetHealth() and timeForBotToDie < timeForEnemeyToDie then
		botBattleMode = "defend"
	else
		botBattleMode = "neutral"
	end
	
	print("Current mode: ", botBattleMode)
	
	if towersInRange ~= nil and #towersInRange > 0 then
		local timeToKillEnemy = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS)
		local timeToKillBot = bot:GetHealth() / (enemyDPS + T1_TOWER_DPS + enemyCreepsDPS)
		if (timeToKillBot < timeToKillEnemy) then
			return BOT_DESIRE_NONE
		end
	end
	
	local pvpDistance = GetUnitToUnitDistance(bot, enemyHero[1])
	--if #enemyHero == 0 or (mutils.CanBeCast(abilities[1]) == true and enemyHero[1]:HasModifier("modifier_nevermore_shadowraze_debuff") == true) then
		--return BOT_DESIRE_NONE
	--end

	
	if bot:WasRecentlyDamagedByTower(1) then
		if #nearbyCreeps ~=0 then
			return BOT_DESIRE_VERY_HIGH, nearbyCreeps[1]
		else
			return BOT_DESIRE_NONE
		end
	end
	
	if botEstimatedDamage > enemyHero[1]:GetHealth() then
		local timeToKillEnemy = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS)
		local timeToKillBot = bot:GetHealth() / (enemyDPS + enemyCreepsDPS)

		if (timeToKillEnemy < timeToKillBot) then
			return BOT_DESIRE_ABSOLUTE, enemyHero[1]
		else
			return BOT_DESIRE_NONE
		end
	end
	
	if enemyHeroEstimatedDamage > bot:GetHealth() then
		return BOT_DESIRE_NONE
	end

	if botBattleMode == "neutral" then
		if bot:WasRecentlyDamagedByAnyHero(1) then
			return BOT_DESIRE_MEDIUM, enemyHero[1]
		end
	end
	
	if botBattleMode == "aggro" then
		local timeToKillBot = bot:GetHealth() / (enemyDPS + enemyCreepsDPS)
		local timeToKillEnemy = enemyHero[1]:GetHealth() / (botDPS + alliedCreepsDPS) 
		print("Time to kill bot : ", timeToKillBot)
		print("Time to kill enemy : ", timeToKillEnemy)
		if timeToKillBot > timeToKillEnemy then
			return BOT_DESIRE_HIGH, enemyHero[1]
		else
			return BOT_DESIRE_NONE
		end
		
		if (pvpDistance ~= 0 and pvpDistance <= attackRange) then
			if (bot:GetLevel() <= 6 and #(bot:GetNearbyLaneCreeps( 200, true )) > 1) then
				return BOT_DESIRE_NONE
			else
				return BOT_DESIRE_HIGH, enemyHero[1]
			end
		end
		
		local botAnimActivity = bot:GetAnimActivity()
		if (botAnimActivity == BOT_ANIMATION_IDLE) then
			print("Attacking because bot is idle")
			return BOT_DESIRE_HIGH, enemyHero[1]
		end
	end
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
			return BOT_DESIRE_MEDIUM, Vector(newXLocationQ, newYLocationQ), abilities[1]
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
			return BOT_DESIRE_MEDIUM, Vector(newXLocationW, newYLocationW), abilities[2]			
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
			return BOT_DESIRE_MEDIUM, Vector(newXLocationE, newYLocationE), abilities[3]
		end
	end
	return BOT_DESIRE_NONE
end

----------------------------------------------------------------------------------------------------
-- Function called every frame to determine what items to buy
----------------------------------------------------------------------------------------------------
local function ItemPurchaseThink(botManaPercentage, botHealthPercentage)
  if bot:DistanceFromFountain() <= 5 and mutils.GetItemTPScroll(bot) == nil then
    table.insert(itemToBuy, 1, "item_tpscroll")
  end

	if itemsToBuy[1] ~= "item_flask" and (botHealthPercentage <= 0.6) then
		table.insert(itemsToBuy, 1, "item_flask")
	end

	if itemsToBuy[1] ~= "item_enchanted_mango" and (botManaPercentage <= 0.6) then
		table.insert(itemsToBuy, 1, "item_enchanted_mango")
	end
end

----------------------------------------------------------------------------------------------------
-- Function called every frame to determine if and what item(s) to use
----------------------------------------------------------------------------------------------------
local function ItemUsageThink(botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
  -- Using Faerie Fire when needed is top priority
  if botHealthLevel <= 85 then
    faerieFire = mutils.GetItemFaerieFire(bot)
    if faerieFire ~= nil then
      bot:Action_UseAbility(faerieFire)
      return botState.STATE_HEALING
    end
  end

  local item_to_use = nil

  -- Using Salve or Mango when needed
  local state = nil
  if botHealthPercentage <= 0.6 then
    item_to_use = mutils.GetItemFlask(bot)
    state = botState.STATE_HEALING
  elseif botManaPercentage <= 0.6 then
    item_to_use = mutils.GetItemMango(bot)
    state = botState.STATE_IDLE
  end

  if item_to_use ~= nil then
    bot:Action_UseAbilityOnEntity(item_to_use, bot)
    return state
  end

  -- TP to T1 if we are in base
  -- The assumption here is that this method will be called only after game starts
  -- (i.e., creeps started)
  local tpScroll = mutils.GetItemTPScroll(bot)
  if bot:DistanceFromFountain() <= 5 and tpScroll ~= nil then
    print("using tp_scroll from "..tostring(bot:DistanceFromFountain()).." on location: "..tostring(mutils.GetT1Location()))
    bot:Action_UseAbilityOnLocation(tpScroll, mutils.GetT1Location())
    return botState.STATE_TELEPORTING
  end

  return botState.STATE_IDLE
end

----------------------------------------------------------------------------------------------------

-- Function that is called every frame, does a complete bot takeover
function Think()
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
			if itemWard == nil then
				wardPlaced = true
			else
				wardPlaced = false
			end
		if wardPlaced == false then
			bot:Action_UseAbilityOnLocation(itemWard, Vector(-286.881836, 100.408691, 1115.548218));
		else
			mutils.moveToT3Tower(bot)
		end
	end
	-----------------------------------------------------------

	-- First creep block
	-----------------------------------------------------------
	if dotaTime > 0 and dotaTime < 30 and creepBlocking == true then
		creepBlocking = mutils.blockCreepWave(bot, nearbyCreeps)

	end
	-----------------------------------------------------------

	-- Brain of the bot
	-----------------------------------------------------------		
	if dotaTime > 30 or creepBlocking == false then
    ItemPurchaseThink(botManaPercentage, botHealthPercentage)
    state = ItemUsageThink(botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
    if mutils.IsHealing(bot) then
      state = botState.STATE_HEALING
    elseif mutils.IsTeleporting(bot) then
      state = botState.STATE_TELEPORTING
    end

    print("Current State: "..tostring(state.name))

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
			bot:Action_MoveDirectly(abilityMoveLocation)
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
			bot:Action_MoveDirectly(Vector(moveLocation.x - 1, moveLocation.y - 1))
			return
		end
		
		if mutils.IsLastHitDesireGreatest(lastHitDesire, battleDesire, abilityUseDesire, moveDesire) then
			print("--------------- LAST HITTING ---------------")
			bot:Action_AttackUnit(lastHitTarget, true)
			return
		end
	end
	-----------------------------------------------------------
end

