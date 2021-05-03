local mutils = require(GetScriptDirectory() ..  "/MyUtility")

X = {}
X["tableItemsToBuy"] = {
  "item_ward_observer","item_faerie_fire","item_quelling_blade",
  "item_slippers", "item_flask", "item_slippers",
  "item_magic_stick","item_branches","item_branches","item_recipe_magic_wand","item_circlet","item_recipe_wraith_band",
  "item_boots","item_gloves","item_boots_of_elves",
  "item_blade_of_alacrity","item_boots_of_elves","item_recipe_yasha"
};


----------------------------------------------------------------------------------------------------
local npcBot = GetBot()

function GetBotHealthyStats()
  botManaLevel = npcBot:GetMana()
	botManaPercentage = botManaLevel/npcBot:GetMaxMana()
	botHealthLevel = npcBot:GetHealth()
  botHealthPercentage = botHealthLevel/npcBot:GetMaxHealth()
  return botManaPercentage, botHealthPercentage
end

function ItemPurchaseThink()
  botManaPercentage, botHealthPercentage = GetBotHealthyStats()

  if npcBot:DistanceFromFountain() <= 5 and mutils.GetItemTPScroll(npcBot) == nil
     and X["tableItemsToBuy"][1] ~= "item_tpscroll" then
    table.insert(X["tableItemsToBuy"], 1, "item_tpscroll")
  end

	if X["tableItemsToBuy"][1] ~= "item_flask" and (botHealthPercentage <= 0.6) then
		table.insert(X["tableItemsToBuy"], 1, "item_flask")
	end

	if X["tableItemsToBuy"][1] ~= "item_enchanted_mango" and (botManaPercentage <= 0.6) then
		table.insert(X["tableItemsToBuy"], 1, "item_enchanted_mango")
	end

	if ( #X["tableItemsToBuy"] == 0 )
	then
    print("nothing to buy")
		npcBot:SetNextItemPurchaseValue( 0 );
		return;
	end

	local sNextItem = X["tableItemsToBuy"][1];

	npcBot:SetNextItemPurchaseValue( GetItemCost( sNextItem ) );

	if ( npcBot:GetGold() >= GetItemCost( sNextItem ) )
	then
    print("purchasing item: "..sNextItem)
		npcBot:ActionImmediate_PurchaseItem( sNextItem );
		table.remove( X["tableItemsToBuy"], 1 );
	end

end

return X
