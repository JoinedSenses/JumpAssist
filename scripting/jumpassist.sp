/*																	TODO
	**********************************************************************************************************************************
	* Done:
	* 0.6.1b - Minor performance improvement. (Constantly checking if the map had regen on every player profile loaded. Changed to check once per map.)
	* 
	* 0.6.2b - JumpAssist NOW REQUIRES SDKHOOKS to be installed.
	* 0.6.2b - Fixed !superman not displaying the correct text/action after a team/class change.
	* 0.6.2b - Re-did the ammo resupply. Correctly supports both jumper weapons now, and other unlocks (Not all weapons added yet).
	* 0.6.2b - Fixed a typo in CreatePlayerProfile where it defaulted the FOV to 90 instead of 70.
	* 0.6.2b - Fixed a couple bugs in LoadPlayerProfile. Everything should load correctly now.
	* 0.6.2b - Fixed a few missing pieces of text in the jumpassist translations file.
	* 0.6.2b - Removed "battle protection" (server admins should make use of !mapset team <red|blu>)
	*
	* 0.6.3b - Re-worked the cap message stuff. Should be 99% better.
	* 0.6.3b - Removed some unreleased stuff I was working on in JA.
	*
	* 0.6.4b - Players using the jumper weapons can no longer use !hardcore.
	* 0.6.4b - Added more to the translations file.
	*
	* 0.6.5b - Added SteamTools
	* 0.6.5b - Added ja_url make your own custom help file.
	*
	* 0.6.6b - Random bug fix
	*
	* 0.6.7b - Better error checking
	*
	* 0.6.8 - Added auto updating to jumpassist. Which makes SteamTools a solid requirement.
	*
	* 0.6.9 - Changed the code around to be more easily maintained.
	*
	* 0.7.0 - Added both options for sqlite and mysql data storage.
	*
	*
	* UNOFFICIAL UPDATES BY TALKINGMELON
	* 0.7.1 - Regen is working better and skeys has less delay. Control points should work properly.
	*		- JA can now be used without a database configured.
	*		- Restart works properly. 
	*		- The system for saving locations for admins is now working properly
	*		- Also general bugfixes
	* 
	* 0.7.2 - Moved skeys and added m1/m2 support
	*		- Changed how commands are recognized to the way that is normally supported
	*		- General bugfixes
	*
	* 0.7.3 - Added support for updater plugin
	*
	* 0.7.4 - Added race functionality
	*
	* 0.7.5 - Fixed a number of racing bugs
	*
	* 0.7.6 - Racing now displays time in HH:MM:SS:MS or just MM:SS:MS if the time is short enough
	*		- Reorganized code to make it more readable and understandable
	*		- Spectators now get race alerts if they are spectating someone in a race
	*		- r_inv now works with argument targeting - ex !r_inv talkingmelon works now
	*		- restart no longer displays twice
	*		- When a player loads into a map, their previous caps will no longer be remembered - should fix the notification issue
	*		- Sounds should play properly 
	*		- r_info added
	*		- r_spec added
	* 		- r_set added
	*
	* 0.7.7 - Can invite multiple people at once with the r_inv command
	*		- Fixed server_race bug
	*		- Tried to fix sounds (pls)
	*		- r_list command added
	*
	* 0.7.8 - Ammo regen after plugin reload working
	*		- skeys_loc now allows you to set the location of skeys on the screen
	*
	* TODO:
	* SPEC SUPPORT FOR r_info
	* TEST RACE SPEC AND ADD FUNCTIONALITY FOR ONLY SHOWING PEOPLE IN A RACE WHEN ATTACK1 AND 2 ARE USED	
	* SOUND ON CP - I think this is fixed but it's very odd
	* Better help menu	
	* rematch typa thing
	* save pos before start of race then restore after
	* Polish for release.
	* Support for jtele with one argument
	*
	*
	* BUGS:
	* I'm sure there are plenty
	*	eventPlayerChangeTeam throws error on dc
	*	Dropped <name> from server (Disconnect by user.)
	*	L 12/02/2014 - 23:07:57: [SM] Native "ChangeClientTeam" reported: Client 2 is not in game
	*	L 12/02/2014 - 23:07:57: [SM] Displaying call stack trace for plugin "jumpassist.smx":
	*	L 12/02/2014 - 23:07:57: [SM]   [0]  Line 1590, scripting\jumpassist.sp::timerTeam()
	* Change to spec during race
	*
	* TESTERS
	* - Zigzati
	* - Elie
	* - Fossiil
	* - Melon
	* - AI
	* - Jondy
	* - Fractal
	* - Torch
	* - Velks
	* - Froyo
	* - Jondy
	* - Pizza Butt 8)
	* - 0beezy
	**********************************************************************************************************************************
	
	
																	NOTES	
	**********************************************************************************************************************************
	*
	* You must have a mysql or sqlite database named jumpassist and configure configured in /addons/sourcemod/configs/databases.cfg
	*
	* Once the database is set up, an example configuration would look like:
	*
	* "jumpassist"
    *     {
    *             "driver"                        "default"
    *             "host"                          "127.0.0.1"
    *             "database"                      "jumpassist"
    *             "user"                          "tf2server"
    *             "pass"                          "tf2serverpassword"
    *             //"timeout"                     "0"
    *             //"port"                        "0"
    *     }
	*
	*
	**********************************************************************************************************************************
	
	
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <steamtools>

#define UPDATE_URL    "http://71.224.176.158:8080/files/jumpassist/updatefile.txt"
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN


#define PLUGIN_VERSION "0.7.8"
#define PLUGIN_NAME "[TF2] Jump Assist"
#define PLUGIN_AUTHOR "rush - Updated by talkingmelon"

#define cDefault    0x01
#define cLightGreen 0x03

/*
	Core Includes
*/
#include "jumpassist/skeys.sp"
#include "jumpassist/skillsrank.sp"
#include "jumpassist/database.sp"
#include "jumpassist/sound.sp"

new Handle:g_hWelcomeMsg;
new Handle:g_hCriticals; 
new Handle:g_hSuperman;
new Handle:g_hSentryLevel;
new Handle:g_hCheapObjects;
new Handle:g_hAmmoCheat;
new Handle:g_hFastBuild;

new g_bRace[MAXPLAYERS+1];
new g_bRaceStatus[MAXPLAYERS+1];
	//1 - inviting players
	//2 - 3 2 1 countdown
	//3 - racing
	//4 - waiting for players to finish
	//  - Only updated for the lobby host
new Float:g_bRaceStartTime[MAXPLAYERS+1];
new Float:g_bRaceTime[MAXPLAYERS+1];
new Float:g_bRaceTimes[MAXPLAYERS+1][MAXPLAYERS];
new g_bRaceFinishedPlayers[MAXPLAYERS+1][MAXPLAYERS];
new Float:g_bRaceFirstTime[MAXPLAYERS+1];
new g_bRaceEndPoint[MAXPLAYERS+1];
new g_bRaceInvitedTo[MAXPLAYERS+1];
new bool:g_bRaceLocked[MAXPLAYERS+1];
new bool:g_bRaceAmmoRegen[MAXPLAYERS+1];
new bool:g_bRaceHealthRegen[MAXPLAYERS+1];
new bool:g_bRaceClassForce[MAXPLAYERS+1];
new g_bRaceSpec[MAXPLAYERS+1];

new Handle:waitingForPlayers;

