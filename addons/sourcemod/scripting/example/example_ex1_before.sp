//TODO
//
// 1. Move Target Text from chat to hud
// 2. Increase Target Text Length after each round

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "TypeSymphony",
	author = "Crystal",
	description = "Event Manager example plugin №1",
	version = "0.9",
	url = ""
};

//////////////////////////////////
//								//
//		Const and Params		//
//								//
//////////////////////////////////

#define	TEXT_LENGTH_MAX 100 //this stays as const
#define NUM_PLACES 3 //number of first places to show
//Convars:
#define ex1_text_length_max 30	//this will be convar
#define ex1_text_length_min 20	//this will be convar too
#define ex1_rounds_max 10
#define ex1_points_top 8
#define ex1_allowed_chars_word "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890,!-+=_;:[{]},,,..." // x3 comma here => x3 chance of comma in target text
#define ex1_space_chance 0.15 

//////////////////////////
//						//
//		Global Vars		//
//						//
//////////////////////////


char g_currentTargetText[TEXT_LENGTH_MAX + 1];
int g_score[MAXPLAYERS + 1];
bool g_bIsPlaying[MAXPLAYERS + 1];
int g_playerCount;
int g_remainingAnswers;
int g_pointCounter;
int g_round;
float g_flStartTime;
float g_flTopTime;
char g_topPlayer[32];


//////////////////////////////
//							//
//		Initialization		//
//							//
//////////////////////////////
public OnPluginStart() 
{ 
	SetRandomSeed(GetTime());
	
	RegAdminCmd("ex1_test", Test, Admin_RCON);
	
	RegConsoleCmd("ex1_join", Join);
	RegConsoleCmd("ex1_leave", Leave);
	
	g_round = -1;
		
} 

//////////////////////
//					//
//		Main		//
//					//
//////////////////////
public Action:Join(client, args) 
{ 
	g_bIsPlaying[client] = true;
	if (g_round < 0)
	{
		//First player!
		//Starting the game:
		g_round = 0;
		g_remainingAnswers = 1;
		for (new i = 1; i <= MaxClients; i++)
		{
			g_score[i] = 0;
			g_bIsPlaying[i] = false;
		}	
		g_bIsPlaying[client] = true;
		TextGen();	
		g_playerCount = 0;	
		
	}
	g_playerCount++;
	g_remainingAnswers++;
	PrintToChat(client, "\x03[EX1]\x01 Warm up round", g_currentTargetText);
	PrintToChat(client, "\x03[EX1]\x01 Current Text is \"%s\"", g_currentTargetText);
}

public Action:Leave(client, args) 
{ 
	if (g_bIsPlaying[client])
	{
		g_bIsPlaying[client] = false;
		g_playerCount--;
		if (g_playerCount > 0)
		{
			Answered(client);
		}
		else
		{
			GameOver();
		}
	}
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (g_round >= 0)
	{
		if (g_bIsPlaying[client])
		{
			if (StrEqual(command, "say"))
			{
				if (StrEqual(sArgs, g_currentTargetText))
				{
					Answered(client);
					return Plugin_Handled;
				}
			}
		}
		
	}
	return Plugin_Continue;
}


TextGen()
{
	int textSize = GetRandomInt(ex1_text_length_min, ex1_text_length_max);
	char charSet[] = ex1_allowed_chars_word;
	
	g_currentTargetText[0] = charSet[GetRandomInt(0, sizeof(charSet)-2)];
	for (new i = 1; i < textSize; i++)
	{	
		
		if (g_currentTargetText[i-1] != ' ')
		{
			if (GetRandomFloat(0.0, 1.0) <= ex1_space_chance)
			{
				g_currentTargetText[i] = ' ';
				continue;
			}
			else if ((g_currentTargetText[i-1] == ',') 
					|| (g_currentTargetText[i-1] == '.') 
					|| (g_currentTargetText[i-1] == '!') 
					|| (g_currentTargetText[i-1] == '?') 
					|| (g_currentTargetText[i-1] == ';') 
					|| (g_currentTargetText[i-1] == ':'))
			{
				g_currentTargetText[i] = ' ';
				continue;
			}
		}
		
		
		g_currentTargetText[i] = charSet[GetRandomInt(0, sizeof(charSet)-2)];
		if (((g_currentTargetText[i] == ',') 
			|| (g_currentTargetText[i] == '.') 
			|| (g_currentTargetText[i] == '!') 
			|| (g_currentTargetText[i] == '?') 
			|| (g_currentTargetText[i] == ';') 
			|| (g_currentTargetText[i] == ':'))
			&& (i < textSize-1))
		{
			g_currentTargetText[i+1] = ' ';
			i++;
		}
		g_currentTargetText[textSize] = '.';
		
	}
}

