#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

#define PARTICIPATION_VALUE 0 //0 - not participating, 1 - is participating
#define TEAM_VALUE 1 //0 - no team, 1 - team 1, 2 - team 2
#define DEATH_COUNT 2 //number of deaths for this participant
#define ARENA_VALUE 3 //0 - out of arena, 1 - in arena, 2 - in arena and in a battle

#define MIN_VOTES 4 //controls the absolute minimum number of participants
#define INITAL_VOTE_TIME 45 //controls the amount of time the first vote for bchess will be displayed

public Plugin:myinfo =
{
	name = "SF BChess Automation",
	author = "Elmo, the Grand Defiler of Souls",
	description = "BattleChess automation",
	version = "0.17",
	url = "http://steamcommunity.com/groups/2sexy4me"
};

/*
-captain indicator
[FIXED]-majority vote is sent to initial mass spawn instead of only yes votes
-player dead, revive, dead, revive bug
--auto revive based on last pick
[DONE]-KICKing when a battle is in progress
 --if a player is kicked mid battle, give the other player full hp
-null velocity on teleport for battle participants
-viewing angles for participants in the battle?
[DONE]- reset shouldn't reset the confirmation option

[FIXED]- jester never spawned with us
[FIXED]- if you kick a player, but there are no players on your team, the menu closes

----Suggestions----
Niky:
yo, I've found a solution for the kick problem. how about that: 
you save the HP of the 2 players participating in the next battle before it begins. 
if someone is kicked, you reset the life of the player who isn't kicked to the previous
value and the next person sent in gets a revive after he dies but the revive just gives him 
the hp of the person kicked before the battle. in other terms: Player1: kicked; Player2 = HPplayer2beforeBattle;
 Player 3 = HPplayer3; if HPplayer3 = 0 {revive Player 3; HPplayer3 = HPplayer1beforeBattle};



[DONE]Elmo, The Grand Defiler Of Soul @ Roaming : oh I need to re-teleport both participants and maybe freeze them for a short amount of time
[DONE]Elmo, The Grand Defiler Of Soul @ Roaming : wait, I should see a message for narny having been picked

-menu stays after map change

Pedro.eXe @ Roaming : Another thing I just thought of is late joiners
adopter010 @ Private duel : Having the ability to add people would be nice too in case of disconnect/accidental kicks

[DONE]⅙Ƭ = Тауыч (Tau) @ Roaming : TP into one area once people voted Yes to BC  -- Initital mass spawn, call from vote results handler
[DONE]⅙Ƭ = Тауыч (Tau) @ Roaming : So that people can see who they're choosing as caps and pawns
[DONE]Pedro.eXe @ Roaming : When entering the arena you should be healed, since Matt damaged me before and I came into the event with low HP.
[DONE]-figure out what happens when captain sends themself out
[DONE]Matthiasa @ Roaming : might be nice to see the % of votes going to who won

[FIXED]-captain 2 can't decline without bug
[FIXED]Elmo, The Grand Defiler Of Soul @ Roaming : alright, so I need to redisplay menu and add message to send swap\
[FIXED]-redisplay menu when battle starts
[FIXED] - fighting with the console

+Hoody @ Roaming : i think a reporting system is a good idea so we dont get any trolly captains
--------Notes/Bugs----------
-v0.13 test results:
[FIXED]-jester's menu dissapeared on replying no to me picking a player
[FIXED]-client commands restricted message appeared to me when jester clicked it
[FIXED]-wins by default happened for the EndBattle message even though it shouldn't have
[FIXED]-there was no message for returning a player from the arena
[FIXED]-lost menu once a player was returned
[FIXED]-jester was able to send a player in to fight the console (lmao)

-bchess start trigger:
 -start_event_battlechess (trigger_multiple)
++++++++++++++
+To do List: +
++++++++++++++
-Deal with client disconnects
 -make function to count participants and reset if it falls below MIN_VOTES (might need to perform this check in the vote results handler)
[DONE?]-Deal with damage done by outsiders, and friendly fire
-Figure out how to initiate and end battles
 [DONE]--in the send function, check if that team has players in the ring first
  [DONE]--if they do, show this menu: "one of your players is already in the arena, return that player and send in the one you just picked?"
  [DONE]--return player that won a battle to his respective side inside the death event (he will be the attacker)
 [DONE]--battles should end on disconnect or in the death event
[DONE]-On every selection in the client options menu, redisplay the captain menu
[FUCKING DONE :D]-Is there a way to prevent participants from duelling? (remember the glitch on your local where duelling was impossible due to a plugin you wrote...)
[FUCKING DONE :D](it's vs_ready/vs_challenge <-- client command)
[DONE]-Figure out a process for reviving players
-what happens when two people die at the same time in a battle?
[DONE]-give hp and message on active game start
[DONE]-DEATH_COUNT should == 0 for players added to the captain menu
[DONE]-Figure out how the entire game ends and is reset.
-in captain menu, add option to remove player from team in exchange for revive
 --both captains must agree on the kicking of a player from the bchess game
 ---write a RemovePlayerFromGame(client) function

[DONE]-message all participants which team a player was picked for
[DONE]-spawn particpants back on their respective sides
-motd message to captains containing instructions
[DONE]-arena exit point 
[DONE]-add "ask to confirm for captains" option to the config
[DONE]-remove captains from revive
*/

//======================================//
//										//
//			Client Globals				//
//										//
//======================================//
new g_Client_Data[MAXPLAYERS+1][4];
//======================================//
//										//
//			Game Globals				//
//										//
//======================================//
new bool:g_bIsTeamSetupInProgress = false;
new bool:g_bIsCaptainSetupInProgress = false;
new bool:g_bIsGameInProgress = false;
new bool:g_bIsBattleInProgress = false;
new bool:g_bTeamSelectionConfirmation = true;
new g_Captain_1 = 0;
new g_Captain_2 = 0;
new team_1_revives = 0;
new team_2_revives = 0;
//======================================//
//										//
//			Config Globals				//
//										//
//======================================//
	//misc
	new String:g_szFile[PLATFORM_MAX_PATH];
	new String:g_szMapName[255];
	//entities
	new g_StartTrigger = INVALID_ENT_REFERENCE;
	new String:g_StartTrigger_Name[64];
	//settings
	new g_MinYesVotes = 0;
	
	new Float:g_vec_initial_mass_spawn_pos[3];
	new Float:g_vec_arena_exit_pos[3];
	
	new Float:g_vec_Team1_start_pos[3];
	new Float:g_vec_Team1_send_pos[3];
	new Float:g_vec_Team1_return_pos[3];
	
	new Float:g_vec_Team2_start_pos[3];
	new Float:g_vec_Team2_send_pos[3];
	new Float:g_vec_Team2_return_pos[3];
//======================================//
//										//
//		   Main Body Of Plugin			//
//										//
//======================================//
public OnPluginStart()
{
	RegConsoleCmd("captain", CMD_CaptainMenu, "opens up the captain options menu during a battlechess game");
	RegAdminCmd("bchess_reset", CMD_Reset, ADMFLAG_ROOT);
}

