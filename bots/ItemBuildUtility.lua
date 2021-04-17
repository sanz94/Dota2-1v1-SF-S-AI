local X = {}

local rand = true;

function X.FillTalenTable(npcBot)
	local talents = {};
	for i = 0, 23 
	do
		local ability = npcBot:GetAbilityInSlot(i);
		if ability ~= nil and ability:IsTalent() then
			table.insert(talents, ability:GetName());
		end
	end
	return talents;
end

function X.FillSkillTable(npcBot, slots)
	local skills = {};
	for _,slot in pairs(slots)
	do
		table.insert(skills, npcBot:GetAbilityInSlot(slot):GetName());
	end
	return skills;
end

function X.GetSlotPattern(nPattern)
	if nPattern == 1 then
		return {0,1,2,5};
	elseif  nPattern == 2 then
		return {0,1,3,5};	
	elseif  nPattern == 3 then
		return {0,3,4,5};		
	end
end

function X.GetBuildPattern(status, s, skills, t, talents)
	if status == "normal" 
	then
		if rand then
			return {
				skills[s[1]],    skills[s[2]],    skills[s[3]],    skills[s[4]],    skills[s[5]],
				skills[s[6]],    skills[s[7]],    skills[s[8]],    skills[s[9]],    talents[1],
				skills[s[10]],   skills[s[11]],   skills[s[12]],   skills[s[13]],   talents[4],
				skills[s[14]],    	"-1",      	  skills[s[15]],    	"-1",   	talents[6],
					"-1",   		"-1",   		"-1",       		"-1",       talents[8]
			}
		else
			return {
				skills[s[1]],    skills[s[2]],    skills[s[3]],    skills[s[4]],    skills[s[5]],
				skills[s[6]],    skills[s[7]],    skills[s[8]],    skills[s[9]],    talents[t[1]],
				skills[s[10]],   skills[s[11]],   skills[s[12]],   skills[s[13]],   talents[t[2]],
				skills[s[14]],    	"-1",      	  skills[s[15]],    	"-1",   	talents[t[3]],
					"-1",   		"-1",   		"-1",       		"-1",       talents[t[4]]
			}
		end
	end	
end

function X.GetRandomBuild(tBuilds)
	return tBuilds[1]
end	

return X;