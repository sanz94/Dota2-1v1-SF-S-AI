local U = {};

local RB = Vector(-7174.000000, -6671.00000,  0.000000)
local DB = Vector(7023.000000, 6450.000000, 0.000000)
local maxGetRange = 1600;
local maxAddedRange = 200;
local DEGREE_VALUE_ONE_RADIAN = 57.3248407643
local SF_TIME_TO_TURN_180_DEGREES = 0.10472

local fSpamThreshold = 0.55;

U.towers = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3,
                   TOWER_MID_1, TOWER_MID_2, TOWER_MID_3,
                   TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3,
                   TOWER_BASE_1, TOWER_BASE_2
				   }
U.barracks = { BARRACKS_TOP_MELEE, BARRACKS_TOP_RANGED, 
					 BARRACKS_MID_MELEE, BARRACKS_MID_RANGED, 
					 BARRACKS_BOT_MELEE, BARRACKS_BOT_RANGED
					}				   

local listBoots = {
	['item_boots'] = 45, 
	['item_tranquil_boots'] = 90, 
	['item_power_treads'] = 45, 
	['item_phase_boots'] = 45, 
	['item_arcane_boots'] = 50, 
	['item_guardian_greaves'] = 55,
	['item_travel_boots'] = 100,
	['item_travel_boots_2'] = 100
}

function U.InitiateAbilities(hUnit, tSlots)
	local abilities = {};
	for i = 1, #tSlots do
		abilities[i] = hUnit:GetAbilityInSlot(tSlots[i]);
	end
	return abilities;
end

function U.CantUseAbility(bot)
	return bot:IsAlive() == false or bot:IsInvulnerable() or bot:IsCastingAbility() or bot:IsUsingAbility() or bot:IsChanneling()  
	       or bot:IsSilenced() or bot:IsStunned() or bot:IsHexed()  
		   or bot:HasModifier("modifier_doom_bringer_doom")
		   or bot:HasModifier('modifier_item_forcestaff_active')
end

function U.CanBeCast(ability)
	return ability:IsTrained() and ability:IsFullyCastable() and ability:IsHidden() == false;
end

function U.GetProperCastRange(bIgnore, hUnit, abilityCR)
	local attackRng = hUnit:GetAttackRange();
	if bIgnore then
		return abilityCR;
	elseif abilityCR <= attackRng then
		return attackRng + maxAddedRange;
	elseif abilityCR + maxAddedRange <= maxGetRange then
		return abilityCR + maxAddedRange;
	elseif abilityCR > maxGetRange then
		return maxGetRange;
	else
		return abilityCR;
	end
end


function U.GetUnitCountAroundEnemyTarget(target, nRadius)
	local heroes = target:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);	
	local creeps = target:GetNearbyLaneCreeps(nRadius, false);	
	return #heroes + #creeps;
end

function U.GetNumEnemyAroundMe(npcBot)
	local heroes = npcBot:GetNearbyHeroes(1000, true, BOT_MODE_NONE);	
	return #heroes;
end

function U.CanSpamSpell(bot, manaCost)
	local initialRatio = 1.0;
	if manaCost < 100 then
		initialRatio = 0.6;
	end
	return ( bot:GetMana() - manaCost ) / bot:GetMaxMana() >= ( initialRatio - bot:GetLevel()/(3*30) );
end

function U.GetHumanPlayer()
	local listHumanPlayer = {};
	for i,id in pairs(GetTeamPlayers(GetTeam())) do
		if not IsPlayerBot(id) then
			local humanPlayer = GetTeamMember(i);
			if humanPlayer ~=  nil then
				table.insert(listHumanPlayer, humanPlayer);
			end
		end
	end
	return listHumanPlayer;
end

function U.canBotKillHuman(npcBot)
	local total_damage = 0;
	listHumanPlayer = U.GetHumanPlayer()
	
	if listHumanPlayer ~=  nil then
		total_damage = npcBot:GetEstimatedDamageToTarget(true, listHumanPlayer[1], 5.0, DAMAGE_TYPE_ALL);
	end

	if total_damage > listHumanPlayer[1]:GetHealth() then
		print("Bot can kill human. Total estimated Damage:"..tostring(total_damage))
		return true;
	end
	return false;