new String:szWebsite[128] = "http://www.jump.tf/";
new String:szForum[128] = "http://tf2rj.com/forum/";
new String:szJumpAssist[128] = "http://tf2rj.com/forum/index.php?topic=854.0";

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "Tools to run a jump server with ease.",
	version = PLUGIN_VERSION,
	url = "http://www.pure-gamers.com"
}
public OnPluginStart()
{
	JA_CreateForward();

	// Skillsrank uses me!
	RegPluginLibrary("jumpassist");

	// ConVars
	CreateConVar("jumpassist_version", PLUGIN_VERSION, "Jump assist version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hPluginEnabled = CreateConVar("ja_enable", "1", "Turns JumpAssist on/off.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hWelcomeMsg = CreateConVar("ja_welcomemsg", "1", "Show clients the welcome message when they join?", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hFastBuild = CreateConVar("ja_fastbuild", "1", "Allows engineers near instant buildings.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hAmmoCheat = CreateConVar("ja_ammocheat", "1", "Allows engineers infinite sentrygun ammo.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hCheapObjects = CreateConVar("ja_cheapobjects", "0", "No metal cost on buildings.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hCriticals = CreateConVar("ja_crits", "0", "Allow critical hits.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hSuperman = CreateConVar("ja_superman", "0", "Allows everyone to be invincible.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hSoundBlock = CreateConVar("ja_sounds", "0", "Block pain, regenerate, and ammo pickup sounds?", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hSentryLevel = CreateConVar("ja_sglevel", "3", "Sets the default sentry level (1-3)", FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	// Jump Assist console commands
	RegConsoleCmd("ja_help", cmdJAHelp, "Shows JA's commands.");
	RegConsoleCmd("sm_hardcore", cmdToggleHardcore, "Sends you back to the beginning without deleting your save..");
	RegConsoleCmd("sm_r", cmdReset, "Sends you back to the beginning without deleting your save..");
	RegConsoleCmd("sm_reset", cmdReset, "Sends you back to the beginning without deleting your save..");
	RegConsoleCmd("sm_restart", cmdRestart, "Deletes your save, and sends you back to the beginning.");
	RegConsoleCmd("sm_setmy", cmdSetMy, "Saves player settings.");
	RegConsoleCmd("sm_goto", cmdGotoClient, "Goto <target>");
	RegConsoleCmd("sm_s", cmdSave, "Saves your current position.");
	RegConsoleCmd("sm_save", cmdSave, "Saves your current position.");
	RegConsoleCmd("sm_regen", cmdDoRegen, "Changes regeneration settings.");
	RegConsoleCmd("sm_undo", cmdUndo, "Restores your last saved position.");
	RegConsoleCmd("sm_t", cmdTele, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_ammo", cmdToggleAmmo, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_health", cmdToggleHealth, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_tele", cmdTele, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_skeys", cmdGetClientKeys, "Toggle showing a clients key's.");
	RegConsoleCmd("sm_skeys_color", cmdChangeSkeysColor, "Changes the color of the text for skeys."); //cannot whether the database is configured or not
	RegConsoleCmd("sm_skeys_loc", cmdChangeSkeysLoc, "Changes the color of the text for skeys.");
	RegConsoleCmd("sm_superman", cmdUnkillable, "Makes you strong like superman.");
	RegConsoleCmd("sm_jumptf", cmdJumpTF, "Shows the jump.tf website.");
	RegConsoleCmd("sm_forums", cmdJumpForums, "Shows the jump.tf forums.");
	RegConsoleCmd("sm_jumpassist", cmdJumpAssist, "Shows the forum page for JumpAssist.");
	
	RegConsoleCmd("sm_race_help", cmdRaceHelp, "Shows race commands.");
	RegConsoleCmd("sm_r_help", cmdRaceHelp, "Shows race commands.");
	RegConsoleCmd("sm_race_list", cmdRaceList, "Lists players and their times in a race.");
	RegConsoleCmd("sm_r_list", cmdRaceList, "Lists players and their times in a race.");
	RegConsoleCmd("sm_race", cmdRaceInitialize, "Initializes a new race.");
	RegConsoleCmd("sm_r_inv", cmdRaceInvite, "Invites players to a new race.");
	RegConsoleCmd("sm_race_invite", cmdRaceInvite, "Invites players to a new race.");
	RegConsoleCmd("sm_r_start", cmdRaceStart, "Starts a race if you have invited people");
	RegConsoleCmd("sm_race_start", cmdRaceStart, "Starts a race if you have invited people");
	RegConsoleCmd("sm_r_leave", cmdRaceLeave, "Leave the current race.");
	RegConsoleCmd("sm_race_leave", cmdRaceLeave, "Leave the current race.");
	RegConsoleCmd("sm_r_spec", cmdRaceSpec, "Spectate a race.");
	RegConsoleCmd("sm_race_spec", cmdRaceSpec, "Spectate a race.");
	RegConsoleCmd("sm_r_set", cmdRaceSet, "Change a race's settings.");
	RegConsoleCmd("sm_race_set", cmdRaceSet, "Change a race's settings.");
	RegConsoleCmd("sm_r_info", cmdRaceInfo, "Display information about the race you are in.");
	RegConsoleCmd("sm_race_info", cmdRaceInfo, "Display information about the race you are in.");
	RegAdminCmd("sm_server_race", cmdServerRace, ADMFLAG_GENERIC, "Invite everyone to a server wide race");
	RegAdminCmd("sm_s_race", cmdServerRace, ADMFLAG_GENERIC, "Invite everyone to a server wide race");

	// Admin Commands
	RegAdminCmd("sm_mapset", cmdMapSet, ADMFLAG_GENERIC, "Change map settings");
	RegAdminCmd("sm_send", cmdSendPlayer, ADMFLAG_GENERIC, "Send target to another target.");
	RegAdminCmd("sm_jatele", SendToLocation, ADMFLAG_GENERIC, "Sends a player to the spcified jump.");
	RegAdminCmd("sm_addtele", cmdAddTele, ADMFLAG_GENERIC, "Adds a teleport location for the current map");

	// ROOT COMMANDS, they're set to root users for a reason.
	RegAdminCmd("ja_query", RunQuery, ADMFLAG_ROOT, "Runs a SQL query on the JA database. (FOR TESTING)");

	
	// Hooks
	HookEvent("player_team", eventPlayerChangeTeam);
	HookEvent("player_changeclass", eventPlayerChangeClass);
	HookEvent("player_spawn", eventPlayerSpawn);
	HookEvent("player_death", eventPlayerDeath);
	HookEvent("player_hurt", eventPlayerHurt);
	HookEvent("controlpoint_starttouch", eventTouchCP);
	HookEvent("player_builtobject", eventPlayerBuiltObj);
	HookEvent("player_upgradedobject", eventPlayerUpgradedObj);
	HookEvent("teamplay_round_start", eventRoundStart);


	// ConVar Hooks
	HookConVarChange(g_hFastBuild, cvarFastBuildChanged);
	HookConVarChange(g_hCheapObjects, cvarCheapObjectsChanged);
	HookConVarChange(g_hAmmoCheat, cvarAmmoCheatChanged);
	HookConVarChange(g_hWelcomeMsg, cvarWelcomeMsgChanged);
	HookConVarChange(g_hSuperman, cvarSupermanChanged);
	HookConVarChange(g_hSoundBlock, cvarSoundsChanged);
	HookConVarChange(g_hSentryLevel, cvarSentryLevelChanged);

	HookUserMessage(GetUserMessageId("VoiceSubtitle"), HookVoice, true);
	AddNormalSoundHook(NormalSHook:sound_hook);

	LoadTranslations("jumpassist.phrases");
	LoadTranslations("common.phrases");

	g_hHostname = FindConVar("hostname");
	HudDisplayForward = CreateHudSynchronizer();
	HudDisplayASD = CreateHudSynchronizer();
	HudDisplayDuck = CreateHudSynchronizer();
	HudDisplayJump = CreateHudSynchronizer();

	waitingForPlayers = FindConVar("mp_waitingforplayers_time");
	
	for(new i = 0; i < MAXPLAYERS+1; i++){
		if (IsValidClient(i))
		{
			g_iClientWeapons[i][0] = GetPlayerWeaponSlot(i, TFWeaponSlot_Primary);
			g_iClientWeapons[i][1] = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
			g_iClientWeapons[i][2] = GetPlayerWeaponSlot(i, TFWeaponSlot_Melee);
		}
	}


	SetAllSkeysDefaults();

	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	
	ConnectToDatabase();
	SetDesc();
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("JA_ClearSave", Native_JA_ClearSave);
	CreateNative("JA_GetSettings", Native_JA_GetSettings);
	CreateNative("JA_PrepSpeedRun", Native_JA_PrepSpeedRun);
	CreateNative("JA_ReloadPlayerSettings", Native_JA_ReloadPlayerSettings);

	g_bLateLoad = late;

	return APLRes_Success;
}
public OnAllPluginsLoaded()
{
	skillsrank = LibraryExists("skillsrank");
}
enum TFGameType {
	TFGame_Unknown,
	TFGame_CaptureTheFlag,
	TFGame_CapturePoint,
	TFGame_Payload,
	TFGame_Arena,
};
TF2_SetGameType()
{
	GameRules_SetProp("m_nGameType", 2);
}
public Updater_OnPluginUpdated()
{
	ReloadPlugin();
}

public OnMapStart()
{
	if (GetConVarBool(g_hPluginEnabled))
	{
		for(new i = 0; i < MAXPLAYERS+1 ; i++){
			ResetRace(i); 
		}
	
		
		SetDesc();
		if (g_hDatabase != INVALID_HANDLE)
		{
			LoadMapCFG();
		}
		SetConVarInt(waitingForPlayers, 0);

		// Precache cap sounds
		PrecacheSound("misc/tf_nemesis.wav");
		PrecacheSound("misc/freeze_cam.wav");
		PrecacheSound("misc/killstreak.wav");
		
		// Change game rules to CP.
		TF2_SetGameType();
	
		// Find caps, and store the number of them in g_iCPs.
		new iCP = -1; g_iCPs = 0;
		while ((iCP = FindEntityByClassname(iCP, "trigger_capture_area")) != -1)
		{
			g_iCPs++;
		}
		
		// Support for concmap*, and quad* maps that are imported from TFC.
		new entity;
		while ((entity = FindEntityByClassname(entity, "func_regenerate")) != -1)
		{
			g_bRegen = true;
		}
	}
}
public OnClientDisconnect(client)
{
	if (GetConVarBool(g_hPluginEnabled))
	{
		g_bHardcore[client] = false, g_bHPRegen[client] = false, g_bLoadedPlayerSettings[client] = false, g_bBeatTheMap[client] = false;
		g_bGetClientKeys[client] = false, g_bSpeedRun[client] = false, g_bUnkillable[client] = false, Format(g_sCaps[client], sizeof(g_sCaps), "\0");
		
		EraseLocs(client);
	}
	
	if(g_bRace[client] !=0)
	{
		LeaveRace(client);
	}
	SetSkeysDefaults(client);
	
}
public OnClientPutInServer(client)
{
	if (GetConVarBool(g_hPluginEnabled))
	{
		// Hook the client
		if(IsValidClient(client)) 
		{
			SDKHook(client, SDKHook_WeaponEquipPost, SDKHook_OnWeaponEquipPost);
		}
		// Load the player profile.
		decl String:sSteamID[64]; GetClientAuthString(client, sSteamID, sizeof(sSteamID));

		LoadPlayerProfile(client, sSteamID);

		// Welcome message. 15 seconds seems to be a good number.
		if (GetConVarBool(g_hWelcomeMsg))
		{
			CreateTimer(15.0, WelcomePlayer, client);
		}
		g_bHardcore[client] = false, g_bHPRegen[client] = false, g_bLoadedPlayerSettings[client] = false, g_bBeatTheMap[client] = false;
		g_bGetClientKeys[client] = false, g_bSpeedRun[client] = false, g_bUnkillable[client] = false, Format(g_sCaps[client], sizeof(g_sCaps), "\0");
	}
}
/*****************************************************************************************************************
												Functions
*****************************************************************************************************************/

//I SHOULD MAKE THIS DO A PAGED MENU IF IT DOESNT ALREADY IDK ANY MAPS WITH THAT MANY CPS ANYWAY
public Action:cmdRaceInitialize(client, args)
{
	if (!IsValidClient(client)) { return; }
	if (g_bSpeedRun[client]) 
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Speedrun_Active");
		return;
	}
	
	if (g_iCPs == 0){
		PrintToChat(client, "\x01[\x03JA\x01] You may only race on maps with control points.");
		return;
	}
	
	if(IsPlayerFinishedRacing(client))
	{
		LeaveRace(client);
	}
	
	
	if (IsClientRacing(client)){
		PrintToChat(client, "\x01[\x03JA\x01] You are already in a race.");
		return;
	}
	
	
	g_bRace[client] = client;
	g_bRaceStatus[client] = 1;
	g_bRaceClassForce[client] = true;

	new String:cpName[32];
	new Handle:menu = CreateMenu(ControlPointSelector);
	SetMenuTitle(menu, "Select End Control Point");
	
	new entity;
	new String:buffer[32];
	while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1)
	{
		
		new pIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");
		GetEntPropString(entity, Prop_Data, "m_iszPrintName", cpName, sizeof(cpName));
		IntToString(pIndex, buffer, sizeof(buffer));
		AddMenuItem(menu, buffer, cpName);
		
	}
	DisplayMenu(menu, client, 300);
	return;
}


public ControlPointSelector(Handle:menu, MenuAction:action, param1, param2)
{

	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_bRaceEndPoint[param1] = StringToInt(info);
	}
	else if (action == MenuAction_Cancel)
	{
		g_bRace[param1] = 0;
		PrintToChat(param1, "\x01[\x03JA\x01] The race has been cancelled.");
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

}



public Action:cmdRaceInvite(client, args)
{
	if (!IsValidClient(client)) { return Plugin_Handled; }

	if (!IsClientRacing(client)){
		PrintToChat(client, "\x01[\x03JA\x01] You have not started a race.");
		return Plugin_Handled;
	}
	if (!IsRaceLeader(client, g_bRace[client])){
		PrintToChat(client, "\x01[\x03JA\x01] You are not the race lobby leader.");
		return Plugin_Handled;
	}
	if (HasRaceStarted(client)){
		PrintToChat(client, "\x01[\x03JA\x01] The race has already started.");
		return Plugin_Handled;
	}
	if(args == 0){
		new Handle:g_PlayerMenu = INVALID_HANDLE;
		g_PlayerMenu = PlayerMenu();
		
		DisplayMenu(g_PlayerMenu, client, MENU_TIME_FOREVER);
	}else{
			
		new String:arg1[32];
		new String:clientName[128];
		new String:client2Name[128];
		new String:buffer[128];
		new Handle:panel;
		GetClientName(client, clientName, sizeof(clientName));

		new target;
		for(new i = 1; i < args+1; i++){
			GetCmdArg(i, arg1, sizeof(arg1));
			target = FindTarget(client, arg1, true, false);
			if(target != -1){

				
				
				GetClientName(target, client2Name, sizeof(client2Name));
			
				PrintToChat(client, "\x01[\x03JA\x01] You have invited %s to race.", client2Name);
				
				Format(buffer, sizeof(buffer), "You have been invited to race to %s by %s", GetCPNameByIndex(g_bRaceEndPoint[client]), clientName);
				

				panel = CreatePanel();
				SetPanelTitle(panel, buffer);
				DrawPanelItem(panel, "Accept");
				DrawPanelItem(panel, "Decline");
				
				g_bRaceInvitedTo[target] = client;
				SendPanelToClient(panel, target, InviteHandler, 15);
				
				CloseHandle(panel);
			}
		}
	}
	return Plugin_Continue;
	
}

stock String:GetCPNameByIndex(index)
{

	new entity;
	new String:cpName[32];
	while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1)
	{
		if(GetEntProp(entity, Prop_Data, "m_iPointIndex") == index)
		{
			GetEntPropString(entity, Prop_Data, "m_iszPrintName", cpName, sizeof(cpName));
		}
	}
	
	return cpName;

}

Handle:PlayerMenu()
{
	
	new Handle:menu = CreateMenu(Menu_InvitePlayers);
	new String:buffer[128];
	new String:clientName[128];
	
	
	//SHOULDNT SHOW CURRENT PLAYER AND ALSO PLAYERS ALREADY IN A RACE BUT I NEED THAT FOR TESTING FOR NOW
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if(IsValidClient(i))
		{
			IntToString(i, buffer, sizeof(buffer));
			GetClientName(i, clientName, sizeof(clientName));
			AddMenuItem(menu, buffer, clientName);
		}
		
		SetMenuTitle(menu, "Select Players to Invite:");
    
	}
	
	return menu;

}

public Menu_InvitePlayers(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:clientName[128];
		new String:client2Name[128];
		new String:buffer[128];
		new String:info[32];
		
		GetClientName(param1, clientName, sizeof(clientName));
		GetMenuItem(menu, param2, info, sizeof(info));
		GetClientName(StringToInt(info), client2Name, sizeof(client2Name));
	
		PrintToChat(param1, "\x01[\x03JA\x01] You have invited %s to race.", client2Name);
		
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		Format(buffer, sizeof(buffer), "You have been invited to race to %s by %s", GetCPNameByIndex(g_bRaceEndPoint[param1]), clientName);
		

		new Handle:panel = CreatePanel();
		SetPanelTitle(panel, buffer);
		DrawPanelItem(panel, "Accept");
		DrawPanelItem(panel, "Decline");
		
		g_bRaceInvitedTo[StringToInt(info)] = param1;
		SendPanelToClient(panel, StringToInt(info), InviteHandler, 15);
		
		CloseHandle(panel);
	
	}
	else if (action == MenuAction_Cancel)
	{
	
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}


public InviteHandler(Handle:menu, MenuAction:action, param1, param2)
{
	// if (action == MenuAction_Select)
	// {
		// PrintToConsole(param1, "You selected item: %d", param2);
		// g_bRaceInvitedTo[param1] = 0;
	// } else if (action == MenuAction_Cancel) {
		
		// PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
		// g_bRaceInvitedTo[param1] = 0;
	// }
	
	
	AlertInviteAcceptOrDeny(g_bRaceInvitedTo[param1], param1, param2);

}

public AlertInviteAcceptOrDeny(client, client2, choice)
{
	new String:clientName[128];
	GetClientName(client2, clientName, sizeof(clientName));
	if (choice == 1)
	{	
		if(HasRaceStarted(client)){
			PrintToChat(client, "\x01[\x03JA\x01] This race has already started.");
			return;
		}
		LeaveRace(client2);
		g_bRace[client2] = client;
		PrintToChat(client, "\x01[\x03JA\x01] %s has accepted your request to race", clientName);
	}
	else if (choice < 1)
	{
		PrintToChat(client, "\x01[\x03JA\x01] %s failed to respond to your invitation", clientName);
	}
	else
	{
		PrintToChat(client, "\x01[\x03JA\x01] %s has declined your request to race", clientName);
	}
	
	
}

//THE WORST WORKAROUND YOU'VE EVER SEEN
public Action:RaceCountdown(Handle:timer, any:raceID)
{	
	PrintToRace(raceID, "****************************");
	PrintToRace(raceID, "             Starting race in: 3");
	PrintToRace(raceID, "****************************");
	CreateTimer(1.0, RaceCountdown2, raceID);

}
public Action:RaceCountdown2(Handle:timer, any:raceID)
{	
	PrintToRace(raceID, "****************************");
	PrintToRace(raceID, "                         2");
	PrintToRace(raceID, "****************************");
	CreateTimer(1.0, RaceCountdown1, raceID);

}
public Action:RaceCountdown1(Handle:timer, any:raceID)
{	
	PrintToRace(raceID, "****************************");
	PrintToRace(raceID, "                         1");
	PrintToRace(raceID, "****************************");
	CreateTimer(1.0, RaceCountdownGo, raceID);

}
public Action:RaceCountdownGo(Handle:timer, any:raceID)
{	
	UnlockRacePlayers(raceID);
	PrintToRace(raceID, "****************************");
	PrintToRace(raceID, "                        GO!");
	PrintToRace(raceID, "****************************");
	new Float:time = GetEngineTime();
	g_bRaceStartTime[raceID] = time;
	g_bRaceStatus[raceID] = 3;

}

public Action:cmdRaceList(client, args){
	if (!IsValidClient(client)) { return; }

	//WILL NEED TO ADD && !ISCLINETOBSERVER(CLIENT) WHEN I ADD SPEC SUPPORT FOR THIS
	if (!IsClientRacing(client))
	{
		PrintToChat(client, "\x01[\x03JA\x01] You are not in a race!"); 
		return;
	}
	new race = g_bRace[client];
	new String:leader[32];
	new String:leaderFormatted[32];
	new String:racerNames[32];
	new String:racerEntryFormatted[255];
	new String:racerTimes[128];
	new String:racerDiff[128];
	new Handle:panel = CreatePanel();
	new bool:space;

	GetClientName(g_bRace[client], leader, sizeof(leader));
	Format(leaderFormatted, sizeof(leaderFormatted), "%s's Race", leader);
	DrawPanelText(panel, leaderFormatted);

	DrawPanelText(panel, " ");
	

	for(new i = 0; i < MAXPLAYERS; i++){
		if(g_bRaceFinishedPlayers[race][i] == 0){
			break;
		}
		space = true;
		GetClientName(g_bRaceFinishedPlayers[race][i], racerNames, sizeof(racerNames));
		racerTimes = TimeFormat(g_bRaceTimes[race][i] - g_bRaceStartTime[race]);
		if(g_bRaceFirstTime[race] != g_bRaceTimes[race][i]){
			racerDiff = TimeFormat(g_bRaceTimes[race][i] - g_bRaceFirstTime[race]);
		}else{
			racerDiff = "00:00:000";
		}
		Format(racerEntryFormatted, sizeof(racerEntryFormatted), "%d. %s - %s[-%s]", (i+1), racerNames, racerTimes, racerDiff);
		DrawPanelText(panel, racerEntryFormatted);

	}
	if(space){
		DrawPanelText(panel, " ");
	}
	new String:name[32];

	for(new i = 0; i < MAXPLAYERS; i++){
		if(IsClientInRace(i, race) && !IsPlayerFinishedRacing(i)){
			GetClientName(i, name, sizeof(name));
			DrawPanelText(panel, name);
		}
	}
	
	DrawPanelText(panel, " ");

	DrawPanelItem(panel, "Exit");
	SendPanelToClient(panel, client, InfoHandler, 30);

	CloseHandle(panel);
}

public ListHandler(Handle:menu, MenuAction:action, param1, param2)
{
	// if (action == MenuAction_Select)
	// {
		// PrintToConsole(param1, "You selected item: %d", param2);
		// g_bRaceInvitedTo[param1] = 0;
	// } else if (action == MenuAction_Cancel) {
		
		// PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
		// g_bRaceInvitedTo[param1] = 0;
	// }

}



public Action:cmdRaceInfo(client, args)
{
	if (!IsValidClient(client)) { return; }

	//WILL NEED TO ADD && !ISCLINETOBSERVER(CLIENT) WHEN I ADD SPEC SUPPORT FOR THIS
	if (!IsClientRacing(client))
	{
		PrintToChat(client, "\x01[\x03JA\x01] You are not in a race!"); 
		return;
	}


	//SPEC INFO FOR RACES TOO NOT WORKING YET

	// if(IsClientObserver(client)){
		
	// 	new iClientToShow, iObserverMode;
	// 	iObserverMode = GetEntPropEnt(client, Prop_Send, "m_iObserverMode");
	// 	iClientToShow = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget"); 
	// 	if(!IsClientRacing(iClientToShow)){
	// 		PrintToChat(client, "\x01[\x03JA\x01] This client is not in a race!"); 
	// 		return;
	// 	}
	// 	if (!IsValidClient(client) || !IsValidClient(iClientToShow) || iObserverMode == 6) { 
	// 		return; 
	// 	}
	// 	client = iClientToShow;
	// }


	new String:leader[32];
	new String:leaderFormatted[64];
	new String:status[64];
	new String:healthRegen[32];
	new String:ammoRegen[32];
	new String:classForce[32];

	GetClientName(g_bRace[client], leader, sizeof(leader));
	Format(leaderFormatted, sizeof(leaderFormatted), "Race Host: %s", leader);

	if(g_bRaceHealthRegen[g_bRace[client]]){
		healthRegen = "HP Regen: Enabled";
	}else{
		healthRegen = "HP Regen: Disabled";
	}
	if(g_bRaceHealthRegen[g_bRace[client]]){
		ammoRegen = "Ammo Regen: Enabled";
	}else{
		ammoRegen = "Ammo Regen: Disabled";
	}

	if(GetRaceStatus(client) == 1){
		status = "Race Status: Waiting for start";
	}else if(GetRaceStatus(client) == 2){
		status = "Race Status: Starting";
	}else if(GetRaceStatus(client) == 3){
		status = "Race Status: Racing";
	}else if(GetRaceStatus(client) == 4){
		status = "Race Status: Waiting for finshers";
	}

	if(g_bRaceClassForce[g_bRace[client]]){
		classForce = "Class Force: Enabled";
	}else{
		classForce = "Class Force: Disabled";
	}


	new Handle:panel = CreatePanel();
	DrawPanelText(panel, leaderFormatted);
	DrawPanelText(panel, status);
	DrawPanelText(panel, "---------------");
	DrawPanelText(panel, healthRegen);
	DrawPanelText(panel, ammoRegen);
	DrawPanelText(panel, "---------------");
	DrawPanelText(panel, classForce);
	DrawPanelText(panel, " ");
	DrawPanelItem(panel, "Exit");
	SendPanelToClient(panel, client, InfoHandler, 30);
	
	CloseHandle(panel);



}

public InfoHandler(Handle:menu, MenuAction:action, param1, param2)
{
	// if (action == MenuAction_Select)
	// {
		// PrintToConsole(param1, "You selected item: %d", param2);
		// g_bRaceInvitedTo[param1] = 0;
	// } else if (action == MenuAction_Cancel) {
		
		// PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
		// g_bRaceInvitedTo[param1] = 0;
	// }

}




public Action:cmdRaceStart(client, args)
{
	if (!IsValidClient(client)) { return; }
	if (g_bRace[client] == 0)
	{
		PrintToChat(client, "\x01[\x03JA\x01] You are not hosting a race!"); 
		return;
	}
	if (!IsRaceLeader(client, g_bRace[client]))
	{
		PrintToChat(client, "\x01[\x03JA\x01] You are not the race lobby leader.");
		return;
	}
	//RIGHT HERE I SHOULD CHECK TO MAKE SURE THERE ARE TWO OR MORE PEOPLE
	if (HasRaceStarted(client)){
		PrintToChat(client, "\x01[\x03JA\x01] The race has already started.");
		return;
	}
	
	LockRacePlayers(client);
	ApplyRaceSettings(client);
	new TFClassType:class = TF2_GetPlayerClass(client);
	new team = GetClientTeam(client);
	
	g_bRaceStatus[client] = 2;
	CreateTimer(1.0, RaceCountdown, client);
	
	SendRaceToStart(client, class, team);
	PrintToRace(client, "Teleporting to race start!");
	
	
}

stock PrintToRace(raceID, String:message[])
{
	new String:buffer[128];
	Format(buffer, sizeof(buffer), "\x01[\x03JA\x01] %s", message);
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID) || IsClientSpectatingRace(i, raceID))
		{
			PrintToChat(i, buffer);
		}
	}

}
stock SendRaceToStart(raceID, TFClassType:class, team)
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID))
		{
			if(g_bRaceClassForce[raceID]){
				TF2_SetPlayerClass(i, class);
			}
			ChangeClientTeam(i, team);
			SendToStart(i);
		}
	}

}

