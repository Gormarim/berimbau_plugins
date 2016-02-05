////////////////////////////////////
//turn area X on and off with command /ex3_toggle X
//enter the area
//fight
//opponent leaves area = win
// after 10 sec area will turn on again (don't turn off while it is on cd)
//
// no rounds, damage protection from non-participants, no walls
////////////////////////////////////

///!TODO
//
//1. Test it
//2. Test with 2+ arenas, 3+ players on arena

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "AreaFight",
	author = "Crystal",
	description = "Event Manager example plugin №3",
	version = "0.9",
	url = ""
};

//////////////////////////////////
//								//
//		Const and Params		//
//								//
//////////////////////////////////

#define MAXAREAS 1
#define MAXAREAPLAYERS 4

//////////////////////////
//						//
//		Global Vars		//
//						//
//////////////////////////

int g_areaPlayer[MAXAREAS][MAXAREAPLAYERS];
int g_gatheredPlayersCount[MAXAREAS];
int g_areaMaxPlayers[MAXAREAS];
float g_vecAreaPos[MAXAREAS][3];
float g_vecAreaWLH[MAXAREAS][3];
int g_areaTrigger[MAXAREAS];
int g_areaBeams[MAXAREAS][6];	//4 Beams + 1 Beam + 1 Target
bool g_bMapIsCorrect;
bool g_bGameStarted[MAXAREAS];
bool g_bAreaOn[MAXAREAS];
bool g_bIsPlaying[MAXPLAYERS + 1];

//////////////////////////////
//							//
//		Initialization		//
//							//
//////////////////////////////

public OnPluginStart() 
{
	RegAdminCmd("ex3_toggle", ToggleArea, Admin_RCON);
	RegAdminCmd("ex3_all_on", TurnAllOn, Admin_RCON);
	RegAdminCmd("ex3_all_off", TurnAllOff, Admin_RCON);
	
	RegAdminCmd("ex3_test", Test, Admin_RCON);
	
	HookEvent("player_death", PlayerDeath);
}

public OnMapStart()
{
	PrecacheModel("materials/particle/dys_beam3.vmt");
	PrecacheModel("materials/particle/dys_beam_big_rect.vmt");
	
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	InitAreas(mapName);
	
}

InitAreas(char[] mapName)
{
	if (StrEqual("ffa_community", mapName, false))
	{
		g_bMapIsCorrect = true;
		for (int i; i < MAXAREAS; i++)
		{
			g_bAreaOn[i] = false;
			g_areaMaxPlayers[i] = 2;
		}
		
		int A = 0;
		g_vecAreaPos[A] = {2187.833496, -884.694214, 192.0};
		g_vecAreaWLH[A] = {600.0, 280.0, 1000.0};
		g_areaMaxPlayers[A] = 2;
		A++;

	}
	else
	{
		g_bMapIsCorrect = false;
	}
	
	
		
}
//////////////////////
//					//
//		Main		//
//					//
//////////////////////

public Action ToggleArea(client, args)
{
	if (args > 0)
	{
		char arg[15];
		GetCmdArg(1, arg, 5);
			
		if (!g_bAreaOn[StringToInt(arg)])
		{
			TurnAreaOn(StringToInt(arg));
		}
		else
		{
			TurnAreaOff(StringToInt(arg));
		}
	}
}

public Action TurnAllOn(client, args)
{
	for (int i; i < MAXAREAS; i++)
	{
		TurnAreaOn(i);
	}
}

public Action TurnAllOff(client, args)
{
	for (int i; i < MAXAREAS; i++)
	{
		TurnAreaOff(i);
	}
}

TurnAreaOn(area)
{
	if (g_bMapIsCorrect)
	{
		if (!g_bAreaOn[area])
		{
		
			g_bAreaOn[area] = true;
			
			g_areaTrigger[area] = CreateTrigger(area);
			g_areaTrigger[area] = CreateTrigger(area);
			CreateBeams(area);
		}
	}
	
}

TurnAreaOff(area)
{
	if (g_bAreaOn[area])
	{	
		g_bAreaOn[area] = false;
		RemoveBeams(area);
		RemoveEntityNow(g_areaTrigger[area]);
	}
	
	
}