public Action:OnClientCommand(client, args)
{
	//block duelling for participants	
	if( IsParticipant(client) )
	{
	
		new String:cl_cmd[16];
		GetCmdArg(0, cl_cmd, sizeof(cl_cmd));
		if( StrEqual(cl_cmd, "vs_challenge", false) )
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:CMD_Reset(client, args)
{
	ResetAllGlobals();
	PrintToChat(client, "bchess reset");
	return Plugin_Handled;
}

public Action:CMD_CaptainMenu(client, args)
{
	if( g_bIsGameInProgress )
	{
		if( IsCaptain_1(client) )
		{
			DisplayCaptainOptionsMenu(g_Captain_1, 1);
		}
		else if( IsCaptain_2(client) )
		{
			DisplayCaptainOptionsMenu(g_Captain_2, 2);
		}
	}
	
	return Plugin_Handled;
}	

public OnMapStart()
{
	//load globals
	GetCurrentMap(g_szMapName, sizeof(g_szMapName));
	LoadSettingsConfig();
	
	//find and store entities
	g_StartTrigger = Entity_FindByName(g_StartTrigger_Name, "trigger_multiple");
	//stop the plugin if there is no start trigger
	if( !IsValidEntity(g_StartTrigger) )
	{
		SetFailState("[BattleChess] Failed to find trigger_multiple (%s).", g_StartTrigger_Name);
	}
	//hook the OnStartTouch output for the trigger, in order to call the vote menu
	HookSingleEntityOutput(g_StartTrigger, "OnStartTouch", Start_Trigger_Callback, false);
	
	//hook player death event
	HookEvent("player_death", Event_Player_Death);
}

public OnClientPutInServer(client)
{
	//hook each client's damage event
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}	  

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{		
	//block damage outside of battles
	if( IsParticipant(victim) && !IsParticipant(attacker) )
	{
		return Plugin_Handled;
	}
	
	if( IsParticipant(victim) && IsParticipant(attacker) )
	{
		if( (g_Client_Data[victim][ARENA_VALUE] != 2) || (g_Client_Data[attacker][ARENA_VALUE] != 2))
		{
			//one of the participants is not in a battle
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	//get attacker
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	//increment death count if the victim and attacker were both in a battle
	if( (g_Client_Data[victim][ARENA_VALUE] == 2) && (g_Client_Data[attacker][ARENA_VALUE] == 2) )
	{
		g_Client_Data[victim][DEATH_COUNT]++;
		EndBattle(false, attacker, victim);
	}
	
	//win condition
	if( victim == g_Captain_1 )
	{
		EndTheGame(2, false);
	}
	else if( victim == g_Captain_2 )
	{
		EndTheGame(1, false);
	}
}

public Start_Trigger_Callback(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if( !IsInDuel(activator) )
		{
			if(!IsVoteInProgress() && !g_bIsCaptainSetupInProgress  && !g_bIsGameInProgress  && !g_bIsTeamSetupInProgress)
			{
				DisplayAskToStartVote(activator);
			}
			else
			{
				PrintToChat(activator, "\x04A vote or game is currently in progress, please wait then try again.");
			}
		}
	}
}

public OnClientDisconnect(client)
{
	if( IsParticipant(client) )
	{
		if( g_bIsCaptainSetupInProgress )
		{
			if( client == g_Captain_1)
			{
				//client was captain 1, during captain setup
				g_Captain_1 = 0;
				ResetClientGlobals(client);
				MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04 Captain 1 has left the game; a re-vote for Captain 1 will occur upon completing the current vote.");
				//count participants, if there are not enough, reset everything
				ResetGameIfLowParticipantCount();
			}
			if( client == g_Captain_2)
			{
				//client was captain 2, during captain setup
				g_Captain_2 = 0;
				ResetClientGlobals(client);
				MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04 Captain 2 has left the game; a re-vote for Captain 2 will occur upon completing the current vote.");
				//count participants, if there are not enough, reset everything
				ResetGameIfLowParticipantCount();
			}
		}
		
		if( g_bIsTeamSetupInProgress )
		{
			if( client == g_Captain_1)
			{
				//client was captain 1, during team setup
				ResetClientGlobals(client);
				//reset captain values, count participants to make sure it is over the min, and if so
				//start the captain voting process again
				g_Captain_1 = 0;
				g_Captain_2 = 0;
				for( new i = 1; i <= MaxClients; i++ )
				{
					g_Client_Data[i][TEAM_VALUE] = 0;
				}
				if( !ResetGameIfLowParticipantCount() )
				{
					//there are enough participants
					MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04 Captain 1 has left the game; captains will be re-selected.");
					DisplayCaptain1Vote();
				}
			}
			if( client == g_Captain_2)
			{
				//client was captain 2, during team setup
				ResetClientGlobals(client);
				//reset captain values, count participants to make sure it is over the min, and if so
				//start the captain voting process again
				g_Captain_1 = 0;
				g_Captain_2 = 0;
				for( new i = 1; i <= MaxClients; i++ )
				{
					g_Client_Data[i][TEAM_VALUE] = 0;
				}
				if( !ResetGameIfLowParticipantCount() )
				{
					//there are enough participants
					MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04 Captain 2 has left the game; captains will be re-selected.");
					DisplayCaptain1Vote();
				}
			}
			
			if( g_Client_Data[client][TEAM_VALUE] == 1 )
			{
				//client was on team 1, during team setup
				ResetClientGlobals(client);
			}
			else if ( g_Client_Data[client][TEAM_VALUE] == 2 )
			{
				//client was on team 2, during team setup
				ResetClientGlobals(client);
			}
		}
		
		if ( g_bIsGameInProgress )
		{
			if( client == g_Captain_1)
			{
				//client was captain 1, during active game
				ResetClientGlobals(client);
				EndTheGame(2, true);
			}
			if( client == g_Captain_2)
			{
				//client was captain 2, during active game
				ResetClientGlobals(client);
				EndTheGame(1, true);
			}
			
			if( g_Client_Data[client][TEAM_VALUE] == 1 )
			{
				//client was on team 1, during active game
				if( g_bIsBattleInProgress && (g_Client_Data[client][ARENA_VALUE] == 2) )
				{
					new other_player;
					for( new i = 1; i <= MaxClients; i++ )
					{
						if( (g_Client_Data[i][ARENA_VALUE] == 2) && (i != client) )
						{
							other_player = i;
							break;
						}
					}
					EndBattle(true, other_player, client);
				}
				ResetClientGlobals(client);
			}
			else if ( g_Client_Data[client][TEAM_VALUE] == 2 )
			{
				//client was on team 2, during active game
				if( g_bIsBattleInProgress && (g_Client_Data[client][ARENA_VALUE] == 2) )
				{
					new other_player;
					for( new i = 1; i <= MaxClients; i++ )
					{
						if( (g_Client_Data[i][ARENA_VALUE] == 2) && (i != client) )
						{
							other_player = i;
							break;
						}
					}
					EndBattle(true, other_player, client);
				}
				ResetClientGlobals(client);
			}
		}
		//just in case I missed something
		ResetClientGlobals(client);		
	}
}

public ParticipantMissedInitialSpawn(client)
{
	if( IsValidClient(client) )
	{
		if( !IsParticipant(client) )
		{
			SDKUnhook(client, SDKHook_SpawnPost, ParticipantMissedInitialSpawn);
		}
		else if( IsParticipant(client) && IsPlayerAlive(client) )
		{
			TeleportEntity(client, g_vec_initial_mass_spawn_pos, NULL_VECTOR, NULL_VECTOR);
			SDKUnhook(client, SDKHook_SpawnPost, ParticipantMissedInitialSpawn);
		}
	}
}

public Team1Respawn(client)
{
	if( IsParticipant(client) )
	{
		TeleportEntity(client, g_vec_Team1_start_pos, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		SDKUnhook(client, SDKHook_SpawnPost, Team1Respawn);
	}
}

public Team2Respawn(client)
{
	if( IsParticipant(client) )
	{
		TeleportEntity(client, g_vec_Team2_start_pos, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		SDKUnhook(client, SDKHook_SpawnPost, Team1Respawn);
	}
}

public OnMapEnd()
{
	ResetAllGlobals();
}
//======================================//
//										//
//			Menu Functions				//
//										//
//======================================//
DisplayAskToStartVote(client)
{
	//create the menu handle
	new Handle:menu = CreateMenu(AskToStartVoteHandler, MENU_ACTIONS_DEFAULT);
	//set the title
	SetMenuTitle(menu, "Would you like to initiate a BattleChess vote?");
	//add menu items (w/unique Ids)
	AddMenuItem(menu, "1", "Yes");
	AddMenuItem(menu, "2", "No");
	//display to client
	DisplayMenu(menu, client, 5);
}

public AskToStartVoteHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//yes
				if(!IsVoteInProgress() && !g_bIsCaptainSetupInProgress && !g_bIsGameInProgress && !g_bIsTeamSetupInProgress)
				{
					//check passed, start the vote
					DisplayInitialVote();
				}
				else
				{
					//check failed
					PrintToChat(param1, "\x04Unable to start vote; another vote or game is in progress.");
				}
			}
			case 2:
			{
				//no
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DisplayInitialVote()
{
	if(!IsVoteInProgress())
	{
		//dynamic array for list of recipients
		new Handle:cl_arr_buff = CreateArray( 1, 0 );
		new numRecipients;
		for( new i = 0; i <= MaxClients; i++ )
		{
			if( IsValidClient(i) && !IsInDuel(i) )
			{
				PushArrayCell(cl_arr_buff, i);
				numRecipients++;
			}
		}
		//translate dynamic array to normal array
		new cl_arr[numRecipients];
		for( new i = 0; i < numRecipients; i++ )
		{
			new x = GetArrayCell(cl_arr_buff, i);
			cl_arr[i] = x;
		}

		//create and push menu
		new Handle:menu = CreateMenu(InitialVoteMenuHandler, MENU_ACTIONS_DEFAULT);
		SetVoteResultCallback(menu, InitialVoteResultsHandler);
		SetMenuTitle(menu, "Would you like to play BattleChess?");
		AddMenuItem(menu, "1", "Yes");
		AddMenuItem(menu, "2", "No");
		SetMenuExitButton(menu, false);
		VoteMenu(menu, cl_arr, numRecipients, INITAL_VOTE_TIME);
		
		//close dynamic array handle
		CloseHandle(cl_arr_buff);
	}
}

public InitialVoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public InitialVoteResultsHandler(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	//get the item index for a 'yes' vote
	new String:vote_item_buffer[2];
	new vote_yes_index;
	for( new i = 0; i < num_items; i++ )
	{
		GetMenuItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], vote_item_buffer, sizeof(vote_item_buffer));
		new x = StringToInt(vote_item_buffer);
		if( x == 1 )
		{
			vote_yes_index = i;
			break;
		}
	}
	
	//get the number of clients that voted yes
	new num_yes_votes = 0;
	for( new i = 0; i < num_clients; i++ )
	{
		if( client_info[i][VOTEINFO_CLIENT_ITEM] == item_info[vote_yes_index][VOTEINFO_ITEM_INDEX] )
		{
			num_yes_votes++;
		}
	}
		
	//check for min number of yes votes
	if( num_yes_votes >= g_MinYesVotes )
	{
		//flag captain setup in progress
		g_bIsCaptainSetupInProgress = true;
		
		//flag the participating clients
		for( new i = 0; i < num_clients; i++ )
		{
			if( client_info[i][VOTEINFO_CLIENT_ITEM] == item_info[vote_yes_index][VOTEINFO_ITEM_INDEX] )
			{
				if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
				{
					//PrintToChatAll("%N voted yes", client_info[i][VOTEINFO_CLIENT_INDEX]);
					g_Client_Data[client_info[i][VOTEINFO_CLIENT_INDEX]][PARTICIPATION_VALUE] = 1;
				}
				
				if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
				{
					if( IsPlayerAlive(client_info[i][VOTEINFO_CLIENT_INDEX]) )
					{
						DispatchKeyValueVector(client_info[i][VOTEINFO_CLIENT_INDEX], "origin", g_vec_initial_mass_spawn_pos);
					}
					else
					{
						SDKHook(client_info[i][VOTEINFO_CLIENT_INDEX], SDKHook_SpawnPost, ParticipantMissedInitialSpawn);
					}
				}
			}
			else if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
			{
				//PrintToChatAll("%N voted no", client_info[i][VOTEINFO_CLIENT_INDEX]);
			}
		}
		// msg participants that the vote passed
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04 Vote successful! Event will begin once captains and teams have been chosen.");
		
		//begin captain selection
		DisplayCaptain1Vote()
	}
	else
	{
		//tell all clients how many players are needed and that there weren't enough to start. Reset everything.
		PrintToChatAll("\x04[\x03BattleChess\x04]\x03: \x04 Vote was unsuccessful; received %i of the required %i minimum votes.", num_yes_votes, g_MinYesVotes);
		ResetAllGlobals();
	}
}

DisplayCaptain1Vote()
{
	//dynamic array for list of participants
	new Handle:cl_arr_buff = CreateArray( 1, 0 );
	new num_participants;
	for( new i = 0; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) && IsParticipant(i) )
		{
			PushArrayCell(cl_arr_buff, i);
			num_participants++;
		}
	}
	new cl_arr[num_participants];
	for( new i = 0; i < num_participants; i++ )
	{
		new x = GetArrayCell(cl_arr_buff, i);
		cl_arr[i] = x;
	}
	
	//create and push menu
	new Handle:menu = CreateMenu(Captain1VoteMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem);
	SetVoteResultCallback(menu, Captain1VoteResultsHandler);
	SetMenuTitle(menu, "Vote for Captain 1:");
	
	decl String:cl_index[4];
	decl String:cl_name[MAX_NAME_LENGTH];
	for( new i = 0; i < num_participants; i++ )
	{
		new y = cl_arr[i];
		
		if( y != g_Captain_2 )
		{
			Format(cl_index, sizeof(cl_index), "%i", y);
			GetClientName(y, cl_name, sizeof(cl_name));
			AddMenuItem(menu, cl_index, cl_name);
		}
	}
	SetMenuExitButton(menu, false);
	VoteMenu(menu, cl_arr, num_participants, 60);
	
	//close dynamic array handle
	CloseHandle(cl_arr_buff);
}

public Captain1VoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_DrawItem)
	{
		//find item that matches client and disable it (so that clients can't vote for themselves)
		new style;
		new String:cl_index_buffer[4];
		new cl_index;
		GetMenuItem(menu, param2, cl_index_buffer, sizeof(cl_index_buffer), style)
		cl_index = StringToInt(cl_index_buffer);
		if( cl_index == param1 && (GetMenuItemCount(menu) > 1) )
		{
			return ITEMDRAW_DISABLED;
		}
		else
		{
			return style;
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	return 0;
}

public Captain1VoteResultsHandler(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	//get client index of 1st choice
	new String:cl_index_buffer_1[4];
	new String:cl_name[MAX_NAME_LENGTH];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], cl_index_buffer_1, sizeof(cl_index_buffer_1), _, cl_name, sizeof(cl_name));
	new cl_index_1 = StringToInt(cl_index_buffer_1);
	
	if( IsValidClient(cl_index_1) )
	{
		SetCaptain_1(cl_index_1);
		
		//check to see if there was a tie
		if( (num_items > 1) && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES]) )
		{
			//get client index of 2nd choice
			new String:cl_index_buffer_2[4];
			GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], cl_index_buffer_2, sizeof(cl_index_buffer_2));
			new cl_index_2 = StringToInt(cl_index_buffer_2);
		
			if( IsValidClient(cl_index_2) )
			{
				//get rank of both clients and determine which is 'higher' (lower value)
				if( BerimbauGetRank(cl_index_1) < BerimbauGetRank(cl_index_2) )
				{
					SetCaptain_1(cl_index_1);
				}
				else
				{
					SetCaptain_1(cl_index_2);
				}
			}
			else
			{
				//second choice is invalid, default to first choice
				SetCaptain_1(cl_index_1);
			}
		}
		//calculate percentage of votes that the captain received
		new Float:win_percentage = FloatDiv( float(item_info[0][VOTEINFO_ITEM_VOTES]), float(num_votes) ) * 100;
		
		//msg the participants telling them which client was chosen as captain 1
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x03%N \x04has been chosen as \x03Captain 1 \x04with %.2fPCT of the votes.", g_Captain_1, win_percentage);
		
		if( g_Captain_2 == 0 )
		{
			//begin captain 2 vote
			DisplayCaptain2Vote();
		}
		else
		{
			//start the team selection process
			BeginTeamSelection();
		}
	}
	else
	{
		//first choice is invalid, restart vote
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x03%s \x04is no longer a valid client, a re-vote will now occur.", cl_name);
		DisplayCaptain1Vote();
	}	
}

