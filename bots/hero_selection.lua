
function Think()
  if(GetTeam() == TEAM_RADIANT) then
	SelectHero(1, "npc_dota_hero_rubick");
    SelectHero(2, "npc_dota_hero_rubick");
    SelectHero(3, "npc_dota_hero_rubick");
    SelectHero(4, "npc_dota_hero_rubick");

  else
	SelectHero(5, "npc_dota_hero_nevermore");
    SelectHero(6, "npc_dota_hero_rubick");
    SelectHero(7, "npc_dota_hero_rubick");
    SelectHero(8, "npc_dota_hero_rubick");
    SelectHero(9, "npc_dota_hero_rubick");
   
  end
end