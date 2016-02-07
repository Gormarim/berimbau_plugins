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
	
}

public void OnAllPluginsLoaded()
{
	RegEvent("sm_noclip Gorm", "NOCLIP GORM");
	RegEventConVar("bb_air_drag");
}