DisplayCaptain2Vote()
{
	//dynamic array for list of participants
	new Handle:cl_arr_buff = CreateArray( 1, 0 );
	new num_participants;
	for( new i = 0; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) && IsParticipant(i) )
		{
			PushArrayCell(cl_arr_buff, i);
			num_participants++;
		}
	}
	new cl_arr[num_participants];
	for( new i = 0; i < num_participants; i++ )
	{
		new x = GetArrayCell(cl_arr_buff, i);
		cl_arr[i] = x;
	}
	
	//create and push menu
	new Handle:menu = CreateMenu(Captain2VoteMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem);
	SetVoteResultCallback(menu, Captain2VoteResultsHandler);
	SetMenuTitle(menu, "Vote for Captain 2:");
	
	decl String:cl_index[4];
	decl String:cl_name[MAX_NAME_LENGTH];
	for( new i = 0; i < num_participants; i++ )
	{
		new y = cl_arr[i];
		
		if( y != g_Captain_1 )
		{
			Format(cl_index, sizeof(cl_index), "%i", y);
			GetClientName(y, cl_name, sizeof(cl_name));
			AddMenuItem(menu, cl_index, cl_name);
		}
	}
	SetMenuExitButton(menu, false);
	VoteMenu(menu, cl_arr, num_participants, 60);
}

public Captain2VoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_DrawItem)
	{
		//find item that matches client and disable it (so that clients can't vote for themselves)
		new style;
		new String:cl_index_buffer[4];
		new cl_index;
		GetMenuItem(menu, param2, cl_index_buffer, sizeof(cl_index_buffer), style)
		cl_index = StringToInt(cl_index_buffer);
		if( cl_index == param1 && (GetMenuItemCount(menu) > 1) )
		{
			return ITEMDRAW_DISABLED;
		}
		else
		{
			return style;
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	return 0;
}

public Captain2VoteResultsHandler(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	//get client index of 1st choice
	new String:cl_index_buffer_1[4];
	new String:cl_name[MAX_NAME_LENGTH];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], cl_index_buffer_1, sizeof(cl_index_buffer_1), _, cl_name, sizeof(cl_name));
	new cl_index_1 = StringToInt(cl_index_buffer_1);
	
	if( IsValidClient(cl_index_1) )
	{
		SetCaptain_2(cl_index_1);
		
		//check to see if there was a tie
		if( (num_items > 1) && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES]) )
		{
			//get client index of 2nd choice
			new String:cl_index_buffer_2[4];
			GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], cl_index_buffer_2, sizeof(cl_index_buffer_2));
			new cl_index_2 = StringToInt(cl_index_buffer_2);
			
			if( IsValidClient(cl_index_2) )
			{
				//get rank of both clients and determine which is 'higher' (lower value)
				if( BerimbauGetRank(cl_index_1) < BerimbauGetRank(cl_index_2) )
				{
					SetCaptain_2(cl_index_1);
				}
				else
				{
					SetCaptain_2(cl_index_2);
				}
			}
			else
			{
				//second choice is invalid, default to first choice
				SetCaptain_2(cl_index_1);
			}
		}
		//calculate percentage of votes that the captain received
		new Float:win_percentage = FloatDiv( float(item_info[0][VOTEINFO_ITEM_VOTES]), float(num_votes) ) * 100;
		
		//msg the participants telling them which client was chosen as captain 2
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x03%N \x04has been chosen as \x03Captain 2 \x04with %.2fPCT of the votes.", g_Captain_2, win_percentage);
		
		if( g_Captain_1 == 0 )
		{
			//redisplay captain 1 vote menu
			DisplayCaptain1Vote();
		}
		else
		{
			//start the team selection process
			BeginTeamSelection();
		}
	}
	else
	{
		//first choice is invalid, restart vote
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x03%s \x04is no longer a valid client, a re-vote will now occur.", cl_name);
		DisplayCaptain2Vote();
	}
}

