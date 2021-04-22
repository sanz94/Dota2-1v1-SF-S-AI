X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(3));

local buildSf = {2,1,1,2,1,2,1,2,4,3,3,3,4,3,4}

X["builds"] = {
	{4,1,1,4,1,4,1,4,6,5,5,5,6}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  buildSf, skills, 
	  {1,4,6,8}, talents
);

return X