Answered(client)
{
	g_remainingAnswers--;
	if (g_bIsPlaying[client])
	{
		if (g_pointCounter==ex1_points_top)
		{
			g_flTopTime = GetGameTime() - g_flStartTime;
			GetClientName(client, g_topPlayer, sizeof(g_topPlayer));
		}
		g_score[client] += g_pointCounter;
		if (g_pointCounter > 0)
			g_pointCounter--;
	}		
	if (g_remainingAnswers <= 0)
	{
		EndRound();
	}
}

EndRound()
{
	if (g_round > 0)
	{
		for (new i = 1; i < MaxClients; i++)
		{
			if (g_bIsPlaying[i])
			{
				PrintToChat(i, "\x03[EX1]\x01 Best Time \x03%3.1f\x01 by \x03%s\x01", g_flTopTime, g_topPlayer);
			}
		}
	}
	
	if (g_round >= ex1_rounds_max)
	{
		GameOver();
	}
	else
	{
		NextRound();
	}
}

NextRound()
{
	g_round++;
	g_remainingAnswers = g_playerCount;
	g_pointCounter = ex1_points_top;
	TextGen();
	g_flStartTime = GetGameTime();
	for (new i = 1; i < MaxClients; i++)
	{
		if (g_bIsPlaying[i])
		{
			PrintToChat(i, "\x03[EX1]\x01 Round %d", g_round);
			PrintToChat(i, "\x03[EX1]\x01 Current Text is \"%s\"", g_currentTargetText);
		}
	}
			
}
public OnClientDisconnect(client)
{
	if (g_bIsPlaying[client])
	{
		g_bIsPlaying[client] = false;
		g_playerCount--;
		if (g_playerCount > 0)
		{
			Answered(client);
		}
		else
		{
			EndRound();
		}
	}
}

GameOver()
{
	
	int maxScorePlayers[NUM_PLACES] = {-1, ...};
	int maxScores[NUM_PLACES] = {-1, ...};
	
	for (int i = 1; i < MaxClients; i++)
	{
		if (g_bIsPlaying[i])
		{
			for (int j; j < NUM_PLACES; j++)
			{
				if (g_score[i] > maxScores[j])
				{
					if (j < NUM_PLACES - 1)
					{
						for (int k = NUM_PLACES - 1; k>j; k--)
						{
							maxScores[k] = maxScores[k-1];
							maxScorePlayers[k] = maxScorePlayers[k-1];
						}
					}
					maxScores[j] = g_score[i];
					maxScorePlayers[j] = i;
					
					break;
				}
			}
		}
	}
	for (int i = 1; i < MaxClients; i++)
	{
		if (g_bIsPlaying[i])
		{
			char playerName[32];
			PrintToChat(i, "\x03[EX1]\x01 Winners:");
			for (int j; j < max(NUM_PLACES, g_playerCount); j++)
			{
				GetClientName(maxScorePlayers[j], playerName,sizeof(playerName));
				PrintToChat(i, "\x03[EX1]\x01 %d points - \x03%s\x01", g_score[maxScorePlayers[j]], playerName);
			}
		}
	}
}

max (a, b)
{
	if (b > a) 
	{
		return b;
	}		
	else 
	{
		return a;
	}
}
min (a, b)
{
	if (b < a) 
	{
		return b;
	}		
	else 
	{
		return a;
	}
}
public Action:Test(client, args) 
{ 
	TextGen();
	PrintToChat(client, "\x03[EX1]\x01 Current Text is \"%s\"", g_currentTargetText);
}