DisplayTeamPickingMenu(client)
{
	//create the menu handle
	new Handle:menu = CreateMenu(TeamPickingMenuHandler, MENU_ACTIONS_DEFAULT);
	
	//set the title
	SetMenuTitle(menu, "Choose a player for your team:");
	
	//add menu items (w/unique Ids)
	AddParticipantsToMenu(menu);
	
	//remove exit button
	SetMenuExitButton(menu, false);

	//display to client
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public TeamPickingMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[4];
		
		//get item/client index
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		
		//convert to int
		new cl_index = StringToInt(sz_indexBuffer);	
		
		
		if( GetMenuItemCount(menu) > 1 )
		{
			//check to make sure cl_index is valid
			if( !IsValidClient(cl_index) )
			{	
				//message saying that the client is invalid
				PrintToChat(param1, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is invalid, please pick again."); 
				//redisplay menu to captain
				DisplayTeamPickingMenu(param1);
			}
			else
			{
				if( g_bTeamSelectionConfirmation )
				{
					//show confirmation menu to other captain
					if( IsCaptain_1(param1) )
					{
						PrintToChat(param1, "\x04[\x03BattleChess\x04]\x03: \x04waiting for Captain 2 to confirm your selection..."); 
						DisplayTeamPickingConfirmationMenu( g_Captain_2, cl_index);
					}
					else if ( IsCaptain_2(param1) )
					{
						PrintToChat(param1, "\x04[\x03BattleChess\x04]\x03: \x04waiting for Captain 1 to confirm your selection..."); 
						DisplayTeamPickingConfirmationMenu( g_Captain_1, cl_index);
					}
				}
				else
				{
					//add the client to the team
					if( IsCaptain_1(param1) )
					{
						//add client to this captain's team
						AddToTeam_1(cl_index);
						//message participants about the selection
						MessageParticipants_Chat(true, "\x04[\x03BattleChess\x04]\x03: %N \x04selected \x03%N \x04 for team 1.", g_Captain_1, cl_index);
						//display selection menu to other captain
						DisplayTeamPickingMenu( g_Captain_2 );
					}
					else if( IsCaptain_2(param1) )
					{
						//add client to this captain's team
						AddToTeam_2(cl_index);
						//message participants about the selection
						MessageParticipants_Chat(true, "\x04[\x03BattleChess\x04]\x03: %N \x04selected \x03%N \x04 for team 2.", g_Captain_2, cl_index);
						//display selection menu to other captain
						DisplayTeamPickingMenu( g_Captain_1 );
					}
				}
			}				
		}
		else
		{
			//last client has been chosen
			//add to team if client is valid
			if( IsValidClient(cl_index) )
			{
				if( IsCaptain_1(param1) )
				{
					//add client to this captain's team
					AddToTeam_1(cl_index);
					//message participants about the selection
					MessageParticipants_Chat(true, "\x04[\x03BattleChess\x04]\x03: %N \x04selected \x03%N \x04 for team 1.", g_Captain_1, cl_index);
				}
				else if( IsCaptain_2(param1) )
				{
					//add client to this captain's team
					AddToTeam_2(cl_index);
					//message participants about the selection
					MessageParticipants_Chat(true, "\x04[\x03BattleChess\x04]\x03: %N \x04selected \x03%N\x04 for team 2.", g_Captain_2, cl_index);
				}
			}
			else
			{
				PrintToChat(param1, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is invalid.");
			}
			//count both teams and issue revives accordingly
			new team_1_count = GetTeamCount_(1);
			new team_2_count = GetTeamCount_(2);
				
			if( team_1_count > team_2_count )
			{
				new amount = (team_1_count - team_2_count);
				AddRevivesToTeam(2, amount);
				//message both teams saying which team got revives
				MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04Team 1 has \x03%i \x04more players than Team 2, therefore Team 2 will get \x03%i \x04revives", amount, amount);
			}
			else if( team_1_count < team_2_count )
			{
				new amount = (team_2_count - team_1_count);
				AddRevivesToTeam(1, amount);
				//message both teams saying which team got revives
				MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04Team 2 has \x03%i \x04more players than Team 1, therefore Team 1 will get \x03%i \x04revives", amount, amount);
			}
			
			BeginActiveGame();
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DisplayTeamPickingConfirmationMenu(captain, cl_index)
{
	decl String:szTitle[128];
	Format(szTitle, sizeof(szTitle), "The other captain selected %N, do you accept?", cl_index);
	
	decl String:szCl_index[4];
	Format(szCl_index, sizeof(szCl_index), "%i", cl_index);
	
	//create the menu handle
	new Handle:menu = CreateMenu(TeamPickingConfirmationMenuHandler, MENU_ACTIONS_DEFAULT);
	
	//set the title
	SetMenuTitle(menu, szTitle);
	
	//add menu items (w/unique Ids)
	AddMenuItem(menu, szCl_index, "Yes");
	AddMenuItem(menu, "no", "No");
	
	//remove exit button
	SetMenuExitButton(menu, false);

	//display to client
	DisplayMenu(menu, captain, MENU_TIME_FOREVER);
}

public TeamPickingConfirmationMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[4];
		
		//get item/client index
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		
		if( StrEqual(sz_indexBuffer, "no", false) )
		{
			//re-display selection menu to captain
			//message them about it
			if( IsCaptain_1(param1) )
			{
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04Captain 1 has declined your selection, please pick again.");
				DisplayTeamPickingMenu( g_Captain_2 );
			}
			else if( IsCaptain_2(param1) )
			{
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04Captain 2 has declined your selection, please pick again.");
				DisplayTeamPickingMenu( g_Captain_1 );
			}
		}
		else
		{
			//convert to int
			new cl_index = StringToInt(sz_indexBuffer);	
			
			//check to make sure cl_index is valid
			if( IsValidClient(cl_index) )
			{
				if( IsCaptain_1(param1) )
				{
					//message other captain about successful pick
					PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04Captain 1 has accepted your selection, and will now pick a player.");
					//add client to other captain's team
					AddToTeam_2(cl_index);
					//message participants about the selection
					MessageParticipants_Chat(true, "\x04[\x03BattleChess\x04]\x03: %N \x04selected \x03%N \x04 for team 2.", g_Captain_2, cl_index);
					//display selection menu to this client
					DisplayTeamPickingMenu( param1 );
				}
				else if( IsCaptain_2(param1) )
				{
					//message other captain about successful pick
					PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04Captain 2 has accepted your selection, and will now pick a player.");
					//add client to other captain's team
					AddToTeam_1(cl_index);
					//message participants about the selection
					MessageParticipants_Chat(true, "\x04[\x03BattleChess\x04]\x03: %N \x04selected \x03%N \x04 for team 1.", g_Captain_1, cl_index);
					//display selection menu to this client
					DisplayTeamPickingMenu( param1 );
				}
			}
			else
			{
				if( IsCaptain_1(param1) )
				{
					PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04the client you chose is no longer valid, please pick again.");
					DisplayTeamPickingMenu( g_Captain_2 );
				}
				else if( IsCaptain_2(param1) )
				{
					PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04the client you chose is no longer valid, please pick again.");
					DisplayTeamPickingMenu( g_Captain_2 );
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock AddParticipantsToMenu(Handle:menu)
{
	new String:cl_index[4];
	new String:cl_name[MAX_NAME_LENGTH];
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) && IsParticipant(i) && !IsCaptain_1(i) 
			&& !IsCaptain_2(i) && (g_Client_Data[i][TEAM_VALUE] == 0) )
		{
			Format(cl_index, sizeof(cl_index), "%i", i);
			GetClientName(i, cl_name, sizeof(cl_name));
			AddMenuItem(menu, cl_index, cl_name);
		}
	}
}

DisplayCaptainOptionsMenu(captain, team)
{
	//create the menu handle
	new Handle:menu = CreateMenu(CaptainOptionsMenuHandler, MENU_ACTIONS_DEFAULT);
		
	//set the title
	SetMenuTitle(menu, "Captain Menu:");
	
	//add menu items (w/unique Ids)
	AddValidTeammatesToMenu(menu, team);
	AddMenuItem(menu, "-1", "Refresh HP display");
	//if the team has revives, add the revive option
	if( captain == g_Captain_1 )
	{
		if( team_1_revives > 0 )
		{
			AddMenuItem(menu, "-2", "Revive a teammate");
		}
	}
	else if( captain == g_Captain_2 )
	{
		if( team_2_revives > 0 )
		{
			AddMenuItem(menu, "-2", "Revive a teammate");
		}
	}
	AddMenuItem(menu, "-3", "Kick player from team");
	
	//display to client
	DisplayMenu(menu, captain, MENU_TIME_FOREVER);
}

public CaptainOptionsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[4];
		
		//get item/client index
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		
		if( StrEqual(sz_indexBuffer, "-1", false) )
		{
			//re-display options menu to captain
			if( IsCaptain_1(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
		else if( StrEqual(sz_indexBuffer, "-2", false) )
		{
			//display the revive menu
			if( IsCaptain_1(param1) )
			{
				DisplayReviveMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				DisplayReviveMenu(g_Captain_2, 2);
			}
		}
		else if( StrEqual(sz_indexBuffer, "-3", false) )
		{
			//display the kick menu
			if( IsCaptain_1(param1) )
			{
				DisplayKickMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				DisplayKickMenu(g_Captain_2, 2);
			}
		}
		else if( !g_bIsBattleInProgress )
		{
			//convert to int
			new cl_index = StringToInt(sz_indexBuffer);	
		
			//check to make sure cl_index is valid
			if( IsValidClient(cl_index) )
			{
				if( IsCaptain_1(param1) )
				{
					DisplayCaptainClientOptions(g_Captain_1, cl_index);
				}
				else if( IsCaptain_2(param1) )
				{
					DisplayCaptainClientOptions(g_Captain_2, cl_index);
				}
			}
			else
			{
				//client is invalid
				if( IsCaptain_1(param1) )
				{
					PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is no longer valid.");
					DisplayCaptainOptionsMenu(g_Captain_1, 1);
				}
				else if( IsCaptain_2(param1) )
				{
					PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is no longer valid.");
					DisplayCaptainOptionsMenu(g_Captain_2, 2);
				}
			}
		}
		else
		{
			//battle is in progress
			if( IsCaptain_1(param1) )
			{
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04a battle is currently in progress, client options are restricted.");
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04a battle is currently in progress, client options are restricted.");
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock AddValidTeammatesToMenu(Handle:menu, team)
{
	new String:cl_index[4];
	new String:cl_name[MAX_NAME_LENGTH];
	new String:display[MAX_NAME_LENGTH+8]
	new cl_hp;
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) && IsParticipant(i) && (g_Client_Data[i][TEAM_VALUE] == team)
			&& (g_Client_Data[i][DEATH_COUNT] == 0) )
		{
			Format(cl_index, sizeof(cl_index), "%i", i);
			GetClientName(i, cl_name, sizeof(cl_name));
			cl_hp = GetClientHealth(i);
			Format(display, sizeof(display), "%s[%i]", cl_name, cl_hp);
			AddMenuItem(menu, cl_index, display);
		}
	}
}

DisplayCaptainClientOptions(captain, client)
{
	//create the menu handle
	new Handle:menu = CreateMenu(CaptainClientOptionsMenuHandler, MENU_ACTIONS_DEFAULT);
	
	//set the title
	new String:cl_name[MAX_NAME_LENGTH];
	new String:szTitle[MAX_NAME_LENGTH+15];
	GetClientName(client, cl_name, sizeof(cl_name));
	Format(szTitle, sizeof(szTitle), "Options for %s:", cl_name);
	SetMenuTitle(menu, szTitle);
	
	//add menu item (w/unique Id)
	new String:cl_index[8];
	Format(cl_index, sizeof(cl_index), "%i_1", client);
	AddMenuItem(menu, cl_index, "Send out");
	Format(cl_index, sizeof(cl_index), "%i_2", client);
	AddMenuItem(menu, cl_index, "Return");
	
	//set back button
	SetMenuExitBackButton(menu, true);
	
	//display to client
	DisplayMenu(menu, captain, MENU_TIME_FOREVER);
}

public CaptainClientOptionsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[8];
		decl String:sz_cl_index[8];
		
		//get item/client index, and figure out which item was selected
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		new test = SplitString(sz_indexBuffer, "_1", sz_cl_index, sizeof(sz_cl_index));
		new item = 1;
		if( test == -1 )
		{
			test = SplitString(sz_indexBuffer, "_2", sz_cl_index, sizeof(sz_cl_index));
			item = 2;
		}
		
		//convert to int
		new cl_index = StringToInt(sz_cl_index);	
			
		//check to make sure cl_index is valid
		if( IsValidClient(cl_index) && (g_Client_Data[cl_index][DEATH_COUNT] == 0) && (g_Client_Data[cl_index][TEAM_VALUE] != 0))
		{
			if( item == 1 )
			{
				//send out player
				if( IsCaptain_1(param1) )
				{
					if( !g_bIsBattleInProgress )
					{
						//change arena value to 1 if there is no other player in the arena, otherwise
						//change to 2 and g_bIsBattleInProgress = true (basically start the battle)
						if( CountNumParticipants_In_Arena(false, 0) > 1 )
						{
							//do nothing, this shouldn't fire: test for firing
							//PrintToChatAll("\x03[TEST]: this condition should not occur");
						}
						else if( CountNumParticipants_In_Arena(true, cl_index) == 1 )
						{
							//1 participant is waiting in the arena, check to make sure they're not from captain 1's team
							for( new i = 1; i <= MaxClients; i ++ )
							{
								if( (g_Client_Data[i][ARENA_VALUE] == 1) && (g_Client_Data[i][TEAM_VALUE] == 1) )
								{
									//swap out the client in the arena, for this client
									g_Client_Data[i][ARENA_VALUE] = 0;
									TeleportEntity(i, g_vec_Team1_return_pos, NULL_VECTOR, NULL_VECTOR);
									
									g_Client_Data[cl_index][ARENA_VALUE] = 1;
									TeleportEntity(cl_index, g_vec_Team1_send_pos, NULL_VECTOR, NULL_VECTOR);
									DisplayCaptainOptionsMenu(g_Captain_1, 1);
									break;
								}
							}
							
							new other_player = GetSingleArenaPlayer();
							
							if( g_Client_Data[other_player][TEAM_VALUE] == 2 )
							{
								//set proper arena_value for both this player, and the one waiting
								g_Client_Data[cl_index][ARENA_VALUE] = 2;
								g_Client_Data[other_player][ARENA_VALUE] = 2;
								
								//teleport client to team 1 arena location
								TeleportEntity(cl_index, g_vec_Team1_send_pos, NULL_VECTOR, NULL_VECTOR);
								//start the battle
								StartBattle(cl_index, other_player);
								//redisplay menu to captain
								if( g_Captain_1 != cl_index )
								{
									DisplayCaptainOptionsMenu(g_Captain_1, 1);
								}
							}
						}
						else
						{
							//there are no participants in the arena, send this client out
							g_Client_Data[cl_index][ARENA_VALUE] = 1;
							//teleport client to team 1 ring location
							TeleportEntity(cl_index, g_vec_Team1_send_pos, NULL_VECTOR, NULL_VECTOR);
							//re-display captain menu
							DisplayCaptainOptionsMenu(g_Captain_1, 1);
						}
					}
					else
					{
						//a battle is in progress
						PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04please wait until the battle is finished to send commands.");
						//re-display captain menu
						DisplayCaptainOptionsMenu(g_Captain_1, 1);
					}
				}
				else if( IsCaptain_2(param1) )
				{
					if( !g_bIsBattleInProgress )
					{
						//change arena value to 1 if there is no other player in the arena, otherwise
						//change to 2 and g_bIsBattleInProgress = true (basically start the battle)
						if( CountNumParticipants_In_Arena(false, 0) > 1 )
						{
							//do nothing, this shouldn't fire: test for firing
							//PrintToChatAll("[TEST]: this condition should not occur");
						}
						else if( CountNumParticipants_In_Arena(true, cl_index) == 1 )
						{
							//1 participant is waiting in the arena, check to make sure they're not from captain 2's team
							for( new i = 1; i <= MaxClients; i ++ )
							{
								if( (g_Client_Data[i][ARENA_VALUE] == 1) && (g_Client_Data[i][TEAM_VALUE] == 2) )
								{
									//swap out the client in the arena, for this client
									g_Client_Data[i][ARENA_VALUE] = 0;
									TeleportEntity(i, g_vec_Team2_return_pos, NULL_VECTOR, NULL_VECTOR);
									
									g_Client_Data[cl_index][ARENA_VALUE] = 1;
									TeleportEntity(cl_index, g_vec_Team2_send_pos, NULL_VECTOR, NULL_VECTOR);
									DisplayCaptainOptionsMenu(g_Captain_2, 2);
									break;
								}
							}
							
							new other_player = GetSingleArenaPlayer();
							
							if( g_Client_Data[other_player][TEAM_VALUE] == 1 )
							{
								//set proper arena_value for both this player, and the one waiting
								g_Client_Data[cl_index][ARENA_VALUE] = 2;
								g_Client_Data[other_player][ARENA_VALUE] = 2;
								
								//teleport client to team 2 arena location
								TeleportEntity(cl_index, g_vec_Team2_send_pos, NULL_VECTOR, NULL_VECTOR);
								//start the battle
								StartBattle(cl_index, other_player);
								//redisplay menu to captain
								if( g_Captain_2 != cl_index )
								{
									DisplayCaptainOptionsMenu(g_Captain_2, 2);
								}
							}
						}
						else
						{
							//there are no participants in the arena, send this client out
							g_Client_Data[cl_index][ARENA_VALUE] = 1;
							//teleport client to team 1 ring location
							TeleportEntity(cl_index, g_vec_Team2_send_pos, NULL_VECTOR, NULL_VECTOR);
							//re-display captain menu
							DisplayCaptainOptionsMenu(g_Captain_2, 2);
						}
					}
					else
					{
						//a battle is in progress
						PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04please wait until the battle is finished to send commands.");
						//re-display captain menu
						DisplayCaptainOptionsMenu(g_Captain_2, 2);
					}
				}
			}
			else if( item == 2 )
			{
				//return player
				if( IsCaptain_1(param1) )
				{
					if( !g_bIsBattleInProgress )
					{
						//change arena value to 0
						g_Client_Data[cl_index][ARENA_VALUE] = 0;
						//return to team 1 side
						TeleportEntity(cl_index, g_vec_Team1_return_pos, NULL_VECTOR, NULL_VECTOR);
						//message captain
						PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04%N has been returned from the arena.", cl_index);
						//redisplay menu
						DisplayCaptainOptionsMenu(g_Captain_1, 1);
					}
					else
					{
						//a battle is in progress
						PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04please wait until the battle is finished to send commands.");
						//re-display captain menu
						DisplayCaptainOptionsMenu(g_Captain_1, 1);
					}
				}
				else if( IsCaptain_2(param1) )
				{
					if( !g_bIsBattleInProgress )
					{
						//change arena value to 0
						g_Client_Data[cl_index][ARENA_VALUE] = 0;
						//return to team 1 side
						TeleportEntity(cl_index, g_vec_Team2_return_pos, NULL_VECTOR, NULL_VECTOR);
						//message captain
						PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04%N has been returned from the arena.", cl_index);
						//redisplay menu
						DisplayCaptainOptionsMenu(g_Captain_2, 2);
					}
					else
					{
						//a battle is in progress
						PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04please wait until the battle is finished to send commands.");
						//re-display captain menu
						DisplayCaptainOptionsMenu(g_Captain_2, 2);
					}
				}
			}
		}
		else
		{
			//client is invalid
			if( IsCaptain_1(param1) )
			{
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04this client is no longer valid.");
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04this client is no longer valid.");
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		//if the client selects the back button, display the captain options menu to them
		if(param2 == MenuCancel_ExitBack)
		{
			if( IsCaptain_1(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if (IsCaptain_2(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DisplayReviveMenu(captain, team)
{
	if( GetTeamCount_(team) > 1 )
	{
		//create the menu handle
		new Handle:menu = CreateMenu(ReviveMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem);
	
		//set the title
		SetMenuTitle(menu, "Select a teammate to revive:");
	
		//add menu item (w/unique Id)
		AddAllTeammatesToMenu(menu, team);
	
		//set back button
		SetMenuExitBackButton(menu, true);
	
		//display to client
		DisplayMenu(menu, captain, MENU_TIME_FOREVER);
	}
	else
	{
		PrintToChat(captain, "\x04[\x03BattleChess\x04]\x03: \x04You are the only player on your team.");
		DisplayCaptainOptionsMenu(captain, team);
	}
}

stock AddAllTeammatesToMenu(Handle:menu, team)
{
	new String:cl_index[4];
	new String:cl_name[MAX_NAME_LENGTH];
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) && IsParticipant(i) && (g_Client_Data[i][TEAM_VALUE] == team) && (i != g_Captain_1)
			&& (i != g_Captain_2) )
		{
			Format(cl_index, sizeof(cl_index), "%i", i);
			GetClientName(i, cl_name, sizeof(cl_name));
			AddMenuItem(menu, cl_index, cl_name);
		}
	}
}

public ReviveMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if( action == MenuAction_DrawItem )
	{
		//find items that match living clients and disable them
		new style;
		new String:cl_index_buffer[4];
		new cl_index;
		GetMenuItem(menu, param2, cl_index_buffer, sizeof(cl_index_buffer), style)
		cl_index = StringToInt(cl_index_buffer);
		if( g_Client_Data[cl_index][DEATH_COUNT] == 0 )
		{
			return ITEMDRAW_DISABLED;
		}
		else
		{
			return style;
		}
	}
	else if(action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[4];
		
		//get item/client index
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		
		//convert to int
		new cl_index = StringToInt(sz_indexBuffer);	
		
		//check to make sure cl_index is valid
		if( IsValidClient(cl_index) )
		{
			if( IsCaptain_1(param1) )
			{
				//reset client death count
				g_Client_Data[cl_index][DEATH_COUNT] = 0;
				//remove a revive from the team
				team_1_revives--;
				//message participants about the revive
				MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04has revived \x03%N\x04.", g_Captain_1, cl_index);
				//redisplay client menu
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				//reset client death count
				g_Client_Data[cl_index][DEATH_COUNT] = 0;
				//remove a revive from the team
				team_2_revives--;
				//message participants about the revive
				MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04has revived \x03%N\x04.", g_Captain_2, cl_index);
				//redisplay client menu
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
		else
		{
			//client is invalid
			if( IsCaptain_1(param1) )
			{
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is no longer valid.");
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is no longer valid.");
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		//if the client selects the back button, display the captain options menu to them
		if(param2 == MenuCancel_ExitBack)
		{
			if( IsCaptain_1(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if (IsCaptain_2(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	return 0;
}

DisplayKickMenu(captain, team)
{
	if( GetTeamCount_(team) > 1 )
	{
		//create the menu handle
		new Handle:menu = CreateMenu(KickMenuHandler, MENU_ACTIONS_DEFAULT);
	
		//set the title
		SetMenuTitle(menu, "Select a player to kick:");
	
		//add menu item (w/unique Id)
		AddLivingTeammatesToMenu(menu, team);
	
		//set back button
		SetMenuExitBackButton(menu, true);
	
		//display to client
		DisplayMenu(menu, captain, MENU_TIME_FOREVER);
	}
	else
	{
		PrintToChat(captain, "\x04[\x03BattleChess\x04]\x03: \x04You are the only player on your team.");
		DisplayCaptainOptionsMenu(captain, team);
	}
}

stock AddLivingTeammatesToMenu(Handle:menu, team)
{
	new String:cl_index[4];
	new String:cl_name[MAX_NAME_LENGTH];
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) && IsParticipant(i) && (g_Client_Data[i][TEAM_VALUE] == team) && (i != g_Captain_1)
			&& (i != g_Captain_2) && (g_Client_Data[i][DEATH_COUNT] == 0) )
		{
			Format(cl_index, sizeof(cl_index), "%i", i);
			GetClientName(i, cl_name, sizeof(cl_name));
			AddMenuItem(menu, cl_index, cl_name);
		}
	}
}


public KickMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[4];
		
		//get item/client index
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		
		//convert to int
		new cl_index = StringToInt(sz_indexBuffer);	
		
		//check to make sure cl_index is valid
		if( IsValidClient(cl_index) )
		{
			if( IsCaptain_1(param1) )
			{
				//message this captain
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04waiting for the other captain's response.");
				//display confirmation to captain 2
				DisplayKickMenuConfirmation(g_Captain_2, cl_index);
				//redisplay client menu
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				//message this captain
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04waiting for the other captain's response.");
				//display confirmation to captain 1
				DisplayKickMenuConfirmation(g_Captain_1, cl_index);
				//redisplay client menu
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
		else
		{
			//client is invalid
			if( IsCaptain_1(param1) )
			{
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is no longer valid.");
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04the client you've chosen is no longer valid.");
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		//if the client selects the back button, display the captain options menu to them
		if(param2 == MenuCancel_ExitBack)
		{
			if( IsCaptain_1(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if (IsCaptain_2(param1) )
			{
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DisplayKickMenuConfirmation(captain, client)
{
	decl String:szTitle[128];
	Format(szTitle, sizeof(szTitle), "The other captain wants to kick %N, do you accept?", client);
	
	decl String:szCl_index[4];
	Format(szCl_index, sizeof(szCl_index), "%i", client);
	
	//create the menu handle
	new Handle:menu = CreateMenu(KickMenuConfirmationHandler, MENU_ACTIONS_DEFAULT);
	
	//set the title
	SetMenuTitle(menu, szTitle);
	
	//add menu items (w/unique Ids)
	AddMenuItem(menu, szCl_index, "Yes");
	AddMenuItem(menu, "no", "No");
	
	//remove exit button
	SetMenuExitButton(menu, false);

	//display to client
	DisplayMenu(menu, captain, MENU_TIME_FOREVER);
}

public KickMenuConfirmationHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_indexBuffer[4];
		
		//get item/client index
		GetMenuItem(menu, param2, sz_indexBuffer, sizeof(sz_indexBuffer));
		
		if( StrEqual(sz_indexBuffer, "no", false) )
		{
			//re-display menu to captain
			//message other captain about failure to kick
			if( IsCaptain_1(param1) )
			{
				PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04Captain 1 has declined your kick proposal.");
				DisplayCaptainOptionsMenu(g_Captain_1, 1);
			}
			else if( IsCaptain_2(param1) )
			{
				PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04Captain 2 has declined your kick proposal.");
				DisplayCaptainOptionsMenu(g_Captain_2, 2);
			}
		}
		else
		{
			//convert to int
			new cl_index = StringToInt(sz_indexBuffer);	
			
			//check to make sure cl_index is valid
			if( IsValidClient(cl_index) )
			{
				if( IsCaptain_1(param1) )
				{
					//message participants about the kick
					MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04has been kicked from the arena.", cl_index);
					//end the battle if the client is in a battle
					//find the other player in the battle first
					if( g_bIsBattleInProgress && (g_Client_Data[cl_index][ARENA_VALUE] == 2) )
					{
						new other_player;
						for( new i = 1; i <= MaxClients; i++ )
						{
							if( (g_Client_Data[i][ARENA_VALUE] == 2) && (i != cl_index) )
							{
								other_player = i;
								break;
							}
						}
						EndBattle(true, other_player, cl_index);
					}
					//kick player
					RemovePlayerFromGame(cl_index);
					DispatchKeyValueVector(cl_index, "origin", g_vec_arena_exit_pos);
					//give revives to team if necessary
					IssueRevives();
					//display captain menu to this client
					DisplayCaptainOptionsMenu(g_Captain_1, 1);
				}
				else if( IsCaptain_2(param1) )
				{
					//message participants about the kick
					MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04has been kicked from the arena.", cl_index);
					//end the battle if the client is in a battle
					//find the other player in the battle first
					if( g_bIsBattleInProgress && (g_Client_Data[cl_index][ARENA_VALUE] == 2) )
					{
						new other_player;
						for( new i = 1; i <= MaxClients; i++ )
						{
							if( (g_Client_Data[i][ARENA_VALUE] == 2) && (i != cl_index) )
							{
								other_player = i;
								break;
							}
						}
						EndBattle(true, other_player, cl_index);
					}
					//kick player
					RemovePlayerFromGame(cl_index);
					DispatchKeyValueVector(cl_index, "origin", g_vec_arena_exit_pos);
					//give revives to team if necessary
					IssueRevives();
					//display captain menu to this client
					DisplayCaptainOptionsMenu(g_Captain_2, 2);
				}
			}
			else
			{
				//client is invalid
				if( IsCaptain_1(param1) )
				{
					//display captain menu to this client
					DisplayCaptainOptionsMenu(g_Captain_1, 1);
				}
				else if( IsCaptain_2(param1) )
				{
					//display captain menu to this client
					DisplayCaptainOptionsMenu(g_Captain_2, 2);
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}
//======================================//
//										//
//			Config Functions			//
//										//
//======================================//
stock LoadSettingsConfig()
{
	BuildPath(Path_SM, g_szFile, PLATFORM_MAX_PATH, "configs/sf_bchess_settings.ini"); //read file path into var
	
	//read config and store globals
	//declare vars 
	decl String:SectionName[32];
	
	//load keyvalues
	new Handle:kv = CreateKeyValues("SF_BChess_Settings")
	FileToKeyValues(kv, g_szFile)
	KvGotoFirstSubKey(kv);
	//loop through keyvalues and store info
	do
	{		
		KvGetSectionName(kv, SectionName, sizeof(SectionName));
		//get global settings, and settings from the correct map section in the config
		if( StrEqual(SectionName, "settings", false) )
		{
			g_MinYesVotes = KvGetNum(kv, "minimum number of participants", MIN_VOTES);
			//force min of MIN_VOTES # of participants
			if(g_MinYesVotes < MIN_VOTES)
			{
				g_MinYesVotes = MIN_VOTES;
			}
			new x = KvGetNum(kv, "does team selection require confirmation", 1);
			if( x == 1 )
			{
				g_bTeamSelectionConfirmation = true;
			}
			else
			{
				g_bTeamSelectionConfirmation = false;
			}
		}
		else if( StrEqual(SectionName, g_szMapName, false) )
		{
			KvGetString(kv, "start trigger name", g_StartTrigger_Name, sizeof(g_StartTrigger_Name));
			KvGetVector(kv, "initial mass spawn location", g_vec_initial_mass_spawn_pos);
			KvGetVector(kv, "arena exit location", g_vec_arena_exit_pos);
			
			KvGetVector(kv, "team 1 initial teleport location", g_vec_Team1_start_pos);
			KvGetVector(kv, "team 1 player send location", g_vec_Team1_send_pos);
			KvGetVector(kv, "team 1 player return location", g_vec_Team1_return_pos);
			
			KvGetVector(kv, "team 2 initial teleport location", g_vec_Team2_start_pos);
			KvGetVector(kv, "team 2 player send location", g_vec_Team2_send_pos);
			KvGetVector(kv, "team 2 player return location", g_vec_Team2_return_pos);
		}
	} while (KvGotoNextKey(kv));
	
	//clean up
	KvRewind(kv);
	CloseHandle(kv);
}
//======================================//
//										//
//			Game  Functions				//
//										//
//======================================//
stock ResetClientGlobals( client )
{
	g_Client_Data[client][PARTICIPATION_VALUE] = 0;
	g_Client_Data[client][TEAM_VALUE] = 0;
	g_Client_Data[client][DEATH_COUNT] = 0;
	g_Client_Data[client][ARENA_VALUE] = 0;
}

stock ResetAllGlobals()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		ResetClientGlobals(i);
	}
	
	g_Captain_1 = 0;
	g_Captain_2 = 0;
	g_bIsCaptainSetupInProgress = false;
	g_bIsTeamSetupInProgress = false;
	g_bIsGameInProgress = false;
	g_bIsBattleInProgress = false;
	team_1_revives = 0;
	team_2_revives = 0;
}

stock BeginTeamSelection()
{
	g_bIsCaptainSetupInProgress = false;
	g_bIsTeamSetupInProgress = true;
	
	MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04captains will now begin picking teammates...");
	
	new x = GetRandomInt(0, 1);
	if( x == 0 )
	{
		//display selection menu to captain 1
		DisplayTeamPickingMenu(g_Captain_1);
	}
	else
	{
		//display selection menu to captain 2
		DisplayTeamPickingMenu(g_Captain_2);
	}
}

stock BeginActiveGame()
{
	g_bIsTeamSetupInProgress = false;
	g_bIsGameInProgress = true;
	
	MessageParticipants_Hint("The game will start once both captains have sent out a player.");
	
	//heal all the participants
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsParticipant(i) && IsValidClient(i) )
		{
			SetEntityHealth(i, 100);
		}
	}
	MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04all participants have been healed.");
	
	//hook every player's spawn event, in order to tele them back to their respective sides after death
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsParticipant(i) && IsValidClient(i) )
		{
			if( g_Client_Data[i][TEAM_VALUE] == 1 )
			{
				SDKHook(i, SDKHook_SpawnPost, Team1Respawn);
			}
			else if( g_Client_Data[i][TEAM_VALUE] == 2 )
			{
				SDKHook(i, SDKHook_SpawnPost, Team2Respawn);
			}
		}
	}
	
	//teleport everyone to their respective sides
	TeleportTeamToLocation(1, g_vec_Team1_start_pos);
	TeleportTeamToLocation(2, g_vec_Team2_start_pos);
	//show menus to captains
	DisplayCaptainOptionsMenu(g_Captain_1, 1);
	DisplayCaptainOptionsMenu(g_Captain_2, 2);
	//tell captains how to open menus
	PrintToChat(g_Captain_1, "\x04[\x03BattleChess\x04]\x03: \x04this menu can be accessed at any time via the /captain chat trigger.");
	PrintToChat(g_Captain_2, "\x04[\x03BattleChess\x04]\x03: \x04this menu can be accessed at any time via the /captain chat trigger.");
}

stock StartBattle(p_1, p_2)
{
	//let other functions know that a battle is in progress
	g_bIsBattleInProgress = true;	
	//message all participants that the battle is starting
	MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04and \x03%N \x04are now battling in the arena.", p_1, p_2);
	
	if( g_Client_Data[p_1][TEAM_VALUE] == 1 )
	{
		//p_1 is on team 1, p_2 is on team 2
		TeleportEntity(p_1, g_vec_Team1_send_pos, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(p_2, g_vec_Team2_send_pos, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		//p_1 is on team 2, p_2 is on team 1
		TeleportEntity(p_1, g_vec_Team2_send_pos, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(p_2, g_vec_Team1_send_pos, NULL_VECTOR, NULL_VECTOR);
	}
	
	SetEntPropFloat(p_1, Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(p_2, Prop_Send, "m_flLaggedMovementValue", 0.0);
	
	new Handle:datapack;
	CreateDataTimer(0.8, UnFreezeBattleParticipants, datapack, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(datapack, p_1);
	WritePackCell(datapack, p_2);
	
}

public Action:UnFreezeBattleParticipants(Handle:timer, Handle:pack)
{
	decl p_1, p_2;
	ResetPack(pack);
	p_1 = ReadPackCell(pack);
	p_2 = ReadPackCell(pack);
	
	SetEntPropFloat(p_1, Prop_Send, "m_flLaggedMovementValue", 1.0);
	SetEntPropFloat(p_2, Prop_Send, "m_flLaggedMovementValue", 1.0);
}

stock EndBattle(bool:prematurely, winner, loser)
{
	//let other functions know that a battle is in no longer in progress
	g_bIsBattleInProgress = false;
	//reset loser arena value
	g_Client_Data[loser][ARENA_VALUE] = 0;
	//check for premature end
	if( prematurely )
	{
		//message all particpants about who won by default
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04wins by default.", winner);	
	}
	else
	{
		//message all particpants about who won
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: %N \x04has defeated \x03%N \x04in the arena.", winner, loser);
	}
	//teleport winner back to his side
	g_Client_Data[winner][ARENA_VALUE] = 0;
	TeleportPlayerBackToTeamReturn(winner);
}

stock EndTheGame(WinningTeam, bool:PrematureEnd)
{
	if( !PrematureEnd )
	{
		if( WinningTeam == 1 )
		{
			MessageParticipants_Hint("%N's team wins!", g_Captain_1);
		}
		else if( WinningTeam == 2 )
		{
			MessageParticipants_Hint("%N's team wins!", g_Captain_2);
		}
	}
	else
	{
		if( WinningTeam == 1 )
		{
			MessageParticipants_Hint("Team 1 wins by default.");
		}
		else if( WinningTeam == 2 )
		{
			MessageParticipants_Hint("Team 2 wins by default.");
		}
	}
	TeleportTeamToLocation(1, g_vec_arena_exit_pos);
	TeleportTeamToLocation(2, g_vec_arena_exit_pos);
	ResetAllGlobals();
}
stock MessageParticipants_Chat(bool:FilterOutCaptains,const String:message[], any:...)
{
	decl String:buffer[254];
	VFormat(buffer, sizeof(buffer), message, 3);
	ReplaceString(buffer, sizeof(buffer), "PCT", "%%", true);
	
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_Client_Data[i][PARTICIPATION_VALUE] == 1 )
		{
			if( FilterOutCaptains )
			{
				if( (i != g_Captain_1) && (i != g_Captain_2) )
				{
					PrintToChat(i, buffer);
				}
			}
			else
			{
				PrintToChat(i, buffer);
			}
		}
	}
}

stock MessageParticipants_Hint(const String:message[], any:...)
{
	decl String:buffer[254];
	VFormat(buffer, sizeof(buffer), message, 2);

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_Client_Data[i][PARTICIPATION_VALUE] == 1 )
		{
			PrintHintText(i, buffer);
		}
	}
}

stock bool:IsParticipant(client)
{
	if( g_Client_Data[client][PARTICIPATION_VALUE] == 1 )
	{
		return true;
	}
	return false;
}

stock bool:IsCaptain_1(client)
{
	if( g_Captain_1 == client )
	{
		return true;
	}
	return false;
}

stock bool:IsCaptain_2(client)
{
	if( g_Captain_2 == client )
	{
		return true;
	}
	return false;
}

stock SetCaptain_1(client)
{
	g_Captain_1 = client;
	g_Client_Data[client][TEAM_VALUE] = 1;
}

stock SetCaptain_2(client)
{
	g_Captain_2 = client;
	g_Client_Data[client][TEAM_VALUE] = 2;
}

stock AddToTeam_1(client)
{
	g_Client_Data[client][TEAM_VALUE] = 1;
}

stock AddToTeam_2(client)
{
	g_Client_Data[client][TEAM_VALUE] = 2;
}

stock GetTeamCount_(team)
{
	new teamcount = 0;
	
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_Client_Data[i][TEAM_VALUE] == team )
		{
			teamcount++;
		}
	}
	
	return teamcount;
}

stock AddRevivesToTeam(team, amount)
{
	if( team == 1 )
	{
		team_1_revives += amount;
	}
	else if( team == 2 )
	{
		team_2_revives += amount;
	}
}

stock TeleportTeamToLocation(team, Float:vec_pos[3])
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_Client_Data[i][TEAM_VALUE] == team )
		{
			if( IsValidClient(i) )
			{
				TeleportEntity(i, vec_pos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

stock TeleportPlayerBackToTeamReturn(client)
{
	if( g_Client_Data[client][TEAM_VALUE] == 1 )
	{
		TeleportEntity(client, g_vec_Team1_return_pos, NULL_VECTOR, NULL_VECTOR);
	}
	else if( g_Client_Data[client][TEAM_VALUE] == 2 )
	{
		TeleportEntity(client, g_vec_Team2_return_pos, NULL_VECTOR, NULL_VECTOR);
	}
}

stock CountNumParticipants_In_Arena(bool:filterout, client)
{
	new count;
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( (g_Client_Data[i][ARENA_VALUE] == 1) || ( g_Client_Data[i][ARENA_VALUE] == 2 ) )
		{
			if(filterout)
			{
				if( i != client )
				{
					count++;
				}
			}
			else
			{
				count++;
			}
		}
	}
	
	return count;
}

stock GetSingleArenaPlayer()
{
	new client;
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_Client_Data[i][ARENA_VALUE] == 1 )
		{
			client = i;
			return client;
		}
	}
	return -1;
}

stock GetBiggestTeam()
{
	new count_team_1, count_team_2;
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_Client_Data[i][TEAM_VALUE] == 1 )
		{
			count_team_1++;
		}
		else if( g_Client_Data[i][TEAM_VALUE] == 2 )
		{
			count_team_2++;
		}
	}
	
	if( count_team_1 > count_team_2 )
	{
		//team 1 has more players
		return 1;
	}
	else if( count_team_1 < count_team_2 )
	{
		//team 2 has more players
		return 2;
	}
	else
	{
		//teams are equal
		return 0;
	}
}

stock RemovePlayerFromGame(client)
{
	PrintToChat(client, "\x04[\x03BattleChess\x04]\x03: \x04You have been kicked from the arena.");
	ResetClientGlobals(client);
}

stock IssueRevives()
{
	new x = GetBiggestTeam();
	if( x == 1 )
	{
		//team 1 has more players
		team_2_revives++;
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04Team 2 has been issued \x031 \x04revive.");
	}
	else if( x == 2 )
	{
		//team 2 has more players
		team_1_revives++;
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04Team 1 has been issued \x031 \x04revive.");
	}
	else
	{
		//teams are even
	}
}

stock GetParticipantCount()
{
	new count;
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsParticipant(i) )
		{
			count++;
		}
	}
	return count;
}

stock ResetGameIfLowParticipantCount()
{
	new x = GetParticipantCount();
	if( x < g_MinYesVotes )
	{
		//there are less than the min # of participants
		MessageParticipants_Chat(false, "\x04[\x03BattleChess\x04]\x03: \x04Player count has dropped below the min number of participants, BattleChess will now be reset.");
		ResetAllGlobals();
		return true;
	}
	
	return false;
}
//======================================//
//										//
//			Misc. Functions				//
//										//
//======================================//
stock bool:IsValidClient(client)
{
	if(1 <= client <= MaxClients)
	{
		if( IsValidEntity(client) )
		{
			if( IsClientInGame(client) )
			{
				return true;
			}
		}
	}
	return false;
}

stock bool:IsInDuel(client)
{
	if(!IsClientInGame(client))
	{
		return false;
	}

	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
	{
		return true;
	}
	
	return false;
}

stock BerimbauGetRank(client)
{
	new RankArray[MAXPLAYERS+1];
	new m_Rank_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iRank");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");
	
	GetEntDataArray(ResourceManager, m_Rank_Offset, RankArray, 34, 4);
	
	return RankArray[client];
}