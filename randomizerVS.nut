//FY VScript by Vic Gasior (Rivi the Warlock)
//Using give_tf_weapon library by Yaki
ClearGameEventCallbacks()	//Clears any pre-existing OnGameEvent listeners. WARNING: If you're using other events, be aware that this is here or just comment this function out.

// Player regenerate event
// GTFW uses this function for cleaning up any unused entities that would otherwise clutter and possibly crash the server if ent count gets too high.

function OnGameEvent_post_inventory_application(params)
{
	if (!("userid" in params)) return;
//Defines player handle as hPlayer
	local hPlayer = GetPlayerFromUserID(params.userid);

// REQUIRED ( Must be at the beginning! )
	hPlayer.GTFW_Cleanup();	// Anytime a weapon or wearable is created, it won't delete by itself!! This function will remove those entities for you.
	

// OPTIONAL
// - LOADOUTS
//	 This feature is for if you want to save and load player loadouts.
//	 Without this generally what happens is after you give a weapon, resupply will just delete it completely and not give it back.
//	 This fixes that!
	EntFireByHandle(hPlayer,"RunScriptCode","self.LoadLoadout()",0.0,hPlayer,hPlayer);
	
// - CUSTOM CLASS ARMS FOR FIRST-PERSON
//	 As it says on the tin. This one is only if you want to restore custom class arms after touching resupply.
//	 You can set custom arms with function hPlayer.SetCustomClassArms(my_model_path, true)
//	  If you set param 2 to `true`, it'll save the arms in memory to be loaded by the below function.
//	  Otherwise, setting to `false` or just not including it won't save it in memory. It'll only last until GTFW_Cleanup() removes it.
	EntFireByHandle(hPlayer,"RunScriptCode","self.GTFW_RestoreCustomClassArms()",0.0,hPlayer,hPlayer);
}

//-----------------------------------------------------------------------------
//	Weapon Config for GiveWeapon() and RegisterCustomWeapon()
//-----------------------------------------------------------------------------
// These are properties that are used by GTFW.
// You can preset the defaults for every weapon spawned by GiveWeapon(), or on a per-weapon basis.
// For per-weapon, use parameter 2 in GiveWeapon() and add the bits you want, or simply make a custom weapon with a different preset.

// `Defaults` preset for all weapons is below this list.

// Here are all the properties you can use:

::DeleteAndReplace <-	(1 << 0)	// Deletes the weapon that matches the slot of the new weapon, then adds the new weapon. Not compatible with KeepIDX bit. NOTE: Cannot switch to another weapon in the same slot, unless using "hud_fastswitch 0".
::KeepIDX <-			(1 << 1)	// Only updates the Item Definition Index of the given weapon. Not compatible with DeleteAndReplace bit. Added for MvM to allow for custom weapons to be upgradeable.
::AutoSwitch <-			(1 << 2)	// Forcefully switches to the weapon if obtained.
::WipeAttributes <-		(1 << 3)	// Clears original attributes present on the weapon.
::ForceCustom <-		(1 << 4)	// Forces the weapon to be "custom". "custom" in GTFW terms means different things, but here it means it sets netprop "ItemIDHigh" bit 6, for coding convenience. (The other "custom" means unique ItemDefinitionIndex. Don't worry about it right now)
::ForceNotCustom <-		(1 << 5)	//  Makes sure to unset "ItemIDHigh" bit 6.
::AnnounceToChat <- 	(1 << 6)	// Announces the weapon in chat for all to see what you got!
::Save <- 				(1 << 7)	// Saves the weapon, allowing players to retrieve it as long as function "handle.LoadLoadout()" is used.
::AutoRegister <- 		(1 << 8)	// This automatically registers this as a custom weapon, if it wasn't already registered before. It might suck up all the unique ItemDefinitionIndexes, so use with caution, or don't use this setting at all.
::FixClassAnims <- 		(1 << 9)	// Player model switches to class animations of weapon's intended player class. No disgression--If it the weapon is unintended for that class, it will switch.
::FixClassAnimsRef <-	(1 << 10)	//  Same as FixClassAnims, but only for when player goes into reference pose.
::FixClassAnimsITEM <-	(1 << 11)	//  Same as FixClassAnims, but only for unique ITEM animations (ITEM1, ITEM2, ITEM3, ITEM4).

//-----------------------------------------------------------------------------
// This is the Defaults preset for all weapons. Adjust it how you like.
//-----------------------------------------------------------------------------
//Defaults: DeleteAndReplace|AutoSwitch|Save|FixClassAnimsRef|FixClassAnimsITEM
//To remove all, write: 0

::Defaults <- DeleteAndReplace|AutoSwitch|Save|FixClassAnimsRef|FixClassAnimsITEM


//-----------------------------------------------------------------------------
//	VScript CVars
//-----------------------------------------------------------------------------
Convars.SetValue("tf_dropped_weapon_lifetime", 0)	//disables dropped weapons because they're buggy with this script
::CVAR_GTFW_DEBUG_MODE <- false		// Sends error messages to everyone. False by default.