end

function U.IsEnemyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local creeps = hSource:GetNearbyLaneCreeps(1600, true);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	creeps = hTarget:GetNearbyLaneCreeps(1600, false);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	return false;
end

function U.IsAllyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local creeps = hSource:GetNearbyLaneCreeps(1600, false);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	creeps = hTarget:GetNearbyLaneCreeps(1600, true);
	for i,creep in pairs(creeps) do
		local tResult = PointToLineDistance(vStart, vEnd, creep:GetLocation());
		if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
			return true;
		end
	end
	return false;
end

function U.IsCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	if not U.IsAllyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius) then
		return U.IsEnemyCreepBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius);
	end
	return true;
end

function U.IsEnemyHeroBetweenMeAndTarget(hSource, hTarget, vLoc, nRadius)
	local vStart = hSource:GetLocation();
	local vEnd = vLoc;
	local heroes = hSource:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
	for i,hero in pairs(heroes) do
		if hero ~= hTarget  then
			local tResult = PointToLineDistance(vStart, vEnd, hero:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
				return true;
			end
		end
	end
	heroes = hTarget:GetNearbyHeroes(1600, false, BOT_MODE_NONE);
	for i,hero in pairs(heroes) do
		if hero ~= hTarget  then
			local tResult = PointToLineDistance(vStart, vEnd, hero:GetLocation());
			if tResult ~= nil and tResult.within and tResult.distance <= nRadius + 50 then
				return true;
			end
		end
	end
	return false;
end

function U.GetUltimateAbility(bot)
	return bot:GetAbilityInSlot(5);
end

--============== ^^^^^^^^^^ NEW FUNCTION ABOVE ^^^^^^^^^ ================--

function U.CanKillTarget(npcTarget, dmg, dmgType)
	return npcTarget:GetActualIncomingDamage( dmg, dmgType ) >= npcTarget:GetHealth(); 
end

function U.GetUpgradedSpeed(bot)
	for i=0,5 do
		local item = bot:GetItemInSlot(i);
		if item ~= nil and listBoots[item:GetName()] ~= nil then
			return bot:GetBaseMovementSpeed()+listBoots[item:GetName()];
		end
	end
	return bot:GetBaseMovementSpeed();
end

function U.IsInRange(npcTarget, npcBot, nCastRange)
	return GetUnitToUnitDistance( npcTarget, npcBot ) <= nCastRange;
end

function U.GetTeamFountain()
	local Team = GetTeam();
	if Team == TEAM_DIRE then
		return DB;
	else
		return RB;
	end
end

function U.IsProjectileIncoming(npcBot, range)
	local incProj = npcBot:GetIncomingTrackingProjectiles()
	for _,p in pairs(incProj)
	do
		if GetUnitToLocationDistance(npcBot, p.location) < range and not p.is_attack and p.is_dodgeable then
			return true;
		end
	end
	return false;
end

function U.GetCorrectLoc(target, delay)
	if target:GetMovementDirectionStability() < 1.0 then
		return target:GetLocation();
	else
		return target:GetExtrapolatedLocation(delay);	
	end
end

function U.GetClosestUnit(units)
	local target = nil;
	if units ~= nil and #units >= 1 then
		return units[1];
	end
	return target;
end


function U.IsFacingLocation(hero,loc,delta)

	local face=hero:GetFacing();
	local move = loc - hero:GetLocation();
	
	move = move / (utilsModule.GetDistance(Vector(0,0),move));

	local moveAngle=math.atan2(move.y,move.x)/math.pi * 180;

	if moveAngle<0 then
		moveAngle=360+moveAngle;
	end
	local face=(face+360)%360;
	
	if (math.abs(moveAngle-face)<delta or math.abs(moveAngle+360-face)<delta or math.abs(moveAngle-360-face)<delta) then
		return true;
	end
	return false;
end

function U.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utilsModule.deepcopy(orig_key)] = utilsModule.deepcopy(orig_value)
        end
        setmetatable(copy, utilsModule.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function U.CanCastOnCreep(unit)
	return unit:CanBeSeen() and unit:IsMagicImmune() == false and unit:IsInvulnerable() == false; 
end

function U.GetNumEnemyCreepsAroundTarget(bot, target, bEnemy, nRadius)
	local locationAoE = bot:FindAoELocation( true, false, target:GetLocation(), 0, nRadius, 0, 0 );
	if ( locationAoE.count >= 1 ) then
		return locationAoE.count
	end
	return 0
end

function U.hasManaToCastSpells(botLevel, botMana)
	if botLevel == 1 and botMana >= 75 then
		return true
	elseif botLevel == 3 and botMana >= 80 then
		return true
	elseif botLevel == 5 and botMana >= 85 then
		return true
	elseif botMana >= 90 then
		return true
	else
		return false
	end
end

function U.isLocationWithinRazeRange(bot, castRange, razeRadius, targetLocation)
	local distanceToLocation = GetUnitToLocationDistance(bot, targetLocation)
	if (distanceToLocation <= (castRange + razeRadius) and distanceToLocation >= (castRange - razeRadius)) then
		return true
	end
	return false
end

function U.isUnitWithinRazeRange(bot, unit, castRange, razeRadius)
	if (GetUnitToUnitDistance(unit, bot) >= castRange - razeRadius
				and GetUnitToUnitDistance(unit, bot) <= castRange + razeRadius  ) then
		return true
	end
	return false
end

function U.fakeCastQRaze(bot) 
	bot:Action_ClearActions(true);
	bot:Action_UseAbility(abilities[1]);
	bot:Action_ClearActions(true);
	
end

function U.fakeCastWRaze(bot) 
	bot:Action_ClearActions(true);
	bot:Action_UseAbility(abilities[2]);
	bot:Action_ClearActions(true);
	
end

function U.fakeCastERaze(bot) 
	bot:Action_ClearActions(true);
	bot:Action_UseAbility(abilities[3]);
	bot:Action_ClearActions(true);
	
end

function U.moveToT3Tower(bot)
	if bot:GetCurrentActionType() == 4 then
		return
	end
	distance = GetUnitToLocationDistance(bot, GetLocationAlongLane(2, 0.28))
	if distance > 200 then
		print("Moving to T3 tower")
		bot:Action_AttackMove(GetLocationAlongLane(2, 0.29))
	end
end

function U.moveToT1Tower(bot)
	if bot:GetCurrentActionType() == 4 then
		return
	end
	print("Moving to T1 tower")
	bot:Action_AttackMove(Vector(473.224609, 389.945801))
end

function U.blockCreepWave(bot, enemyHero, enemyCreeps, nearbyCreeps)
	print("Blocking creep wave")
	local creepToBlock
	local farthestCreepAlongLane
	local lowestDistanceToBlock = 999999
	local lowestDistance = 999999
	local botLocation = bot:GetLocation()
	
	-- If near hero
	if enemyHero~= nil and #enemyHero ~= 0 then
		if GetUnitToUnitDistance(bot, enemyHero[1]) < 550 then
			print("Stopping block")
			return false
		end
	end
	
	
	-- If near enemyCreeps
	if enemyCreeps~= nil and #enemyCreeps ~= 0 then
		if GetUnitToUnitDistance(bot, enemyCreeps[1]) < 200 then
			print("Stopping block")
			return false
		end
	end
	
	-- If near tower
	if GetAmountAlongLane(LANE_MID, bot:GetLocation()).amount > 0.537 then
		if #nearbyCreeps > 0 then
			print("Stopping block")
			return false
		end
	end
	
	-- else block creeps
	if #nearbyCreeps > 0 then
		for i=1,#nearbyCreeps,1 do
			local creepDistance = GetUnitToLocationDistance(nearbyCreeps[i], Vector(-3293.869141, -3455.594727))
			local heroDistance = GetUnitToLocationDistance(bot, Vector(-3293.869141, -3455.594727))
			if creepDistance < lowestDistanceToBlock and creepDistance > heroDistance then
				lowestDistanceToBlock = creepDistance
				creepToBlock = nearbyCreeps[i]
			end
			if creepDistance < lowestDistance then
				lowestDistance = creepDistance
				farthestCreepAlongLane = nearbyCreeps[i]
			end
		end
		
		if farthestCreepAlongLane ~= nil and farthestCreepAlongLane ~= creepToBlock and GetUnitToUnitDistance(farthestCreepAlongLane, bot) > 600 then
			return false
		end
		
		if creepToBlock == nil then
			return false
		end
		
		bot:Action_AttackMove(Vector(creepToBlock:GetLocation().x-75, creepToBlock:GetLocation().y-75))
		return true
	end
	
	return true
end

function U.GetWeakestUnit(units)
	local lowestHP = 10000;
	local lowestUnit = nil;
	for _,unit in pairs(units)
	do
		local hp = unit:GetHealth();
		if hp < lowestHP then
			lowestHP = hp;
			lowestUnit = unit;	
		end
	end
	return lowestUnit;
end

local function GetItem(bot, item_name)
   local itemSlot = bot:FindItemSlot(item_name)
   if itemSlot == -1 then
      return nil
   else
      return bot:GetItemInSlot(itemSlot)
   end
end

function U.GetItemWard(bot)
   return GetItem(bot, "item_ward_observer")
end

function U.GetItemFlask(bot)
   return GetItem(bot, "item_flask")
end

function U.GetItemMango(bot)
   return GetItem(bot, "item_enchanted_mango")
end

function U.GetItemTPScroll(bot)
   return GetItem(bot, "item_tpscroll")
end

function U.GetItemFaerieFire(bot)
   return GetItem(bot, "item_faerie_fire")
end

function U.GetT1Location()
  return GetTower(GetTeam(), TOWER_MID_1):GetLocation()
end

function U.IsHealing(bot)
  return bot:HasModifier("modifier_flask_healing")
end

function U.IsTeleporting(bot)
  return bot:HasModifier("modifier_teleporting")
end

function U.enum(entries)
  local objects = {}
  for id, name in pairs(entries) do
    local object = {
      id=id,
      name=name
    }
    objects[name] = object
    objects[id] = object
  end
  return objects
end

function U.IsUnitNearLoc( nUnit, vLoc, nRange, nDely )

	if nUnit == nil then return false end

	if GetUnitToLocationDistance( nUnit, vLoc ) > 250
	then
		return false
	end

	local nMoveSta = nUnit:GetMovementDirectionStability()
	if nMoveSta < 0.98 then nRange = nRange - 14 end
	if nMoveSta < 0.91 then nRange = nRange - 26 end
	if nMoveSta < 0.81 then nRange = nRange - 30 end

	local fLoc = U.GetCorrectLoc( nUnit, nDely )
	if U.GetLocationToLocationDistance( fLoc, vLoc ) < nRange
	then
		return true
	end


	return false

end

function U.GetCorrectLoc( npcTarget, fDelay )

	local nStability = npcTarget:GetMovementDirectionStability()

	local vFirst = npcTarget:GetLocation()
	local vFuture = npcTarget:GetExtrapolatedLocation( fDelay )
	local vMidFutrue = ( vFirst + vFuture ) * 0.5
	local vLowFutrue = ( vFirst + vMidFutrue ) * 0.5
	local vHighFutrue = ( vFuture + vMidFutrue ) * 0.5


	if nStability < 0.5
	then
		return vLowFutrue
	elseif nStability < 0.7
	then
		return vMidFutrue
	elseif nStability < 0.9
	then
		return vHighFutrue
	end

	return vFuture
end


function U.IsUnitCanBeKill( nUnit, nDamage, nBonus, nCastPoint )

	local nDamageType = DAMAGE_TYPE_MAGICAL

	local nStack = 0
	local nUnitModifier = nUnit:NumModifiers()

	if nUnitModifier >= 1
	then
		for i = 0, nUnitModifier
		do
			if nUnit:GetModifierName( i ) == "modifier_nevermore_shadowraze_debuff"
			then
				nStack = nUnit:GetModifierStackCount( i )
				break
			end
		end
	end

	local nRealDamage = nDamage + nStack * nBonus


	return J.WillKillTarget( nUnit, nRealDamage, nDamageType, nCastPoint )

end

function U.GetFaceTowardDistanceLocation( bot, nDistance )

	local npcBotLocation = bot:GetLocation()
	local tempRadians = bot:GetFacing() * math.pi / 180
	local tempVector = Vector( math.cos( tempRadians ), math.sin( tempRadians ) )

	return npcBotLocation + nDistance * tempVector

end

function U.GetLocationToLocationDistance( fLoc, sLoc )

	local x1 = fLoc.x
	local x2 = sLoc.x
	local y1 = fLoc.y
	local y2 = sLoc.y

	return math.sqrt( math.pow( ( y2-y1 ), 2 ) + math.pow( ( x2-x1 ), 2 ) )

end

function U.GetCreepType( creep )

    if (creep:IsHero() == true) then return "hero" end

	local creepMaxHealth = creep:GetMaxHealth()

	if (creepMaxHealth <= 500) then
		return "ranged"
	elseif (creepMaxHealth <= 900) then
		return "meele"
	elseif (creepMaxHealth <= 1700) then
		return "siege"
	else
		return "tower"
	end
end

function U.GetAttacksPerSecondForCreepType( creepType )

	if (creepType == "ranged") then
		return 1.00
	elseif (creepType == "meele") then
		return 1.00
	elseif (creepType == "siege") then
		return 3.00
	else
		return 0.82
	end
end


function U.IsLastHitDesireGreatest( lastHitDesire, battleDesire, abilityUseDesire, moveDesire )

	if (lastHitDesire > battleDesire) and (lastHitDesire > abilityUseDesire) and (lastHitDesire > moveDesire) then
		return true
	else
		return false
	end
end

function U.IsBattleDesireGreatest( lastHitDesire, battleDesire, abilityUseDesire, moveDesire )

	if (battleDesire > lastHitDesire) and (battleDesire > abilityUseDesire) and (battleDesire > moveDesire) then
		return true
	else
		return false
	end
end

function U.IsAbilityUseDesireGreatest( lastHitDesire, battleDesire, abilityUseDesire, moveDesire )

	if (abilityUseDesire > battleDesire) and (abilityUseDesire > lastHitDesire) and (abilityUseDesire > moveDesire) then
		return true
	else
		return false
	end
end

function U.IsMoveDesireGreatest( lastHitDesire, battleDesire, abilityUseDesire, moveDesire )

	if (moveDesire > battleDesire) and (moveDesire > abilityUseDesire) and (moveDesire > lastHitDesire) then
		return true
	else
		return false
	end
end

function U.DoesBotHaveToTurnToHitCreep(bot, creepTarget)
	local botAngle = bot:GetFacing()
	local botLocation = bot:GetLocation()
	local creepLocation = creepTarget:GetLocation()
	local targetX, targetY = botLocation.x - creepLocation.x   , botLocation.y - creepLocation.y
	local creepAngle = math.atan2(targetX, targetY) * DEGREE_VALUE_ONE_RADIAN

	local creepAngleRelative = creepAngle + 180

	local angleDifference = botAngle - creepAngleRelative

	local timeToTurn = math.abs((SF_TIME_TO_TURN_180_DEGREES * angleDifference) / 180)

	--print("BOT ANGLE", bot:GetFacing())
	--print("CREEP ANGLE", math.atan2(targetX, targetY) * DEGREE_VALUE_ONE_RADIAN)
	--print("ANGLE DIFFERENCE", angleDifference)
	--print("Time to turn", timeToTurn)
			
	if (((botAngle - creepAngleRelative) >= 11.5) or ((botAngle - creepAngleRelative) <= -11.5)) then
		return true, timeToTurn
	else
		return false, 0
	end
end

function U.getDamageMultipler(target)
	local targetArmor = target:GetArmor()
	local numerator = 0.052 * targetArmor
	local denominator = 0.9 + 0.048 * math.abs(targetArmor)
	return 1 - (numerator/denominator)
end

function U.getAttackPointBasedOnIAS(bot)
	local agilityIAS = bot:GetAttributeValue(ATTRIBUTE_AGILITY)

	local botSecondsPerAttack = bot:GetSecondsPerAttack()
	local botAttackPerSecond = 1 / botSecondsPerAttack

	local bonusIAS = (botAttackPerSecond * 160) - 100 - agilityIAS

	local IASTotal = agilityIAS + bonusIAS
	local attackPoint = bot:GetAttackPoint() / ( 1 + (IASTotal / 100))
	return attackPoint
end

function U.GetBotSpellDamage(bot, enemy, timePeriod, abilities)
	if abilities == nil then return 0 end
	local spellDamage = 0
	local timeTaken = timePeriod
	local botMana = bot:GetMana()
	local distanceBetweenBotAndEnemy = GetUnitToUnitDistance(bot, enemy)
	local qRazeManaCost = abilities[1]:GetManaCost()
	local wRazeManaCost = abilities[2]:GetManaCost()
	local eRazeManaCost = abilities[3]:GetManaCost()
	local ultiManaCost = abilities[4]:GetManaCost()
	
	if abilities[3]:IsCooldownReady() == true and (botMana >= eRazeManaCost)  and distanceBetweenBotAndEnemy > 450 and distanceBetweenBotAndEnemy < 950 and bot:IsFacingLocation(enemy:GetLocation(), 10) and abilities[3]:GetCastPoint() <= timeTaken   then
		spellDamage = spellDamage + (abilities[3]:GetAbilityDamage() - (abilities[3]:GetAbilityDamage() * enemy:GetMagicResist()))
		botMana = botMana - abilities[3]:GetManaCost()
		timeTaken = timeTaken - abilities[3]:GetCastPoint()
	end
	
	if abilities[2]:IsCooldownReady() == true and (botMana >= wRazeManaCost) and distanceBetweenBotAndEnemy > 200  and distanceBetweenBotAndEnemy < 700 and bot:IsFacingLocation(enemy:GetLocation(), 10) and abilities[2]:GetCastPoint() <= timeTaken   then
		spellDamage = spellDamage + (abilities[2]:GetAbilityDamage() - (abilities[2]:GetAbilityDamage() * enemy:GetMagicResist()))
		botMana = botMana - abilities[2]:GetManaCost()
		timeTaken = timeTaken - abilities[2]:GetCastPoint()
	end
	
	if abilities[1]:IsCooldownReady() == true and (botMana >= qRazeManaCost) and distanceBetweenBotAndEnemy > 0 and distanceBetweenBotAndEnemy < 450 and bot:IsFacingLocation(enemy:GetLocation(), 10) and abilities[1]:GetCastPoint() <= timeTaken   then
		spellDamage = spellDamage + (abilities[1]:GetAbilityDamage() - (abilities[1]:GetAbilityDamage() * enemy:GetMagicResist()))
		botMana = botMana - abilities[1]:GetManaCost()
		timeTaken = timeTaken - abilities[1]:GetCastPoint()
	end

	if (bot:GetLevel() > 8) and abilities[4]:IsCooldownReady() == true and (botMana >= ultiManaCost) and GetUnitToUnitDistance(bot, enemy) < 100 and abilities[4]:GetCastPoint() <= timeTaken   then
		spellDamage = spellDamage + (abilities[4]:GetAbilityDamage() - (abilities[4]:GetAbilityDamage() * enemy:GetMagicResist()))
		botMana = botMana - abilities[4]:GetManaCost()
		timeTaken = timeTaken - abilities[4]:GetCastPoint()
	end
	
	return spellDamage, (timePeriod - timeTaken)
end


function U.GetEnemySpellDamage(bot, enemy, timePeriod, abilities)
	if abilities == nil then return 0 end

	local spellDamage = 0
	local timeTaken = timePeriod
	local enemyMana = enemy:GetMana()
	local distanceBetweenBotAndEnemy = GetUnitToUnitDistance(bot, enemy)
	local qRazeManaCost = abilities[1]:GetManaCost()
	local wRazeManaCost = abilities[2]:GetManaCost()
	local eRazeManaCost = abilities[3]:GetManaCost()
	local ultiManaCost = abilities[4]:GetManaCost()
	
	if (enemyMana >= eRazeManaCost) and distanceBetweenBotAndEnemy > 450 and distanceBetweenBotAndEnemy < 950 and enemy:IsFacingLocation(bot:GetLocation(), 10) and abilities[3]:GetCastPoint() <= timeTaken  then
		spellDamage = spellDamage + (abilities[3]:GetAbilityDamage() - (abilities[3]:GetAbilityDamage() * bot:GetMagicResist()))
		enemyMana = enemyMana - abilities[3]:GetManaCost()
		timeTaken = timeTaken - abilities[3]:GetCastPoint()
	end
	
	if (enemyMana >= wRazeManaCost) and distanceBetweenBotAndEnemy > 200  and distanceBetweenBotAndEnemy < 700 and enemy:IsFacingLocation(bot:GetLocation(), 10) and abilities[2]:GetCastPoint() <= timeTaken    then
		spellDamage = spellDamage + (abilities[2]:GetAbilityDamage() - (abilities[2]:GetAbilityDamage() * bot:GetMagicResist()))
		enemyMana = enemyMana - abilities[2]:GetManaCost()
		timeTaken = timeTaken - abilities[2]:GetCastPoint()
	end
	
	
	if (enemyMana >= qRazeManaCost) and distanceBetweenBotAndEnemy > 0  and distanceBetweenBotAndEnemy < 450 and enemy:IsFacingLocation(bot:GetLocation(), 10) and abilities[1]:GetCastPoint() <= timeTaken   then
		spellDamage = spellDamage + (abilities[1]:GetAbilityDamage() - (abilities[1]:GetAbilityDamage() * bot:GetMagicResist()))
		enemyMana = enemyMana - abilities[1]:GetManaCost()
		timeTaken = timeTaken - abilities[1]:GetCastPoint()
	end
	
	if (bot:GetLevel() > 5) and (enemyMana >= ultiManaCost) and GetUnitToUnitDistance(bot, enemy) < 1000 and abilities[4]:GetCastPoint() <= timeTaken   then
		spellDamage = spellDamage + (abilities[4]:GetAbilityDamage() - (abilities[4]:GetAbilityDamage() * bot:GetMagicResist()))
		enemyMana = enemyMana - abilities[4]:GetManaCost()
		timeTaken = timeTaken - abilities[4]:GetCastPoint()
	end
	
	return spellDamage, (timePeriod - timeTaken)
end

function U.GetUnitsDamageToEnemyForTimePeriod(unit, enemy, timePeriod, abilities)
	local tPeriod = timePeriod
	local unitSecondsPerAttack = unit:GetSecondsPerAttack()
	local unitAttackPerSecond = 1 / unitSecondsPerAttack
	local spellDamage
	local timeTakenToCastSpells
	if unit:IsBot() == true then
		spellDamage, timeTakenToCastSpells = U.GetBotSpellDamage(unit, enemy, timePeriod, abilities)
	else
		spellDamage, timeTakenToCastSpells = U.GetEnemySpellDamage(unit, enemy, timePeriod, abilities)
	end
	
	tPeriod = tPeriod - timeTakenToCastSpells
	return ((unit:GetAttackDamage() * unit:GetAttackCombatProficiency(enemy) * U.getDamageMultipler(enemy))* (tPeriod / unitSecondsPerAttack)) + spellDamage 
end

return U;