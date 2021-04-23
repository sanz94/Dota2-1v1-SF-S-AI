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
----------------------------------------------------------------------------------------------------

-- Hard coded values
----------------------------------------------------------------------------------------------------
local attackRange = 500
local nCastRangeQ = 200
local nCastRangeW = 450
local nCastRangeE = 700	
local razeRadius = 250
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
	
	--if  mutils.CanBeCast(abilities[1]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) then
		--return 1;
	--end
	
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

	
	--if  mutils.CanBeCast(abilities[2]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) then
		--return 0;
	--end
	
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
	
	--if  mutils.CanBeCast(abilities[3]) == false or mutils.hasManaToCastSpells(botLevel, botManaLevel) then
		--return 0;
	--end
	
	if ( botLevel >= 2 ) then
		local enemyHeroInRazeRadius = bot:GetNearbyHeroes(nCastRangeE+razeRadius, true, BOT_MODE_NONE);
		local enemyCreepsInRazeRadius = bot:GetNearbyLaneCreeps(nCastRangeE+razeRadius, true);
		local locationAoEForE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRangeE, razeRadius, 0, nDamageE );

		--if #enemyHero ~= 0 and #enemyHeroInRazeRadius ~= 0 then
			--return 1, enemyHero[1]:GetLocation()	
		--end
		
		if #enemyHero ~= 0 and mutils.IsUnitNearLoc( enemyHero[1], nCastLocation, razeRadius -30, nCastPoint ) then
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
local function heroPosition(nearbyCreeps, enemyCreeps)

	--print("TEST2", bot:IsCastingAbility())
	--print("TEST1", bot:GetCurrentActiveAbility())

	if enemyCreeps ~= nil and #enemyCreeps > 0 then
		bot:Action_MoveToLocation(Vector(enemyCreeps[1]:GetLocation().x+400, enemyCreeps[1]:GetLocation().y+400))
	elseif nearbyCreeps ~= nil and #nearbyCreeps > 0 then
		bot:Action_MoveToLocation(Vector(nearbyCreeps[1]:GetLocation().x+100, nearbyCreeps[1]:GetLocation().y+100))
	else
		mutils.moveToT1Tower(bot)
	end
end
----------------------------------------------------------------------------------------------------