int CreateTrigger(area)
{
	float vecPos[3];
	float minBounds[3];
	float maxBounds[3];
	for (int i; i < 3; i++)
	{
		vecPos[i] = g_vecAreaPos[area][i];
		minBounds[i] =  - g_vecAreaWLH[area][i]/2.0;
		maxBounds[i] =   g_vecAreaWLH[area][i]/2.0;
	}	
	
	int ent = CreateEntityByName("trigger_multiple");
	
	DispatchKeyValue(ent, "spawnflags", "1"); 
	DispatchKeyValue(ent, "targetname", "ex3_trigger_multiple");
	DispatchKeyValue(ent, "wait", "0.01");
	
	DispatchSpawn(ent);
	ActivateEntity(ent);
	
	TeleportEntity(ent, vecPos, NULL_VECTOR, NULL_VECTOR);
    //TeleportEntity(ent, NULL_VECTOR, vecDir, NULL_VECTOR);
	
	///! 
	SetEntityModel(ent, "models/extras/info_speech.mdl");
	
	
	SetEntPropVector(ent, Prop_Data, "m_vecMins", minBounds);
	SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxBounds);
	
	SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
	
	int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);
	
	
	SetVariantString("OnStartTouch !self:Enable::0.0:-1");
	AcceptEntityInput(ent, "AddOutput"); 
	
	HookSingleEntityOutput(ent, "OnStartTouch", AreaStartTouch, false);
	HookSingleEntityOutput(ent, "OnEndTouch", AreaEndTouch, false);
	
	return ent;
}

