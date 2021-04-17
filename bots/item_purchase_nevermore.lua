X = {}
X["tableItemsToBuy"] = { 
				"item_faerie_fire","item_quelling_blade",
				"item_enchanted_mango","item_enchanted_mango","item_tango",
				"item_slippers", "item_flask",
				"item_magic_stick","item_branches","item_branches","item_recipe_magic_wand", 
				"item_boots","item_gloves","item_boots_of_elves",
				"item_blade_of_alacrity","item_boots_of_elves","item_recipe_yasha"
};


----------------------------------------------------------------------------------------------------
local npcBot = GetBot()
function ItemPurchaseThink()
	
	if ( #X["tableItemsToBuy"] == 0 )
	then
		npcBot:SetNextItemPurchaseValue( 0 );
		return;
	end

	local sNextItem = X["tableItemsToBuy"][1];

	npcBot:SetNextItemPurchaseValue( GetItemCost( sNextItem ) );

	if ( npcBot:GetGold() >= GetItemCost( sNextItem ) )
	then
		npcBot:ActionImmediate_PurchaseItem( sNextItem );
		table.remove( X["tableItemsToBuy"], 1 );
	end

end

return X