stock LockRacePlayers(raceID)
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID))
		{
			g_bRaceLocked[i] = true;
		}
	}
}

stock UnlockRacePlayers(raceID)
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID))
		{
			g_bRaceLocked[i] = false;
		}
	}
}

public Action:cmdRaceLeave(client, args)
{
	if (!IsClientRacing(client)){
		PrintToChat(client, "\x01[\x03JA\x01] You are not in a race.");
		return;
	}
	LeaveRace(client);
	PrintToChat(client, "\x01[\x03JA\x01] You have left the race.");
		
}



public Action:cmdServerRace(client, args)
{

	cmdRaceInitializeServer(client, args);
	
}

public Action:cmdRaceInitializeServer(client, args)
{
	if (!IsValidClient(client)) { return; }
	if (g_bSpeedRun[client]) 
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Speedrun_Active");
		return;
	}
	
	if (g_iCPs == 0){
		PrintToChat(client, "\x01[\x03JA\x01] You may only race on maps with control points.");
		return;
	}
	
	if(IsPlayerFinishedRacing(client))
	{
		LeaveRace(client);
	}
	
	
	if (IsClientRacing(client)){
		PrintToChat(client, "\x01[\x03JA\x01] You are already in a race.");
		return;
	}
	
	
	g_bRace[client] = client;
	g_bRaceStatus[client] = 1;
	g_bRaceClassForce[client] = true;
	
	new String:cpName[32];
	new Handle:menu = CreateMenu(ControlPointSelectorServer);
	SetMenuTitle(menu, "Select End Control Point");
	
	new entity;
	new String:buffer[32];
	while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1)
	{
		
		new pIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");
		GetEntPropString(entity, Prop_Data, "m_iszPrintName", cpName, sizeof(cpName));
		IntToString(pIndex, buffer, sizeof(buffer));
		AddMenuItem(menu, buffer, cpName);
		
	}
	DisplayMenu(menu, client, 300);
	return;
}


