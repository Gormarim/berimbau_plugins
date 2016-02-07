#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <include/events_manager.inc>

public Plugin myinfo = 
{
	name = "123",
	author = "123",
	description = "123",
	version = "11.00",
	url = "123"
};

public void OnPluginStart()
{
	RegConsoleCmd("ev_start", StartEv);
	RegConsoleCmd("ev_stop", StopEv);
}

public void OnAllPluginsLoaded()
{
	RegEvent("sm_noclip Gorm", "NOCLIP GORM");
	RegEventConVar("bb_air_drag");
}

public Action StartEv(int client, int args)
{
	if (StartEvent())
		PrintToChatAll("Event started!");
	else
		PrintToChatAll("Cannot start event");
	
	return Plugin_Handled;
}

public Action StopEv(int client, int args)
{
	if (EndEvent())
		PrintToChatAll("Event stopped!");
	else
		PrintToChatAll("Cannot stop event");
	
	return Plugin_Handled;
}
	