::CVAR_USE_VIEWMODEL_FIX <- true				// Automatically fixes any and all viewmodel arms to match the class you're playing as. True by default.
::CVAR_DELETEWEAPON_AUTO_SWITCH <- true			// Automatically switches weapon to another if deleting a weapon. True by default.
::CVAR_DISABLEWEAPON_AUTO_SWITCH <- true		// Automatically switches weapon to another if disabling a weapon. True by default.
::CVAR_ENABLEWEAPON_AUTO_SWITCH <- false		// Automatically switches weapon to another if re-enabling a weapon. False by default.

const GLOBAL_WEAPON_COUNT = 7	//How many loops the script makes to check for unused slots

//-----------------------------------------------------------------------------
//	Included Scripts
//-----------------------------------------------------------------------------
// Only runs the main code files once to improve server performance.

//If TF_CUSTOM_WEAPONS_REGISTRY is already defined, stop running the script. Otherwise, continue to execute the main code files.
if ( "TF_CUSTOM_WEAPONS_REGISTRY" in getroottable() ) return;
::GTFW <- {};

::TF_CUSTOM_WEAPONS_REGISTRY <- {}; // Weapon's registry only allows for registering same weapon type 63 times.

//IncludeScript("give_tf_weapon/extra/text_listener.nut")		//Optional chat command "!give"
IncludeScript("give_tf_weapon/libs/netpropperf.nut")	//according to ficool2, reduces NetProps runtime by some-20%!
IncludeScript("give_tf_weapon/code/__exec.nut")			// Executes all functions that this script uses!

//-----------------------------
// RANDOMIZER STUFF STARTS HERE
//-----------------------------
// Flags
local class_restrict_weapons = false // Restricts random weapons to being only from ones own class
local randomize_class = false // Randomizes class on spawn

// Weapon arrays https://wiki.alliedmods.net/Team_fortress_2_item_definition_indexes
// Scout
local scout_primary = [13, 45, 220, 448, 772, 1103, 1103]
local scout_secondary = [23, 46, 163, 222, 449, 773, 812]
local scout_melee = [0, 44, "Holy Mackerel", 317, 325, 349, 355, 450, 452, 648, 30667]
local scout_weapons = [scout_primary, scout_secondary, scout_melee]
// Soldier
local solly_primary = [18, 127, "Black Box", 237, 414, 441, 513, 730, 1104]
local solly_secondary = [10, 129, 133, 226, 354, 415, 442, 444, 1101, 1153]
local solly_melee = [6, 128, 154, 357, 416, 447, 775]
local solly_weapons = [solly_primary, solly_secondary, solly_melee]
// Pyro
local pyro_primary = [21, 40, 215, 594, 659, 741, 1178]
local pyro_secondary = [12, 39, 351, 415, 595, 740, 1153, 1179, 1180]
local pyro_melee = [2, 38, 153, 214, 326, 348, 595, 813, 1181]
local pyro_weapons = [pyro_primary, pyro_secondary, pyro_melee]
// Demo
local demo_primary = [19, 308, 405, 996, 1151] // Excluded base jumper
local demo_secondary = [20, 130, 131, 406, 1099, 1150]
local demo_melee = [1, 132, 154, 172, 266, 307, 327, 357, 404, 609]
local demo_weapons = [demo_primary, demo_secondary, demo_melee]
// Heavy
local heavy_primary = [15, 41, 312, 424, 811, 298]
local heavy_secondary = [11, 42, 159, 311, 425, 433, 1153, 1190]
local heavy_melee = [5, 43, 239, 310, 331, 426, 587]
local heavy_weapons = [heavy_primary, heavy_secondary, heavy_melee]
// Engi
local engi_primary = [9, 141, 527, 588, 997, 1153]
local engi_secondary = [22, 140, 528, 294]
local engi_melee = [7, 142, 155, 169, 329, 589]
local engi_weapons = [engi_primary, engi_secondary, engi_melee]
// Med
local med_primary = [17, 36, 305, 412]
local med_secondary = [29, 35, 411, 998]
local med_melee = [8, 37, 173, 264, 304, 413]
local med_weapons = [med_primary, med_secondary, med_melee]
// Sniper
local sniper_primary = [14, 56, 230, 402, 526, 752, 851, 1092, 1098]
local sniper_secondary = [16, 57, 58, 231, 642]
local sniper_melee = [3, 171, 232, 401, 423, 1013, 1071]
local sniper_weapons = [sniper_primary, sniper_secondary, sniper_melee]
// Spy
local spy_primary = [24, 61, 161, 224, 460, 525]
local spy_secondary = [753, 810]
local spy_melee = [4, 225, 356, 461, 649, 727]
local spy_weapons = [spy_primary, spy_secondary, spy_melee]