public ControlPointSelectorServer(Handle:menu, MenuAction:action, param1, param2)
{

	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_bRaceEndPoint[param1] = StringToInt(info);
		
		new String:buffer[128];
		new String:clientName[128];
		
		GetClientName(param1, clientName, sizeof(clientName));
		for (new i = 1; i <= GetMaxClients(); i++)
		{
			if (IsValidClient(i) && param1 != i)
			{
				
				Format(buffer, sizeof(buffer), "You have been invited to race to %s by %s", GetCPNameByIndex(g_bRaceEndPoint[param1]), clientName);
			

				new Handle:panel = CreatePanel();
				SetPanelTitle(panel, buffer);
				DrawPanelItem(panel, "Accept");
				DrawPanelItem(panel, "Decline");
				
				g_bRaceInvitedTo[i] = param1;
				SendPanelToClient(panel, i, InviteHandler, 15);
				
				CloseHandle(panel);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		g_bRace[param1] = 0;
		PrintToChat(param1, "\x01[\x03JA\x01] The race has been cancelled.");
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}

}


public Action:cmdRaceSpec(client, args){
	if(!IsValidClient(client)){return Plugin_Handled; }
	if(args == 0){
		PrintToChat(client, "\x01[\x03JA\x01] No target race selected.");
		return Plugin_Handled;
	}

	new String:arg1[32];

	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1, true, false);
	if(target == -1){
		return Plugin_Handled;
	}else{
		if(target == client){
			PrintToChat(client, "\x01[\x03JA\x01] You may not spectate yourself.");
			return Plugin_Handled;
		}
		if(!IsClientRacing(target)){
			PrintToChat(client, "\x01[\x03JA\x01] Target client is not in a race.");
			return Plugin_Handled;
		}
		if(IsClientObserver(target)){
			PrintToChat(client, "\x01[\x03JA\x01] You may not spectate a spectator.");
			return Plugin_Handled;
		}
		if(IsClientRacing(client)){
			LeaveRace(client);
		}
		if(!IsClientObserver(client)){
			ChangeClientTeam(client, 1);
			ForcePlayerSuicide(client);
		}
		g_bRaceSpec[client] = g_bRace[target];
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", g_bRace[target]);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 4);


	}
	return Plugin_Continue;
}



public Action:cmdRaceSet(client, args){
	if(!IsValidClient(client)){return Plugin_Handled; }
	if(!IsClientRacing(client)){
		PrintToChat(client, "\x01[\x03JA\x01] You are not in a race.");
		return Plugin_Handled;
	}
	if(!IsRaceLeader(client, g_bRace[client])){
		PrintToChat(client, "\x01[\x03JA\x01] You are not the leader of this race.");
		return Plugin_Handled;
	}
	if(HasRaceStarted(client)){
		PrintToChat(client, "\x01[\x03JA\x01] The race has already started.");
		return Plugin_Handled;
	}
	if(args != 2){
		PrintToChat(client, "\x01[\x03JA\x01] This number of arguments is not supported.");
		return Plugin_Handled;
	}

	new String:arg1[32];
	new String:arg2[32];
	new bool:toSet;

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	PrintToServer(arg2);
	if(!(StrEqual(arg2, "on", false) || StrEqual(arg2, "off", false))){
		PrintToChat(client, "\x01[\x03JA\x01] Your second argument is not valid.");
		return Plugin_Handled;
	}else{
		if(StrEqual(arg2, "on", false)){
			toSet = true;
		}else{
			toSet = false;
		}
	}

	if(StrEqual(arg1, "ammo", false)){
		g_bRaceAmmoRegen[client] = toSet;
		PrintToChat(client, "\x01[\x03JA\x01] Ammo regen has been set.");
	}else if(StrEqual(arg1, "health", false)){
		g_bRaceHealthRegen[client] = toSet;
		PrintToChat(client, "\x01[\x03JA\x01] Health regen has been set.");
	}else if(StrEqual(arg1, "regen", false)){
		g_bRaceAmmoRegen[client] = toSet;
		g_bRaceHealthRegen[client] = toSet;
		PrintToChat(client, "\x01[\x03JA\x01] Regen has been set.");
	}else if(StrEqual(arg1, "cf", false) || StrEqual(arg1, "classforce", false)){
		g_bRaceClassForce[client] = toSet;
		PrintToChat(client, "\x01[\x03JA\x01] Class force has been set.");
	}else{
		PrintToChat(client, "\x01[\x03JA\x01] Invalid setting.");
		return Plugin_Handled;
	}
	return Plugin_Continue;

}





stock ApplyRaceSettings(race){

	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, race))
		{
			g_bAmmoRegen[i] = g_bRaceAmmoRegen[g_bRace[i]];
			g_bHPRegen[i] = g_bRaceHealthRegen[g_bRace[i]];
		}
	}

}



stock GetSpecRace(client)
{
	return g_bRaceSpec[client];
}





stock GetPlayersInRace(raceID)
{
	new players;
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID))
		{
			players++;
		}
	}
	return players;
}


stock GetPlayersStillRacing(raceID)
{
	new players;
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID) && !IsPlayerFinishedRacing(i))
		{
			players++;
		}
	}
	return players;
}

stock LeaveRace(client){
	new race = g_bRace[client];

	if(race == 0){
		return;
	}
	
	if(GetPlayersInRace(race) == 0)
	{
		ResetRace(race);
	}
	
	if(client == race)
	{
		if(GetPlayersInRace(race) == 1)
		{
			ResetRace(race);
		}
		else
		{
			if(HasRaceStarted(race)){
					for (new i = 1; i <= GetMaxClients(); i++)
					{
						if (IsClientInRace(i, race) && IsClientRacing(i))
						{
							new newRace = i;
							new a[32];
							new Float:b[32];
							g_bRaceStatus[i] = g_bRaceStatus[race];
							g_bRaceEndPoint[i] = g_bRaceEndPoint[race];
							g_bRaceStartTime[i] = g_bRaceStartTime[race];
							g_bRaceFirstTime[i] = g_bRaceFirstTime[race];
							g_bRaceAmmoRegen[i] = g_bRaceAmmoRegen[race];
							g_bRaceHealthRegen[i] = g_bRaceHealthRegen[race];
							g_bRaceClassForce[i] = g_bRaceClassForce[race];
							g_bRaceTimes[i] = g_bRaceTimes[race];
							g_bRaceFinishedPlayers[i] = g_bRaceFinishedPlayers[race];

							g_bRace[client] = 0;
							g_bRaceTime[client] = 0.0;
							g_bRaceLocked[client] = false;
							g_bRaceFirstTime[client] = 0.0;
							g_bRaceEndPoint[client] = 0;
							g_bRaceStartTime[client] = 0.0;
							g_bRaceFinishedPlayers[client] = a;
							g_bRaceTimes[client] = b;							
							
							for (new j = 1; j <= GetMaxClients(); j++)
							{
								if (IsClientRacing(j) && !IsRaceLeader(j, race))
								{
									g_bRace[j] = newRace;
								}
							}
							
							return;
							
							
							
						}
					}
			}
			else
			{
				PrintToRace(race, "The race has been cancelled.");
				ResetRace(race);
			}
		}
	}
	else
	{
		g_bRace[client] = 0;
		g_bRaceTime[client] = 0.0;
		g_bRaceLocked[client] = false;
		g_bRaceFirstTime[client] = 0.0;
		g_bRaceEndPoint[client] = 0;
		g_bRaceStartTime[client] = 0.0;
	}
	new String:clientName[128];
	new String:buffer[128];
	GetClientName(client, clientName, sizeof(clientName));
	Format(buffer, sizeof(buffer), "%s has left the race.", clientName);
	
	
	PrintToRace(race, buffer);
}

stock ResetRace(raceID)
{

	for (new i = 0; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID))
		{
			g_bRace[i] = 0;
			g_bRaceStatus[i] = 0;
			g_bRaceTime[i] = 0.0;
			g_bRaceLocked[i] = false;
			g_bRaceFirstTime[i] = 0.0;
			g_bRaceEndPoint[i] = 0;
			g_bRaceStartTime[i] = 0.0;
			g_bRaceAmmoRegen[i] = false;
			g_bRaceHealthRegen[i] = false;
			g_bRaceClassForce[i] = true;

		}
		g_bRaceTimes[raceID][i] = 0.0;
		g_bRaceFinishedPlayers[raceID][i] = 0;
	}
	
}


