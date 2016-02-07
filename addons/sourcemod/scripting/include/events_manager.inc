#if defined _events_manager_included
 #endinput
#endif
#define _events_manager_included

/**
 * 
 */
 
enum EventType
{
	EventType_Gamemode = 0,
	EventType_Event
};

forward OnPlayerFree(client);

forward OnPlayerBusy(client);

native bool:RegPlugin();

native bool:UnloadPlugin();

native bool:RegGamemode(const String:start_command[], const String:display_name[], const String:info[] = "", id = 0);

native bool:RegEvent(const String:start_command[], const String:display_name[], const String:info[] = "", id = 0);

native bool:RegGamemodeConVar(char[] str_convar, id = 0);

native bool:RegEventConVar(char[] str_convar, id = 0);

forward __EMCheckStatus();

native __EMValid();

public __EMCheckStatus()
{
	__EMValid();
}

public SharedPlugin:__pl_events_manager =
{
	name = "bs_events_manager",
	file = "events_manager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_events_manager_SetNTVOptional()
{

}
#endif
