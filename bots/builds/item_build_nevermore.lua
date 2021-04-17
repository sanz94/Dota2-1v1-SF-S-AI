X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(3));

local buildSf = {1,4,1,4,1,4,1,4,6,5,5,6,5,5,6}

X["builds"] = {
	{1,4,1,4,1,4,1,4,6,5,5,5,6}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  buildSf, skills, 
	  {1,4,6,8}, talents
);

return X