// int class - 0 gives all weapons, 1 - Scout, 2 - Soldier etc.
function GiveRandomWeapon(hPlayer, slot = 0, merc = 0)
{
    switch(merc){
        case 0: // Recursively provide a random class
            GiveRandomWeapon(hPlayer, slot, RandomInt(1, 9));
            break;
        case 1: // Scout
            hPlayer.GiveWeapon(scout_weapons[slot][RandomInt(0, scout_weapons[slot].len())]);
            break;
        case 2: // Solly
            hPlayer.GiveWeapon(solly_weapons[slot][RandomInt(0, solly_weapons[slot].len())]);
            break;
        case 3: // Pyro
            hPlayer.GiveWeapon(pyro_weapons[slot][RandomInt(0, pyro_weapons[slot].len())]);
            break;
        case 4: // Demo
            hPlayer.GiveWeapon(demo_weapons[slot][RandomInt(0, demo_weapons[slot].len())]);
            break;
        case 5: // Heavy
            hPlayer.GiveWeapon(heavy_weapons[slot][RandomInt(0, heavy_weapons[slot].len())]);
            break;
        case 6: // Engi
            hPlayer.GiveWeapon(engi_weapons[slot][RandomInt(0, engi_weapons[slot].len())]);
            break;
        case 7: // Med
            hPlayer.GiveWeapon(med_weapons[slot][RandomInt(0, med_weapons[slot].len())]);
            break;
        case 8: // Sniper
            hPlayer.GiveWeapon(sniper_weapons[slot][RandomInt(0, sniper_weapons[slot].len())]);
            break;
        case 9: // Snpy
            hPlayer.GiveWeapon(spy_weapons[slot][RandomInt(0, spy_weapons[slot].len())]);
            break;
    }
}

function OnGameEvent_player_death(params) //Player death
{
    if (!("userid" in params)) return;

    //Defines player handle as hPlayer
	    local hPlayer = GetPlayerFromUserID(params.userid);
    // Updates ragdoll to the player's actual class.
	    hPlayer.SetCustomModelWithClassAnimations(GTFW_MODEL_TFCLASSES[hPlayer.GetPlayerClass()]);

    
}

function OnGameEvent_player_spawn(params){
    if (!("userid" in params)) return;

    //Defines player handle as hPlayer
	    local hPlayer = GetPlayerFromUserID(params.userid);

    if(!class_restrict_weapons){
        GiveRandomWeapon(hPlayer, 0, 0);
        GiveRandomWeapon(hPlayer, 1, 0);
        GiveRandomWeapon(hPlayer, 2, 0);
        return;
    }

    switch(hPlayer.GetPlayerClass()){
        case Constants.ETFClass.TF_CLASS_SCOUT: // Scout
            GiveRandomWeapon(hPlayer, 0, 1);
            GiveRandomWeapon(hPlayer, 1, 1);
            GiveRandomWeapon(hPlayer, 2, 1);
            break;
        case Constants.ETFClass.TF_CLASS_SOLDIER: // Solly
            GiveRandomWeapon(hPlayer, 0, 2);
            GiveRandomWeapon(hPlayer, 1, 2);
            GiveRandomWeapon(hPlayer, 2, 2);
            break;
        case Constants.ETFClass.TF_CLASS_PYRO: // Pyro
            GiveRandomWeapon(hPlayer, 0, 3);
            GiveRandomWeapon(hPlayer, 1, 3);
            GiveRandomWeapon(hPlayer, 2, 3);
            break;
        case Constants.ETFClass.TF_CLASS_DEMOMAN: // Demo
            GiveRandomWeapon(hPlayer, 0, 4);
            GiveRandomWeapon(hPlayer, 1, 4);
            GiveRandomWeapon(hPlayer, 2, 4);
            break;
        case Constants.ETFClass.TF_CLASS_HEAVYWEAPONS: // Heavy
            GiveRandomWeapon(hPlayer, 0, 5);
            GiveRandomWeapon(hPlayer, 1, 5);
            GiveRandomWeapon(hPlayer, 2, 5);
            break;
        case Constants.ETFClass.TF_CLASS_ENGINEER: // Engi
            GiveRandomWeapon(hPlayer, 0, 6);
            GiveRandomWeapon(hPlayer, 1, 6);
            GiveRandomWeapon(hPlayer, 2, 6);
            break;
        case Constants.ETFClass.TF_CLASS_MEDIC: // Med
            GiveRandomWeapon(hPlayer, 0, 7);
            GiveRandomWeapon(hPlayer, 1, 7);
            GiveRandomWeapon(hPlayer, 2, 7);
            break;
        case Constants.ETFClass.TF_CLASS_SNIPER: // Sniper
            GiveRandomWeapon(hPlayer, 0, 8);
            GiveRandomWeapon(hPlayer, 1, 8);
            GiveRandomWeapon(hPlayer, 2, 8);
            break;
        case Constants.ETFClass.TF_CLASS_SPY: // Snpy
            GiveRandomWeapon(hPlayer, 0, 9);
            GiveRandomWeapon(hPlayer, 1, 9);
            GiveRandomWeapon(hPlayer, 2, 9);
            break;
    }
}


__CollectGameEventCallbacks(this)