CreateBeams(area)
{
	float vecPoint[3];
	vecPoint[2] = g_vecAreaPos[area][2] + 8.0;
	
	for (int i; i < 5; i++)
	{
		
		int ent = CreateEntityByName( "env_beam" );
		SetEntityModel(ent, "materials/particle/dys_beam_big_rect.vmt" );
				
		DispatchKeyValue(ent, "renderamt", "100" );
		DispatchKeyValue( ent, "rendermode", "0" );
		DispatchKeyValue( ent, "rendercolor", "0 255 0" );  
		DispatchKeyValue( ent, "life", "0" ); 
						
		DispatchSpawn(ent);
		SetEntPropEnt( ent, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(ent) );
		SetEntPropEnt( ent, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(ent), 1 );
		
		SetEntProp( ent, Prop_Send, "m_nNumBeamEnts", 2);
		SetEntProp( ent, Prop_Send, "m_nBeamType", 2);
						
		SetEntPropFloat( ent, Prop_Data, "m_fWidth",  5.0 );
		SetEntPropFloat( ent, Prop_Data, "m_fEndWidth", 5.0 );
		ActivateEntity(ent);
		AcceptEntityInput(ent,"TurnOn");
		
		g_areaBeams[area][i] = ent;
	}
	
	int tar = CreateEntityByName("env_sprite"); 
	SetEntityModel(tar, "materials/particle/dys_beam_big_rect.vmt" );
	DispatchKeyValue(tar, "renderamt", "255" );
	DispatchKeyValue(tar, "rendercolor", "255 255 255" ); 
	DispatchSpawn(tar);
	AcceptEntityInput(tar,"ShowSprite");
	ActivateEntity(tar);
	g_areaBeams[area][5] = tar;
	
	SetEntPropEnt( g_areaBeams[area][0], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(g_areaBeams[area][3]), 1 );
	SetEntPropEnt( g_areaBeams[area][1], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(g_areaBeams[area][0]), 1 );
	SetEntPropEnt( g_areaBeams[area][2], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(g_areaBeams[area][1]), 1 );
	SetEntPropEnt( g_areaBeams[area][3], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(g_areaBeams[area][2]), 1 );
	SetEntPropEnt( g_areaBeams[area][4], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(g_areaBeams[area][5]), 1 );
	
	vecPoint[0] = g_vecAreaPos[area][0] + g_vecAreaWLH[area][0]/2.0 + 32.0;
	vecPoint[1] = g_vecAreaPos[area][1] + g_vecAreaWLH[area][1]/2.0 + 32.0;
	TeleportEntity(g_areaBeams[area][0], vecPoint, NULL_VECTOR, NULL_VECTOR); 
	vecPoint[0] = g_vecAreaPos[area][0] - g_vecAreaWLH[area][0]/2.0 - 32.0;
	vecPoint[1] = g_vecAreaPos[area][1] + g_vecAreaWLH[area][1]/2.0 + 32.0;
	TeleportEntity(g_areaBeams[area][4], vecPoint, NULL_VECTOR, NULL_VECTOR); 
	TeleportEntity(g_areaBeams[area][1], vecPoint, NULL_VECTOR, NULL_VECTOR);
	vecPoint[0] = g_vecAreaPos[area][0] - g_vecAreaWLH[area][0]/2.0 - 32.0;
	vecPoint[1] = g_vecAreaPos[area][1] - g_vecAreaWLH[area][1]/2.0 - 32.0;
	TeleportEntity(g_areaBeams[area][2], vecPoint, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(g_areaBeams[area][5], vecPoint, NULL_VECTOR, NULL_VECTOR);  
	vecPoint[0] = g_vecAreaPos[area][0] + g_vecAreaWLH[area][0]/2.0 + 32.0;
	vecPoint[1] = g_vecAreaPos[area][1] - g_vecAreaWLH[area][1]/2.0 - 32.0;
	TeleportEntity(g_areaBeams[area][3], vecPoint, NULL_VECTOR, NULL_VECTOR);
	
	
}

StartFight(area)
{
	g_bGameStarted[area] = true;
	for (int i; i < g_areaMaxPlayers[area]; i++)
	{
		g_bIsPlaying[g_areaPlayer[area][i]] = true;
		SDKHook(g_areaPlayer[area][i], SDKHook_OnTakeDamage, OnTakeDamage);
		PrintToChat(g_areaPlayer[area][i], "\x03[EX3]\x01 Fight!");
	}
	for(int i; i < 5; i++)
	{
		SetVariantString("rendercolor 255 0 0" ); 
		AcceptEntityInput(g_areaBeams[area][i], "AddOutput");
	}

}

StopGame(area)
{
	PrintToChat(g_areaPlayer[area][0], "\x03[EX3]\x01 You win!");
	g_bIsPlaying[g_areaPlayer[area][0]] = false;
	g_bGameStarted[area] = false;
	TurnAreaOff(area);
	
	CreateTimer(10.0, Timer_AreaRespawn, area);
}

public Action:Timer_AreaRespawn(Handle:timer, any:area)
{
	
	TurnAreaOn(area);
}

PlayerOut(area, client)
{
	for( int i; i < g_gatheredPlayersCount[area]; i++)
		if (client == g_areaPlayer[area][i])
		{
			SDKUnook(client, SDKHook_OnTakeDamage, OnTakeDamage);
			if (i < g_gatheredPlayersCount[area] - 1)
			{
				for (int j; j<g_gatheredPlayersCount[area] - 1; j++)
				{
					g_areaPlayer[area][j] = g_areaPlayer[area][j+1];
				}
			}
			g_gatheredPlayersCount[area]--;
			if( g_bGameStarted[area])
			{
				if (g_gatheredPlayersCount[area] <= 1)
				{
					StopGame(area);
				}
			}
			break;
		}
}

public AreaStartTouch(const String:output[], caller, activator, Float:delay)
{
	//find area of trigger-caller:
	int area = -1;
	for (int i; i < MAXAREAS; i++)
		if (g_bAreaOn[i])
			if (caller == g_areaTrigger[i])
			{
				area = i;
				break;
			}
			
	if (area >= 0)
	{
		if (!g_bGameStarted[area])  // not started ==> g_gatheredPlayersCount < g_areaMaxPlayers
		{
			if (IsPlayerAlive(activator))
			{
				g_areaPlayer[area][g_gatheredPlayersCount[area]] = activator;
				g_gatheredPlayersCount[area]++;
				
				if (g_gatheredPlayersCount[area] >= g_areaMaxPlayers[area])
				{
					StartFight(area);
				}
				else
				{
					AcceptEntityInput(g_areaBeams[area][4], "TurnOff");
					//inner laser shows number of players needed
					float vecPoint[3];
					vecPoint[2] = g_vecAreaPos[area][2] + 8.0;
					vecPoint[0] = g_vecAreaPos[area][0] - g_vecAreaWLH[area][0]/2.0 - 32.0 + (g_vecAreaWLH[area][0] + 64.0)*g_gatheredPlayersCount[area]/g_areaMaxPlayers[area];
					
					vecPoint[1] = g_vecAreaPos[area][1] + g_vecAreaWLH[area][1]/2.0 + 32.0;
					TeleportEntity(g_areaBeams[area][4], vecPoint, NULL_VECTOR, NULL_VECTOR);
					
					vecPoint[1] = g_vecAreaPos[area][1] - g_vecAreaWLH[area][1]/2.0 - 32.0;
					TeleportEntity(g_areaBeams[area][5], vecPoint, NULL_VECTOR, NULL_VECTOR);
					
					
					if (g_gatheredPlayersCount[area] <= 0)
					{
						//SetVariantString("rendercolor 0 255 0" );
						//AcceptEntityInput(g_areaBeams[area][4], "AddOutput");		
						AcceptEntityInput(g_areaBeams[area][4], "TurnOff");
					}
					else if (g_gatheredPlayersCount[area] == g_areaMaxPlayers[area])
					{
						SetVariantString("rendercolor 255 0 0" ); 
						AcceptEntityInput(g_areaBeams[area][4], "AddOutput");
						AcceptEntityInput(g_areaBeams[area][4], "TurnOn");
					}
					else
					{
						SetVariantString("rendercolor 0 0 255" ); 
						AcceptEntityInput(g_areaBeams[area][4], "AddOutput");
						AcceptEntityInput(g_areaBeams[area][4], "TurnOn");
					}
				}
			}
		}
	}
}
public AreaEndTouch(const String:output[], caller, activator, Float:delay)
{
	//find area of trigger-caller:
	int area = -1;
	for (int i; i < MAXAREAS; i++)
		if (g_bAreaOn[i])
			if (caller == g_areaTrigger[i])
			{
				area = i;
				break;
			}
			
	if (area >= 0)
	{
		PlayerOut(area, activator);
		
		if (!g_bGameStarted[area])
		{
			
		}
		else
		{
			if (g_bIsPlaying[activator])
			{
				g_bIsPlaying[activator] = false;
				if (IsValidClient(activator))
				{
					FakeClientCommand(activator, "kill");
				}
			}
		}
		
		//inner laser shows number of players needed
		float vecPoint[3];
		vecPoint[2] = g_vecAreaPos[area][2] + 8.0;
		vecPoint[0] = (g_vecAreaWLH[area][0] + 64.0)*g_gatheredPlayersCount[area]/g_areaMaxPlayers[area];
					
		vecPoint[1] = g_vecAreaPos[area][1] + g_vecAreaWLH[area][1]/2.0 + 32.0;
		TeleportEntity(g_areaBeams[area][4], vecPoint, NULL_VECTOR, NULL_VECTOR);
					
		vecPoint[1] = g_vecAreaPos[area][1] - g_vecAreaWLH[area][1]/2.0 + 32.0;
		TeleportEntity(g_areaBeams[area][5], vecPoint, NULL_VECTOR, NULL_VECTOR);
		if (!g_bGameStarted[area])		
		{
			if (g_gatheredPlayersCount[area] <= 0)
			{
				//SetVariantString("rendercolor 0 255 0" );
				//AcceptEntityInput(g_areaBeams[area][4], "AddOutput");		
				AcceptEntityInput(g_areaBeams[area][4], "TurnOff");
			}
			else if (g_gatheredPlayersCount[area] == g_areaMaxPlayers[area])
			{
				SetVariantString("rendercolor 255 0 0" ); 
				AcceptEntityInput(g_areaBeams[area][4], "AddOutput");
			}
		}
	}
}

RemoveBeams(area)
{
	for (int i; i < 6; i++)
	{
		RemoveEntityNow(g_areaBeams[area][i]);
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (damage <= 0.0)
		return Plugin_Continue;
	
	if (!g_bIsPlaying[victim])
		return Plugin_Continue;
	
	if (1 <= attacker && attacker <= MaxClients)
	{
		if (!g_bIsPlaying[attacker])
		{
			
			damage = 0.0;
			return Plugin_Handled;
		}
		else
		{
			//check if attacker is in different area
			
		}
	}
	return Plugin_Continue;
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_bIsPlaying[client] = false;
	
	for (int i; i < MAXAREAS; i++)
	{
		bool found = false;
		for( new j; j < g_gatheredPlayersCount[i]; j++)
		{
			if (g_areaPlayer[i][j] == client)
			{
				PlayerOut(i, client);
				break;
			}
			if (found)
				break;
		}
	}
}

public OnClientDisconnect(client)
{
	g_bIsPlaying[client] = false;
	
	for (int i; i < MAXAREAS; i++)
	{
		bool found = false;
		for( new j; j < g_gatheredPlayersCount[i]; j++)
		{
			if (g_areaPlayer[i][j] == client)
			{
				PlayerOut(i, client);
				break;
			}
			if (found)
				break;
		}
	}
	
}

//////////////////////
//					//
//		Misc		//
//					//
//////////////////////

/*float[3] AddVectors(float a[3], float b[3])
{
	float c[3];
	for (int i; i < 3; i++)
		c[i] = a[i] + b[i];
}
float[3] SubVectors(float a[3], float b[3])
{
	float c[3];
	for (int i; i < 3; i++)
		c[i] = a[i] - b[i];
}*/

RemoveEntityNow(any:entity)
{
	if (entity > 32)
		if(IsValidEdict(entity))
		{
			AcceptEntityInput(entity, "Deactivate");
			AcceptEntityInput(entity, "Kill");
		}
}
bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientInGame(client));
}
//////////////////////
//					//
//		Tests		//
//					//
//////////////////////

public Action Test(client, args)
{
	
	
}