-- Function called every frame for helping the bot last hitting
----------------------------------------------------------------------------------------------------
local function heroLastHit(enemyHero, nearbyCreeps, enemyCreeps, botAttackDamage)

	if enemyCreeps ~= nil and #enemyCreeps > 0 then
		for i=1,#enemyCreeps,1 do
			if enemyCreeps[i]:GetHealth() < botAttackDamage then
				print("Last hitting enemy creep")
				bot:Action_AttackUnit(enemyCreeps[i], false)
			end
		end
	end
	
	if nearbyCreeps ~= nil and #nearbyCreeps > 0 then
		for i=1,#nearbyCreeps,1 do
			if nearbyCreeps[i]:GetHealth() < botAttackDamage then
				print("Denying allied creep")
				bot:Action_AttackUnit(nearbyCreeps[i], false)
			end
		end
	end
	
		
	local alliedCreepTarget = mutils.GetWeakestUnit(nearbyCreeps);
	local enemyCreepTarget = mutils.GetWeakestUnit(enemyCreeps);
	
	local numberOfEnemyMeeleCreeps = 0
	local numberOfAlliedMeeleCreeps = 0
	
	if enemyCreepTarget == nil and alliedCreepTarget == nil then
		return
	else
		if enemyCreepTarget ~= nil then

			local timeForBotAttackToLand = GetUnitToUnitDistance(bot, enemyCreepTarget) / bot:GetAttackProjectileSpeed()
			local projectiles = enemyCreepTarget:GetIncomingTrackingProjectiles()
			for _,creep in pairs(nearbyCreeps) do
				local creepDistance = GetUnitToUnitDistance(enemyCreepTarget,creep)
				if creep:IsFacingLocation(enemyCreepTarget:GetLocation(), 10) then
					numberOfAlliedMeeleCreeps = numberOfAlliedMeeleCreeps + 1
				end
				
				local totalProjectilesDamage = 0
				local projectileWhichKillsIndex = 0
				if (#projectiles ~= 0) then
					for index, projectile in pairs(projectiles) do
						totalProjectilesDamage = totalProjectilesDamage + projectile.caster:GetAttackDamage()
						if (totalProjectilesDamage >= enemyCreepTarget:GetHealth() or ((enemyCreepTarget:GetHealth() - totalProjectilesDamage) < botAttackDamage)) then
							projectileWhichKillsIndex = index
						end
					end
				end
				
				if projectileWhichKillsIndex ~= nil and projectileWhichKillsIndex ~= 0 then
					local timeTakenForProjectileToLand = (mutils.GetLocationToLocationDistance(enemyCreepTarget:GetLocation(), projectiles[projectileWhichKillsIndex].location) / projectiles[projectileWhichKillsIndex].caster:GetAttackProjectileSpeed()) + bot:GetAttackPoint() + (numberOfAlliedMeeleCreeps * 1.5)
					if (timeTakenForProjectileToLand <= timeForBotAttackToLand) then
						bot:Action_AttackUnit(enemyCreepTarget, true);
					end
				end
				
			end
			
		elseif alliedCreepTarget ~= nil then
			local timeForBotAttackToLand = GetUnitToUnitDistance(bot, alliedCreepTarget) / bot:GetAttackProjectileSpeed()
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
						if (totalProjectilesDamage >= alliedCreepTarget:GetHealth() or ((alliedCreepTarget:GetHealth() - totalProjectilesDamage) < botAttackDamage)) then
							projectileWhichKillsIndex = index
						end
					end
				end
				
				if projectileWhichKillsIndex ~= nil and projectileWhichKillsIndex ~= 0 then
					local timeTakenForProjectileToLand = (mutils.GetLocationToLocationDistance(alliedCreepTarget:GetLocation(), projectiles[projectileWhichKillsIndex].location) / projectiles[projectileWhichKillsIndex].caster:GetAttackProjectileSpeed()) + bot:GetAttackPoint() + (numberOfEnemyMeeleCreeps * 1.5)
					if (timeTakenForProjectileToLand <= timeForBotAttackToLand) then
						bot:Action_AttackUnit(alliedCreepTarget, true);
					end
				end
				
			end
		end
	end
end
----------------------------------------------------------------------------------------------------

-- Function called every frame to determine what items to buy
----------------------------------------------------------------------------------------------------
local function ItemPurchaseThink(botManaPercentage, botHealthPercentage)
	
	if itemsToBuy[1] ~= "item_flask" and (botHealthPercentage <= 60) then
		table.insert(itemsToBuy, 1, "item_flask")
	end
	
	if itemsToBuy[1] ~= "item_enchanted_mango" and (botManaPercentage <= 60) then
		table.insert(itemsToBuy, 1, "item_enchanted_mango")
	end
	
end
----------------------------------------------------------------------------------------------------

-- Function called every frame to determine what items to buy
----------------------------------------------------------------------------------------------------
local function heroBattleThink(enemyHero)
	
	local pvpDistance = GetUnitToUnitDistance(bot, enemyHero[1])
	
	if bot:WasRecentlyDamagedByAnyHero(1) then
		bot:Action_AttackUnit( enemyHero[1], true )
		return
	end
	
	if (pvpDistance ~= 0 and pvpDistance <= attackRange) then
		bot:Action_AttackUnit( enemyHero[1], true )
	end
	
end
----------------------------------------------------------------------------------------------------

-- Function called every frame to determine bot spell usage
----------------------------------------------------------------------------------------------------
local function AbilityUsageThink(botLevel, botAttackDamage, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	
	local manaBasedDesire = 0
	local levelBasedDesire = 0
	local currentBotLocation = bot:GetLocation()
	
	if mutils.CantUseAbility(bot) or mutils.hasManaToCastSpells(botLevel, botManaLevel) == false then
		return
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
		bot:Action_ClearActions(true);
		bot:Action_UseAbility(abilities[4]);		
		return
	end
	
	if castQDesire > 0 then
		bot:Action_ClearActions(true);
		
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
		
		DebugDrawCircle( Vector(newXLocationQ, newYLocationQ), 200, 0, 0, 255 )
		bot:Action_MoveDirectly(Vector(newXLocationQ, newYLocationQ))
		if (bot:IsFacingLocation( optimalLocationQ, 50 )) then
			bot:Action_UseAbility(abilities[1]);		
		end
		return
	end
	
	if castWDesire > 0 then
		bot:Action_ClearActions(true);
		
		
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
		
		DebugDrawCircle( Vector(newXLocationW, newYLocationW), 200, 0, 255, 0 )
		bot:Action_MoveDirectly(Vector(newXLocationW, newYLocationW))
		
		if (bot:IsFacingLocation( optimalLocationW, 25 )) then
			bot:Action_UseAbility(abilities[2]);		
		end
		return
	end
	
	if castEDesire > 0 then
		bot:Action_ClearActions(true);
		
		
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
		DebugDrawCircle( Vector(newXLocationE, newYLocationE), 200, 255, 0, 0 )
		bot:Action_MoveDirectly(Vector(newXLocationE, newYLocationE))
		
		if (bot:IsFacingLocation( optimalLocationE, 10 )) then
			bot:Action_UseAbility(abilities[3]);		
		end

		return
	end
	
end
----------------------------------------------------------------------------------------------------

-- Function that is called every frame, does a complete bot takeover
function Think()

	-- Early exit conditions
	if bot:IsUsingAbility() then
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
		CourierUsageThink()
		AbilityLevelUpThink()
		ItemPurchaseThink(botManaPercentage, botHealthPercentage)

		heroPosition(nearbyCreeps, enemyCreeps)
		heroLastHit(enemyHero, nearbyCreeps, enemyCreeps, botAttackDamage)
		heroBattleThink(enemyHero)
		AbilityUsageThink(botLevel, botAttackDamage, enemyHero, enemyCreeps, botManaLevel, botManaPercentage, botHealthLevel, botHealthPercentage)
	end
	-----------------------------------------------------------
end