stock EmitSoundToRace (raceID, String:sound[])
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInRace(i, raceID) || IsClientSpectatingRace(i, raceID))
		{
			EmitSoundToClient(i, sound);
		}
	}
	return;
}

stock EmitSoundToNotRace (raceID, String:sound[])
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (!IsClientInRace(i, raceID) && !IsClientSpectatingRace(i, raceID) && IsValidClient(i))
		{
			EmitSoundToClient(i, sound);
		}
	}
	return;
}


stock bool:IsClientRacing(client){
	if (g_bRace[client] != 0){
		return true;
	}
	return false;
}

stock bool:IsClientInRace(client, race){
	if(g_bRace[client] == race){
		return true;
	}
	return false;
}

stock GetRaceStatus(client){
	return g_bRaceStatus[g_bRace[client]]; 
}

stock bool:IsRaceLeader(client, race){
	if(client == race){
		return true;
	}
	return false;
}

stock bool:HasRaceStarted(client){
	if(g_bRaceStatus[g_bRace[client]] > 1){
		return true;
	}
	return false;
}

stock bool:IsPlayerFinishedRacing(client){
	if(g_bRaceTime[client] != 0.0){
		return true;
	}
	return false;

}

stock bool:IsClientSpectatingRace(client, race){
	if(!IsValidClient(client)){
		return false;
	}
	if(!IsClientObserver(client)){
		return false;
	}
	new iClientToShow, iObserverMode;
	iObserverMode = GetEntPropEnt(client, Prop_Send, "m_iObserverMode");
	iClientToShow = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget"); 
	if (!IsValidClient(client) || !IsValidClient(iClientToShow) || iObserverMode == 6) { 
		return false; 
	}
	
	if(IsClientInRace(iClientToShow, race)){
		return true;
	}
	return false;
}

stock String:TimeFormat(Float:timeTaken){

	new String:formatTime[255];
	new String:formatTime1[255];
	new intTimeTaken;
	new Float:ms;
	new String:msFormat[128];
	new String:msFormatFinal[128];
	new String:final[128];

	ms = timeTaken-RoundToZero(timeTaken);
	Format(msFormat, sizeof(msFormat), "%.3f", ms);
	strcopy(msFormatFinal, sizeof(msFormatFinal), msFormat[2]);
	intTimeTaken = RoundToZero(timeTaken) + 450000;
	FormatTime(formatTime1, sizeof(formatTime1), "%X", intTimeTaken);
	//if(RoundToZero(timeTaken) < 60){
	//	strcopy(formatTime, sizeof(formatTime), formatTime1[6]);
	//}else 
	if(RoundToZero(timeTaken) < 3540){
		strcopy(formatTime, sizeof(formatTime), formatTime1[3]);
	}else{
		strcopy(formatTime, sizeof(formatTime), formatTime1[0]);
	}

	Format(final, sizeof(final), "%s:%s", formatTime, msFormatFinal);

	return final;
}


stock bool:IsRaceOver(client){
	if(g_bRaceStatus[client] == 5){
		return true;
	}
	return false;

}



















































































public Action:cmdToggleAmmo(client, args)
{
	if (!IsValidClient(client)) { return; }
	if(IsClientRacing(client) && !IsPlayerFinishedRacing(client) && HasRaceStarted(client)){
		ReplyToCommand(client, "\x01[\x03JA\x01] You may not change regen during a race");
		return;

	}
	SetRegen(client, "Ammo", "z");
	
}

public Action:cmdToggleHealth(client, args)
{
	if (!IsValidClient(client)) { return; }
	if(IsClientRacing(client) && !IsPlayerFinishedRacing(client) && HasRaceStarted(client)){
		ReplyToCommand(client, "\x01[\x03JA\x01] You may not change regen during a race");
		return;

	}
	SetRegen(client, "Health", "z");
	
}

public Action:cmdToggleHardcore(client, args)
{
	if (!IsValidClient(client)) { return; }
	if (IsUsingJumper(client))
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Jumper_Command_Disabled");
		return;
	}
	Hardcore(client);
	
}


public Action:cmdJAHelp(client, args)
{
	if (!IsValidClient(client)) { return; }
	ReplyToCommand(client, "");
	ReplyToCommand(client, "");
	ReplyToCommand(client, "*************JA HELP**************");
	ReplyToCommand(client, "Put either ! or / in front of each command");
	ReplyToCommand(client, "! - Prints to chat, / - Hidden from chat");
	ReplyToCommand(client, "************COMMANDS**************");
	ReplyToCommand(client, "jumptf - Shows the jump.tf website");
	ReplyToCommand(client, "forums - Shows the jump.tf forums");
	ReplyToCommand(client, "jumpassist - Shows the jumpassist forum page");
	ReplyToCommand(client, "regen <on|off> - Sets ammo & health regen");
	ReplyToCommand(client, "ammo - Toggles ammo regen");
	ReplyToCommand(client, "health - Toggles health regen");
	ReplyToCommand(client, "undo - Reverts your last save");
	ReplyToCommand(client, "skeys_color <R> <G> <B> - Skeys color");
	ReplyToCommand(client, "skeys - Shows key presses on the screen");
	ReplyToCommand(client, "save or s - Saves your position");
	ReplyToCommand(client, "tele or t - Teleports you to your saved position");
	ReplyToCommand(client, "reset or r - Restarts you on the map");
	ReplyToCommand(client, "restart - Deletes your save and restarts you");
	if(IsUserAdmin(client)){
		ReplyToCommand(client, "**********ADMIN COMMANDS**********");
		ReplyToCommand(client, "mapset - Change map settings");
		ReplyToCommand(client, "addtele - Add a teleport location");
		ReplyToCommand(client, "jatele - Teleport a user to a location");
	}
	

	
	return;

}

public Action:cmdRaceHelp(client, args)
{
	if (!IsValidClient(client)) { return; }
	ReplyToCommand(client, "");
	ReplyToCommand(client, "");
	ReplyToCommand(client, "************RACE HELP*************");
	ReplyToCommand(client, "!r_set - Change settings of a race.");
	ReplyToCommand(client, "     <classforce|cf|ammo|health|regen>");
	ReplyToCommand(client, "     <on|off>");
	ReplyToCommand(client, "!r_info - Provides info about the current race.");
	ReplyToCommand(client, "!r_list - Lists race players and their times");
	ReplyToCommand(client, "!r_spec - Spectates a race.");
	ReplyToCommand(client, "!race - Initialize a race and select final CP.");
	ReplyToCommand(client, "!r_inv - Invite players to the race.");
	ReplyToCommand(client, "!r_start - Start the race.");
	ReplyToCommand(client, "!r_leave - Leave a race.");
	if(IsUserAdmin(client)){
		ReplyToCommand(client, "**********ADMIN COMMANDS**********");
		ReplyToCommand(client, "!s_race - Invites everyone in the server to a race");
	}

	

	
	return;

}





stock bool:IsUsingJumper(client)
{
	if (!IsValidClient(client)) { return false; }

	if (TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		if (!IsValidWeapon(g_iClientWeapons[client][0])) { return false; }
		new sol_weap = GetEntProp(g_iClientWeapons[client][0], Prop_Send, "m_iItemDefinitionIndex");
		switch (sol_weap)
		{
			case 237:
				return true;
		}
		return false;
	}

	if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
	{
		if (!IsValidWeapon(g_iClientWeapons[client][1])) { return false; }
		new dem_weap = GetEntProp(g_iClientWeapons[client][1], Prop_Send, "m_iItemDefinitionIndex");
		switch (dem_weap)
		{
			case 265:
				return true;
		}
		return false;
	}
	return false;
}


stock IsStringNumeric(const String:MyString[])
{
	new n=0;
	while (MyString[n] != '\0') 
	{
		if (!IsCharNumeric(MyString[n]))
		{
			return false;
		}
		n++;
	}
	return true;
}
public Action:RunQuery(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "\x01[\x03JA\x01] More parameters are required for this command.");
		return Plugin_Handled;
	}
	decl String:query[1024];
	GetCmdArgString(query, sizeof(query));
	
	SQL_TQuery(g_hDatabase, SQL_OnPlayerRanSQL, query, client);
	return Plugin_Handled;
}
public Action:cmdUnkillable(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	if (!GetConVarBool(g_hSuperman) && !IsUserAdmin(client))
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Command_Locked");
		return Plugin_Handled;
	}

	if (g_bSpeedRun[client]) 
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Speedrun_Active");
		return Plugin_Handled;
	}

	if (!g_bUnkillable[client])
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_UnkillableOn");
		g_bUnkillable[client] = true;
	} else {
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_UnkillableOff");
		g_bUnkillable[client] = false;
	}
	return Plugin_Handled;
}
public Action:cmdUndo(client, args)
{
	if (g_bSpeedRun[client])
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Save_UndoSpeedRun");
		return Plugin_Handled;
	}
	if (g_fLastSavePos[client][0] == 0.0) 
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Save_UndoCant");
		return Plugin_Handled;
	} else {
		g_fOrigin[client][0] = g_fLastSavePos[client][0]; g_fAngles[client][0] = g_fLastSaveAngles[client][0];
		g_fOrigin[client][1] = g_fLastSavePos[client][1]; g_fAngles[client][1] = g_fLastSaveAngles[client][1];
		g_fOrigin[client][2] = g_fLastSavePos[client][2]; g_fAngles[client][2] = g_fLastSaveAngles[client][2];
		
		g_fLastSavePos[client][0] = 0.0; g_fLastSavePos[client][1] = 0.0; g_fLastSavePos[client][2] = 0.0;

		PrintToChat(client, "\x01[\x03JA\x01] %t", "Save_Undo");
		return Plugin_Handled;
	}
}
public Action:cmdDoRegen(client, args)
{
	if(IsClientRacing(client) && !IsPlayerFinishedRacing(client) && HasRaceStarted(client)){
		ReplyToCommand(client, "\x01[\x03JA\x01] You may not change regen during a race");
		return Plugin_Handled;

	}
	decl String:arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));

	if (StrEqual(arg1, "on", false))
	{
		SetRegen(client, "regen", "on");
		return Plugin_Handled;
	} else if (StrEqual(arg1, "off", false)) 
	{
		SetRegen(client, "regen", "off");
		return Plugin_Handled;
	} else {
		SetRegen(client, "Regen", "Display");
	}
	return Plugin_Handled;
}

//public Action:cmdClearSave(client, args)
//{
//	if (GetConVarBool(g_hPluginEnabled))
//	{
//		EraseLocs(client);
//		PrintToChat(client, "\x01[\x03JA\x01] %t", "Player_ClearedSave");
//	}
//	return Plugin_Handled;
//}

