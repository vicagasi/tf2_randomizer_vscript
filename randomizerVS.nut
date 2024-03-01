//FY VScript by Vicky G (Rivi the Warlock)
//Based on Team Deathmatch VScript by John Worden (MilkMaster72)
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

// Weapon arrays https://wiki.alliedmods.net/Team_fortress_2_item_definition_indexes
// Scout
local scout_primary = [13, 45, 220, 448, 772, 1103, 1103]
local scout_secondary = [23, 46, 163, 222, 449, 773, 812]
local scout_melee = [0, 44, 221, 317, 325, 349, 355, 450, 452, 648, 30667]
local scout_weapons = [scout_primary, scout_secondary, scout_melee]
// Soldier
local solly_primary = [18, 127, 228, 237, 414, 441, 513, 730, 1104]
local solly_secondary = [10, 129, 133, 226, 354, 415, 442, 444, 1101, 1153]
local solly_melee = [6, 128, 154, 357, 416, 447, 775]
local solly_weapons = [solly_primary, solly_secondary, solly_melee]

// int class - 0 gives all weapons, 1 - Scout, 2 - Soldier etc.
function GiveRandomWeapon(hPlayer, slot = 0, merc = 0)
{
    switch(merc){
        case 0: // Recursively provide a random class
            GiveRandomWeapon(hPlayer, slot, RandomInt(1, 2));
            break;
        case 1: // Scout
            hPlayer.GiveWeapon(scout_weapons[slot][RandomInt(0, scout_weapons[slot].len())]);
            break;
        case 2: // Solly
            hPlayer.GiveWeapon(solly_weapons[slot][RandomInt(0, solly_weapons[slot].len())]);
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

    //hPlayer.GiveWeapon(scout_weapons[0][RandomInt(0, scout_weapons[0].len())])
    GiveRandomWeapon(hPlayer, 0, 0);
}


__CollectGameEventCallbacks(this)