public Action:cmdSendPlayer(client, args)
{
	if(!databaseConfigured)
	{
		PrintToChat(client, "This feature is not supported without a database configuration");
		return Plugin_Handled;
	}
	if (GetConVarBool(g_hPluginEnabled))
	{
		if (args < 2)
		{
			ReplyToCommand(client, "\x01[\x03JA\x01] %t", "SendPlayer_Help", LANG_SERVER);
			return Plugin_Handled;
		}
		new String:arg1[MAX_NAME_LENGTH];
		new String:arg2[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));

		new target1 = FindTarget2(client, arg1, true, false);
		new target2 = FindTarget2(client, arg2, true, false);
		
		if (target1 == client)
		{
			ReplyToCommand(client, "\x01[\x03JA\x01] %t", "SendPlayer_Self", cLightGreen, cDefault);
			return Plugin_Handled;
		}
		if (!target1 || !target2)
		{
			return Plugin_Handled;	
		}
		new Float:TargetOrigin[3];
		new Float:pAngle[3];
		new Float:pVec[3];
		GetClientAbsOrigin(target2, TargetOrigin);
		GetClientAbsAngles(target2, pAngle);

		pVec[0] = 0.0;
		pVec[1] = 0.0;
		pVec[2] = 0.0;

		TeleportEntity(target1, TargetOrigin, pAngle, pVec);
		
		new String:target1_name[MAX_NAME_LENGTH];
		new String:target2_name[MAX_NAME_LENGTH];

		GetClientName(target1, target1_name, sizeof(target1_name));
		GetClientName(target2, target2_name, sizeof(target2_name));

		ShowActivity2(client, "\x01[\x03JA\x01] ", "%t", "Send_Player", target1_name, target2_name);
	}
	return Plugin_Handled;
}
public Action:cmdGotoClient(client, args)
{
	if (GetConVarBool(g_hPluginEnabled))
	{
		//can use this too g_bBeatTheMap[client] && !g_bSpeedRun[client]
		if (IsUserAdmin(client))
		{
			if (args < 1)
			{
				ReplyToCommand(client, "\x01[\x03JA\x01] %t", "Goto_Help", LANG_SERVER);
				return Plugin_Handled;
			}
			if (IsClientObserver(client))
			{
				ReplyToCommand(client, "\x01[\x03JA\x01] %t", "Goto_Spectate", LANG_SERVER);
				return Plugin_Handled;
			}

			new String:arg1[MAX_NAME_LENGTH];
			GetCmdArg(1, arg1, sizeof(arg1));

			new String:target_name[MAX_TARGET_LENGTH], target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

			new Float:TeleportOrigin[3], Float:PlayerOrigin[3], Float:pAngle[3], Float:PlayerOrigin2[3], Float:g_fPosVec[3];
			if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, target_name, sizeof(target_name), tn_is_ml)) <= 0)
			{
				ReplyToCommand(client, "\x01[\x03JA\x01] %t", "No matching client", LANG_SERVER);
				return Plugin_Handled;
			}
			if (target_count > 1)
			{
				ReplyToCommand(client, "\x01[\x03JA\x01] %t", "More than one client matched", LANG_SERVER);
				return Plugin_Handled;
			}
			for (new i = 0; i < target_count; i++)
			{
				if (IsClientObserver(target_list[i]) || !IsValidClient(target_list[i]))
				{
					ReplyToCommand(client, "\x01[\x03JA\x01] %t", "Goto_Cant", LANG_SERVER, target_name);
					return Plugin_Handled;
				}
				if (target_list[i] == client)
				{
					ReplyToCommand(client, "\x01[\x03JA\x01] %t", "Goto_Self", LANG_SERVER);
					return Plugin_Handled;
				}
				GetClientAbsOrigin(target_list[i], PlayerOrigin);
				GetClientAbsAngles(target_list[i], PlayerOrigin2);

				TeleportOrigin[0] = PlayerOrigin[0];
				TeleportOrigin[1] = PlayerOrigin[1];
				TeleportOrigin[2] = PlayerOrigin[2];

				pAngle[0] = PlayerOrigin2[0];
				pAngle[1] = PlayerOrigin2[1];
				pAngle[2] = PlayerOrigin2[2];

				g_fPosVec[0] = 0.0;
				g_fPosVec[1] = 0.0;
				g_fPosVec[2] = 0.0;

				TeleportEntity(client, TeleportOrigin, pAngle, g_fPosVec);
				PrintToChat(client, "\x01[\x03JA\x01] %t", "Goto_Success", target_name);
			}
		} else {
			ReplyToCommand(client, "\x01[\x03JA\x01] %t", "No Access", LANG_SERVER);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
public Action:cmdReset(client, args)
{
	if (GetConVarBool(g_hPluginEnabled))
	{
		if (skillsrank)
		{
			if (IsPlayerBusy(client))
			{
				PrintToChat(client, "\x01[\x03JA\x01] %t", "General_Busy");
				return Plugin_Handled;
			}
		}
		if (IsClientObserver(client))
		{
			return Plugin_Handled;
		}
		
		SendToStart(client);
		g_bUsedReset[client] = true;
	}
	return Plugin_Handled;
}

public Action:cmdTele(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	Teleport(client);
	return Plugin_Handled;
}
public Action:cmdSave(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	SaveLoc(client);
	return Plugin_Handled;
}
Teleport(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (!IsValidClient(client)) { return; }
	if (g_bRace[client] && (g_bRaceStatus[g_bRace[client]] == 2 || g_bRaceStatus[g_bRace[client]] == 3) )
	{
		PrintToChat(client, "\x01[\x03JA\x01] Cannot teleport while racing.");
		return;
	}

	if (g_bSpeedRun[client]) 
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Speedrun_Active");
		return;
	}
	new g_iClass = int:TF2_GetPlayerClass(client);
	new g_iTeam = GetClientTeam(client);
	decl String:g_sClass[32], String:g_sTeam[32];
	new Float:g_vVelocity[3];
	g_vVelocity[0] = 0.0; g_vVelocity[1] = 0.0; g_vVelocity[2] = 0.0;

	Format(g_sClass, sizeof(g_sClass), "%s", GetClassname(g_iClass));

	if (g_iTeam == 2)
	{
		Format(g_sTeam, sizeof(g_sTeam), "%T", "Red_Team", LANG_SERVER);
	} else if (g_iTeam == 3)
	{
		Format(g_sTeam, sizeof(g_sTeam), "%T", "Blu_Team", LANG_SERVER);
	}
	if (g_bHardcore[client])
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Teleports_Disabled");
	else if(!IsPlayerAlive(client))
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Teleport_Dead");
	else if(g_fOrigin[client][0] == 0.0)
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Teleport_NoSave", g_sClass, g_sTeam, cLightGreen, cDefault, cLightGreen, cDefault);
	else
	{
		TeleportEntity(client, g_fOrigin[client], g_fAngles[client], g_vVelocity);
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Teleported_Self");
	}
}
SaveLoc(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (g_bSpeedRun[client]) 
	{
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Speedrun_Active");
		return;
	}
	if (g_bHardcore[client])
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Saves_Disabled");
	else if(!IsPlayerAlive(client))
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Saves_Dead");	
	else if(!(GetEntityFlags(client) & FL_ONGROUND))
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Saves_InAir");
	else if(GetEntProp(client, Prop_Send, "m_bDucked") == 1)
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Saves_Ducked");
	else
	{
		g_fLastSavePos[client][0] = g_fOrigin[client][0]; g_fLastSaveAngles[client][0] = g_fAngles[client][0];
		g_fLastSavePos[client][1] = g_fOrigin[client][1]; g_fLastSaveAngles[client][1] = g_fAngles[client][1];
		g_fLastSavePos[client][2] = g_fOrigin[client][2]; g_fLastSaveAngles[client][2] = g_fAngles[client][2];

		GetClientAbsOrigin(client, g_fOrigin[client]);
		GetClientAbsAngles(client, g_fAngles[client]);
		if(databaseConfigured){
			GetPlayerData(client);
		}
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Saves_Location");
	}
}
ResetPlayerPos(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (!IsClientInGame(client) || IsClientObserver(client))
	{
		return;
	}
	DeletePlayerData(client);
	return;
}
Hardcore(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	if (skillsrank)
	{
		if (IsPlayerBusy(client))
		{
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Hardcore_SettingsBusy");
			return;
		}
	}

	new String:steamid[32];
	GetClientAuthString(client, steamid, sizeof(steamid));

	if (!IsClientInGame(client))
	{
		return;
	}
	else if (IsClientObserver(client))
	{
		return;
	}
	if (!g_bHardcore[client]) 
	{
		g_bHardcore[client] = true;
		g_bHPRegen[client] = false;
		EraseLocs(client);
		TF2_RespawnPlayer(client);
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Hardcore_On", cLightGreen, cDefault);
	} else {
		g_bHardcore[client] = false;
		LoadPlayerData(client);
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Hardcore_Off");
	}
}
SetDesc()
{
	decl String:desc[128];
	Format(desc, sizeof(desc), "Jump Assist (%s)", PLUGIN_VERSION);
	Steam_SetGameDescription(desc);
}
SetRegen(client, String:RegenType[], String:RegenToggle[])
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	if (skillsrank)
	{
		if (IsPlayerBusy(client))
		{
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_SettingsBusy");
			return;
		}
	}

	if (StrEqual(RegenType, "Ammo", false))
	{
		if (g_bHardcore[client]) { g_bHardcore[client] = false; }
		if (!g_bAmmoRegen[client])
		{
			g_bAmmoRegen[client] = true;
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_AmmoOnlyOn");
			return;
		} else {
			g_bAmmoRegen[client] = false;
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_AmmoOnlyOff");
			return;
		}
	}
	if (StrEqual(RegenType, "Health", false))
	{
		if (g_bHardcore[client]) { g_bHardcore[client] = false; }
		if (!g_bHPRegen[client])
		{
			g_bHPRegen[client] = true;
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_HealthOnlyOn");
			return;
		} else {
			g_bHPRegen[client] = false;
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_HealthOnlyOff");
			return;
		}
	}
	if (StrEqual(RegenType, "Regen", false) && StrEqual(RegenToggle, "display", false))
	{
		if (!g_bAmmoRegen[client])
		{
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_DisplayAmmoOff");
		} else {
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_DisplayAmmoOn");
		}
		if (!g_bHPRegen[client])
		{
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_DisplayHealthOff");
		} else {
			PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_DisplayHealthOn");
		}
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_ShowHelp");
		return;
	} else if (StrEqual(RegenType, "Regen", false) && StrEqual(RegenToggle, "on", false))
	{
		g_bAmmoRegen[client] = true;
		g_bHPRegen[client] = true;
		
		if (g_bHardcore[client]) { g_bHardcore[client] = false; }
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_On");
	} else if (StrEqual(RegenType, "Regen", false) && StrEqual(RegenToggle, "off", false))
	{
		g_bAmmoRegen[client] = false;
		g_bHPRegen[client] = false;
		
		if (g_bHardcore[client]) { g_bHardcore[client] = false; }
		PrintToChat(client, "\x01[\x03JA\x01] %t", "Regen_Off");
	} else {
		LogError("Unknown regen settings.");
	}
	return;
}
public Action:cmdJumpTF(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	ShowMOTDPanel(client, "Jump Assist Help", szWebsite, MOTDPANEL_TYPE_URL);
	return;
}
public Action:cmdJumpAssist(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	ShowMOTDPanel(client, "Jump Assist Help", szJumpAssist, MOTDPANEL_TYPE_URL);
	return;
}
public Action:cmdJumpForums(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	ShowMOTDPanel(client, "Jump Assist Help", szForum, MOTDPANEL_TYPE_URL);
	return;
}
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){

	g_iButtons[client] = buttons; //FOR SKEYS AS WELL AS REGEN
	if ((g_iButtons[client] & IN_ATTACK) == IN_ATTACK)
	{
		if (g_bAmmoRegen[client])
		{
			ReSupply(client, g_iClientWeapons[client][0]);
			ReSupply(client, g_iClientWeapons[client][1]);
			ReSupply(client, g_iClientWeapons[client][2]);
		}
		if (g_bHPRegen[client]){
			new iMaxHealth = TF2_GetPlayerResourceData(client, TFResource_MaxHealth);
			SetEntityHealth(client, iMaxHealth);
		}
	}
	
	if(g_bRaceLocked[client])
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		if(buttons & IN_BACK) 
		{
			return Plugin_Handled;
		}
		if(buttons & IN_FORWARD) 
		{
			return Plugin_Handled;
		}
		if(buttons & IN_MOVERIGHT) 
		{
			return Plugin_Handled;
		}
		if(buttons & IN_MOVELEFT) 
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}
		
		

public SDKHook_OnWeaponEquipPost(client, weapon)
{
	if (IsValidClient(client))
	{
		g_iClientWeapons[client][0] = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		g_iClientWeapons[client][1] = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		g_iClientWeapons[client][2] = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	}
}
stock bool:IsValidWeapon(iEntity)
{
	decl String:strClassname[128];
	if (IsValidEntity(iEntity) && GetEntityClassname(iEntity, strClassname, sizeof(strClassname)) && StrContains(strClassname, "tf_weapon", false) != -1) return true;
	return false;
}
stock ReSupply(client, iWeapon)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (!IsValidWeapon(iWeapon))
	{
		return;
	}

	// Primary Weapons
	switch(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
	{
		// Rocket Launchers
		case 18,205,127,513,800,809,658:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 4);
			SetAmmo(client, iWeapon, 20);
		}
		// Black box, Liberty launcher.
		case 228, 414:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 3);
			SetAmmo(client, iWeapon, 20);
		}
		// Rocket Jumper
		case 237:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 4);
			SetAmmo(client, iWeapon, 60);
		}
		
		// Ullapool caber
		/* Removed
		case 307:
		{
			if (GetConVarBool(g_hReloadUC))
			{
				SetEntProp(iWeapon, Prop_Send, "m_bBroken", 0);
				SetEntProp(iWeapon, Prop_Send, "m_iDetonated", 0);
			}
		}
		*/
		
		// Stickybomb Launchers
		case 20, 207:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 8);
			SetAmmo(client, iWeapon, 24);
		}
		// Sticky jumper
		case 265:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 8);
			SetAmmo(client, iWeapon, 72);
		}
		// Scottish Resistance
		case 130:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 8);
			SetAmmo(client, iWeapon, 36);
		}
		// Heavy, soldier, pyro, and engineer shotgun
		case 9, 10, 11, 12, 199:
		{
			SetEntProp(iWeapon, Prop_Data, "m_iClip1", 6);
			SetAmmo(client, iWeapon, 32);
		}
	}
}
stock SetAmmo(client, iWeapon, iAmmo)
{
	new iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if(iAmmoType != -1) SetEntProp(client, Prop_Data, "m_iAmmo", iAmmo, _, iAmmoType);
}
EraseLocs(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	g_fOrigin[client][0] = 0.0; g_fOrigin[client][1] = 0.0; g_fOrigin[client][2] = 0.0;
	g_fAngles[client][0] = 0.0; g_fAngles[client][1] = 0.0; g_fAngles[client][2] = 0.0;
	
	for(new j = 0; j < 8; j++)
	{
		g_bCPTouched[client][j] = false;
		g_iCPsTouched[client] = 0;
	}
	g_bBeatTheMap[client] = false;

	Format(g_sCaps[client], sizeof(g_sCaps), "\0");
}
CheckTeams()
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new maxplayers = GetMaxClients();
	for (new i=1; i<=maxplayers; i++)
	{
		if (!IsClientInGame(i) || IsClientObserver(i))
		{
			continue;
		} else if (GetClientTeam(i) == g_iForceTeam)
		{
			continue;
		}
		else {
			ChangeClientTeam(i, g_iForceTeam);
			PrintToChat(i, "\x01[\x03JA\x01] %t", "Switched_Teams");
		}
	}
}
LockCPs()
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new iCP = -1;
	g_iCPs = 0;
	while ((iCP = FindEntityByClassname(iCP, "trigger_capture_area")) != -1)
	{
		SetVariantString("2 0");
		AcceptEntityInput(iCP, "SetTeamCanCap");
		SetVariantString("3 0");
		AcceptEntityInput(iCP, "SetTeamCanCap");
		g_iCPs++;
	}
}
public Action:cmdRestart(client, args)
{
	if (!IsValidClient(client) || IsClientObserver(client) || !GetConVarBool(g_hPluginEnabled))
	{		
		return Plugin_Handled;
	}
	if (skillsrank)
	{	
		if (IsPlayerBusy(client))
		{
			PrintToChat(client, "\x01[\x03JA\x01] %t", "General_Busy");
			return Plugin_Handled;
		}
	}
	
	EraseLocs(client);
	if(databaseConfigured)
	{
		ResetPlayerPos(client);
	}
	TF2_RespawnPlayer(client);
	PrintToChat(client, "\x01[\x03JA\x01] %t", "Player_Restarted");
	return Plugin_Handled;
}
SendToStart(client)
{
	if (!IsValidClient(client) || IsClientObserver(client) || !GetConVarBool(g_hPluginEnabled))
	{
		return;
	}

	g_bUsedReset[client] = true;

	TF2_RespawnPlayer(client);
	PrintToChat(client, "\x01[\x03JA\x01] %t", "Player_SentToStart");
}
stock String:GetClassname(class)
{
	new String:buffer[128];
	switch(class)
	{
		case 1:	{ Format(buffer, sizeof(buffer), "%T", "Class_Scout", LANG_SERVER); }
		case 2: { Format(buffer, sizeof(buffer), "%T", "Class_Sniper", LANG_SERVER); }
		case 3: { Format(buffer, sizeof(buffer), "%T", "Class_Soldier", LANG_SERVER); }
		case 4: { Format(buffer, sizeof(buffer), "%T", "Class_Demoman", LANG_SERVER); }
		case 5: { Format(buffer, sizeof(buffer), "%T", "Class_Medic", LANG_SERVER); }
		case 6: { Format(buffer, sizeof(buffer), "%T", "Class_Heavy", LANG_SERVER); }
		case 7: { Format(buffer, sizeof(buffer), "%T", "Class_Pyro", LANG_SERVER); }
		case 8: { Format(buffer, sizeof(buffer), "%T", "Class_Spy", LANG_SERVER); }
		case 9: { Format(buffer, sizeof(buffer), "%T", "Class_Engineer", LANG_SERVER); }
	}
	return buffer;
}
bool:IsValidClient( client )
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || IsFakeClient(client))
        return false;
    
    return true;
}
public jteleHandler(Handle:menu, MenuAction:action, client, item)
{
	//decl String:MenuInfo[64];
	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, item, Jtele, sizeof(Jtele));
		JumpList(client);
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
	return;
}
stock FindTarget2(client, const String:target[], bool:nobots = false, bool:immunity = true)
{
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[1], target_count, bool:tn_is_ml;

	new flags = COMMAND_FILTER_NO_MULTI;
	if (nobots)
	{
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if (!immunity)
	{
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	if ((target_count = ProcessTargetString(
			target,
			client, 
			target_list, 
			1, 
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		return target_list[0];
	}
	else
	{
		if (target_count == 0) { return -1; }
		ReplyToCommand(client, "\x01[\x03JA\x01] %t", "No matching client");
		return -1;
	}
}
// Ugly wtf was I thinking?
stock GetValidClassNum(String:class[])
{
	new iClass = -1;
	if(StrEqual(class,"scout", false))
	{
		iClass = 1;
		return iClass;
	}
	if(StrEqual(class,"sniper", false))
	{
		iClass = 2;
		return iClass;
	}
	if(StrEqual(class,"soldier", false))
	{
		iClass = 3;
		return iClass;
	}
	if(StrEqual(class,"demoman", false))
	{
		iClass = 4;
		return iClass;
	}
	if(StrEqual(class,"medic", false))
	{
		iClass = 5;
		return iClass;
	}
	if(StrEqual(class,"heavy", false))
	{
		iClass = 6;
		return iClass;
	}
	if(StrEqual(class,"pyro", false))
	{
		iClass = 7;
		return iClass;
	}
	if(StrEqual(class,"spy", false))
	{
		iClass = 8;
		return iClass;
	}
	if(StrEqual(class,"engineer", false))
	{
		iClass = 9;
		return iClass;
	}
	return iClass;
}
public JumpListHandler(Handle:menu, MenuAction:action, client, item)
{
	if(!databaseConfigured)
	{
		PrintToChat(client, "This feature is not supported without a database configuration");
		return;
	}
	decl String:MenuInfo[64];
	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, item, MenuInfo, sizeof(MenuInfo));
		MenuSendToLocation(client, Jtele, MenuInfo);
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
	return;
}
stock bool:IsUserAdmin(client)
{
	new bool:IsAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic);

	if (IsAdmin)
		return true;
	else
		return false;
}
stock SetCvarValues()
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (!GetConVarBool(g_hCriticals))
		SetConVarInt(FindConVar("tf_weapon_criticals"), 0, true, false);
	if (GetConVarBool(g_hFastBuild))
		SetConVarInt(FindConVar("tf_fastbuild"), 1, false, false);
	if (GetConVarBool(g_hCheapObjects))
		SetConVarInt(FindConVar("tf_cheapobjects"), 1, false, false);
	if (GetConVarBool(g_hAmmoCheat))
		SetConVarInt(FindConVar("tf_sentrygun_ammocheat"), 1, false, false); 
}
/*****************************************************************************************************************
													Natives
*****************************************************************************************************************/
public Native_JA_GetSettings(Handle:plugin, numParams)
{
	new setting = GetNativeCell(1);
	new client = GetNativeCell(2);
	
	if (client != -1)
	{
		// Client is only needed for all but 1 setting so far.
		if (client < 1 || client > GetMaxClients())
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
		}
		if (!IsClientConnected(client))
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
		}
	}
	
	switch (setting)
	{
		case 1: { return g_iMapClass; }
		case 2: { return g_bAmmoRegen[client]; }
		case 3: { return g_bHPRegen[client]; }
	}
	return ThrowNativeError(SP_ERROR_NATIVE, "Invalid setting param.");
}
public Native_JA_ClearSave(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	if (client < 1 || client > GetMaxClients())
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	
	EraseLocs(client);
	PrintToChat(client, "\x01[\x03JA\x01] %t", "Native_ClearSave");
	return true;
}
public Native_JA_PrepSpeedRun(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	if (client < 1 || client > GetMaxClients())
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}

	EraseLocs(client);

	if (g_bUnkillable[client]) { g_bUnkillable[client] = false; SetEntProp(client, Prop_Data, "m_takedamage", 2, 1); }
	
	g_bSpeedRun[client] = true;
	PrintToChat(client, "\x01[\x03JA\x01] %t", "Native_ClearSave");

	return true;
}
public Native_JA_ReloadPlayerSettings(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	if (client < 1 || client > GetMaxClients())
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}

	g_bSpeedRun[client] = false;
	ReloadPlayerData(client);
	return true;
}
/*****************************************************************************************************************
												Player Events
*****************************************************************************************************************/
public Action:eventPlayerBuiltObj(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid")), object = GetEventInt(event, "object"), index = GetEventInt(event, "index");
	
	if (object == 2)
	{
		if (GetConVarInt(g_hSentryLevel) == 3)
		{
			SetEntData(index, FindSendPropOffs("CObjectSentrygun", "m_iUpgradeLevel"), 3, 4);
			SetEntData(index, FindSendPropOffs("CObjectSentrygun", "m_iUpgradeMetal"), 200);
		}
	}
	if (!g_bHardcore[client])
	{
		SetEntData(client, FindDataMapOffs(client, "m_iAmmo") + (3 * 4), 199, 4);
	}
}
public Action:eventPlayerUpgradedObj(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid")); //object = GetEventInt(event, "object"), index = GetEventInt(event, "index");

	if (!g_bHardcore[client])
	{
		SetEntData(client, FindDataMapOffs(client, "m_iAmmo") + (3 * 4), 199, 4);
	}
}
public Action:eventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:currentMap[32]; GetCurrentMap(currentMap, sizeof(currentMap));
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	if (g_iLockCPs == 1) { LockCPs(); }

	SetCvarValues();
}
public Action:eventTouchCP(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	new client = GetEventInt(event, "player"), area = GetEventInt(event, "area"), class = int:TF2_GetPlayerClass(client), entity;
	decl String:g_sClass[33], String:playerName[64], String:cpName[32], String:s_area[32];
	
	if (!g_bCPTouched[client][area] || g_bRace[client] != 0)
	{
		

		Format(g_sClass, sizeof(g_sClass), "%s", GetClassname(class));
		GetClientName(client, playerName, 64);
		
		while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1)
		{
			new pIndex = GetEntProp(entity, Prop_Data, "m_iPointIndex");
			if (pIndex == area)
			{
				new bool:raceComplete;

				if(g_bRaceEndPoint[g_bRace[client]] == pIndex && !IsPlayerFinishedRacing(client) && HasRaceStarted(client)){

					raceComplete = true;
					new Float:time;
					new String:timeString[255];
					new String:clientName[128];
					new String:buffer[128];

					time = GetEngineTime();

					g_bRaceTime[client] = time;
					new Float:timeTaken;
					timeTaken = time - g_bRaceStartTime[g_bRace[client]];

					timeString = TimeFormat(timeTaken);

					GetClientName(client, clientName, sizeof(clientName));
					
					if(RoundToNearest(g_bRaceFirstTime[g_bRace[client]]) == 0)
					{
						Format(buffer, sizeof(buffer), "%s won the race in %s!", clientName, timeString);
						g_bRaceFirstTime[g_bRace[client]] = time;
						g_bRaceStatus[g_bRace[client]] = 4;

						for(new i = 0; i < MAXPLAYERS; i++){
							if(g_bRaceFinishedPlayers[g_bRace[client]][i] == 0){
								g_bRaceFinishedPlayers[g_bRace[client]][i] = client;
								g_bRaceTimes[g_bRace[client]][i] = time;
								break;
							}
						}



						EmitSoundToRace(client, "misc/killstreak.wav");
					}
					else
					{
						new Float:firstTime;
						new Float:diff;
						new String:diffFormatted[255];

						firstTime = g_bRaceFirstTime[g_bRace[client]];
						diff = time - firstTime;
						diffFormatted = TimeFormat(diff);

						for(new i = 0; i < MAXPLAYERS; i++){
							if(g_bRaceFinishedPlayers[g_bRace[client]][i] == 0){
								g_bRaceFinishedPlayers[g_bRace[client]][i] = client;
								g_bRaceTimes[g_bRace[client]][i] = time;
								break;
							}
						}

						Format(buffer, sizeof(buffer), "%s finished the race in %s[-%s]!", clientName, timeString, diffFormatted);
						EmitSoundToRace(client, "misc/freeze_cam.wav");
					}
					
					if(RoundToZero(g_bRaceFirstTime[g_bRace[client]]) == 0)
					{
						g_bRaceFirstTime[g_bRace[client]] = time;
					}
					
					PrintToRace(g_bRace[client], buffer);
					
					if (GetPlayersStillRacing(g_bRace[client]) == 0)
					{
						PrintToRace(g_bRace[client], "Everyone has finished the race.");
						PrintToRace(g_bRace[client], "\x01Type \x03!r_list\x01 to see all times.");
						g_bRaceStatus[g_bRace[client]] = 5;
						
					}
				}


				if (!g_bCPTouched[client][area]){
					GetEntPropString(entity, Prop_Data, "m_iszPrintName", cpName, sizeof(cpName));

					if (g_bHardcore[client])
					{
						// "Hardcore" mode
						PrintToChatAll("\x01[\x03JA\x01] %t", "Player_Capped_BOSS", playerName, cpName, g_sClass, cLightGreen, cDefault, cLightGreen, cDefault, cLightGreen, cDefault);
						if(raceComplete){
							EmitSoundToNotRace(client, "misc/tf_nemesis.wav");
						}else{
							EmitSoundToAll("misc/tf_nemesis.wav");
						}
					} else {
						// Normal mode
						PrintToChatAll("\x01[\x03JA\x01] %t", "Player_Capped", playerName, cpName, g_sClass, cLightGreen, cDefault, cLightGreen, cDefault, cLightGreen, cDefault);
						if(raceComplete){
							EmitSoundToNotRace(client, "misc/freeze_cam.wav");
						}else{
							EmitSoundToAll("misc/freeze_cam.wav");
						}
					}

					if (g_iCPsTouched[client] == g_iCPs)
					{
						g_bBeatTheMap[client] = true;
						//PrintToChat(client, "\x01[\x03JA\x01] %t", "Goto_Avail");
					}
				}
				
				
			}
			//SaveCapData(client);
		}
		
		g_bCPTouched[client][area] = true; g_iCPsTouched[client]++; IntToString(area, s_area, sizeof(s_area));
		if (g_sCaps[client] != -1) { Format(g_sCaps[client], sizeof(g_sCaps), "%s%s", g_sCaps[client], s_area); } else { Format(g_sCaps[client], sizeof(g_sCaps), "%s", s_area); }
		
		
		
		
		
	}
}
public Action:eventPlayerChangeClass(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientRacing(client) && !IsPlayerFinishedRacing(client) && HasRaceStarted(client)){
		if(g_bRaceClassForce[g_bRace[client]]){
			new TFClassType:oldclass = TF2_GetPlayerClass(client);
			TF2_SetPlayerClass(client, oldclass);
			PrintToChat(client, "\x01[\x03JA\x01] Cannot change class while racing.");
			return;
		}
	}


	
	decl String:g_sClass[MAX_NAME_LENGTH], String:steamid[32];
	
	EraseLocs(client);
	TF2_RespawnPlayer(client);
	
	g_bUnkillable[client] = false;
	
	GetClientAuthString(client, steamid, sizeof(steamid));

	new class = int:TF2_GetPlayerClass(client);
	Format(g_sClass, sizeof(g_sClass), "%s", GetClassname(g_iMapClass));

	if (g_iMapClass != -1)
	{
		if (class != g_iMapClass)
		{
			g_bHPRegen[client] = true;
			g_bAmmoRegen[client] = true;
			g_bHardcore[client] = false;

			PrintToChat(client, "\x01[\x03JA\x01] %t", "Designed_For", cLightGreen, g_sClass, cDefault);
		}
	}
}
public Action:eventPlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	new client = GetClientOfUserId(GetEventInt(event, "userid")), team = GetEventInt(event, "team");
	if (g_bRace[client] && (g_bRaceStatus[g_bRace[client]] == 2 || g_bRaceStatus[g_bRace[client]] == 3))
	{
		PrintToChat(client, "\x01[\x03JA\x01] You may not change teams during the race.");
		return Plugin_Handled;
	}

	g_bUnkillable[client] = false;

	if (team == 1 || g_iForceTeam == 1 || team == g_iForceTeam)
	{
		EraseLocs(client);
	} else {
		CreateTimer(0.1, timerTeam, client);
	}
	return Plugin_Handled;
}
public Action:eventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, timerRespawn, client);
}
public Action:eventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_bHPRegen[client])
	{
		CreateTimer(0.1, timerRegen, client);
	}
	if (g_bAmmoRegen[client])
	{
		ReSupply(client, g_iClientWeapons[client][0]);
		ReSupply(client, g_iClientWeapons[client][1]);
		ReSupply(client, g_iClientWeapons[client][2]);
	}
}
public Action:eventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Check if they have the jumper equipped, and hardcore is on for some reason.
	if (IsUsingJumper(client) && g_bHardcore[client])
	{
		g_bHardcore[client] = false;
	}
	
	if (g_bUsedReset[client])
	{	
		if(databaseConfigured)
		{
			ReloadPlayerData(client);
		}
		g_bUsedReset[client] = false;
		return;
	}
	if(databaseConfigured){
		LoadPlayerData(client);
	}
	g_bRaceSpec[client] = 0;
}
/*****************************************************************************************************************
												Timers
*****************************************************************************************************************/

public Action:timerTeam(Handle:timer, any:client)
{
	if (client == 0)
	{
		return;
	}
	EraseLocs(client);
	ChangeClientTeam(client, g_iForceTeam);
}
public Action:timerRegen(Handle:timer, any:client)
{
	if (client == 0 || !IsValidEntity(client))
	{
		return;
	}
	new iMaxHealth = TF2_GetPlayerResourceData(client, TFResource_MaxHealth);
	SetEntityHealth(client, iMaxHealth);
}
public Action:timerRespawn(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		TF2_RespawnPlayer(client);
	}
}
public Action:WelcomePlayer(Handle:timer, any:client)
{
	decl String:sHostname[64];
	GetConVarString(g_hHostname, sHostname, sizeof(sHostname));
	if (!IsClientInGame(client))
		return;

	PrintToChat(client, "\x01[\x03JA\x01] Welcome to \x03%s\x01. This server is running \x03%s\x01 by \x03%s\x01.", sHostname, PLUGIN_NAME, PLUGIN_AUTHOR);
	PrintToChat(client, "\x01[\x03JA\x01] %t", "Welcome_2", PLUGIN_NAME, cLightGreen, cDefault, cLightGreen, cDefault);
	PrintToChat(client, "\x01[\x03JA\x01] Type \x03!r_help\x01 for help with racing");
}
/*****************************************************************************************************************
											ConVars Hooks
*****************************************************************************************************************/
public cvarFastBuildChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarInt(FindConVar("tf_fastbuild"), 0);
	}
	else
	{
		SetConVarInt(FindConVar("tf_fastbuild"), 1);
	}
}
public cvarCheapObjectsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarInt(FindConVar("tf_cheapobjects"), 0);
	}
	else
	{
		SetConVarInt(FindConVar("tf_cheapobjects"), 1);
	}
}
public cvarAmmoCheatChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarInt(FindConVar("tf_sentrygun_ammocheat"), 0);
	}
	else
	{
		SetConVarInt(FindConVar("tf_sentrygun_ammocheat"), 1);
	}
}
public cvarWelcomeMsgChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hWelcomeMsg, false);
	else
		SetConVarBool(g_hWelcomeMsg, true);
}
public cvarSentryLevelChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSentryLevel, false);
	else
		SetConVarBool(g_hSentryLevel, true);
}
public cvarSupermanChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSuperman, false);
	else
		SetConVarBool(g_hSuperman, true);
}
public cvarSoundsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSoundBlock, false);
	else
		SetConVarBool(g_hSoundBlock, true);
}