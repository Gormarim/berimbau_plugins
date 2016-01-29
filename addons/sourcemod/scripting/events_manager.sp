#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <adt>

public Plugin myinfo = 
{
	name = "",
	author = "",
	description = "",
	version = "0.00",
	url = ""
};

ArrayList g_plugins;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	ArrayList = new ArrayList(1, 0);
	CreateNative("RememberMe", __RememberMe);
	CreateNative("NoticeMe", __NoticeMe);
	
	RegPluginLibrary("bs_events_manager");
	return APLRes_Success;
}

public void OnPluginStart()
{
	
}

public int __RememberMe(Handle plugin, int numParams)
{
	int i = g_plugins.FindValue(plugin);
	if (i != -1)
		return;
		
	g_plugins.Push(plugin)
	
	Call_StartFunction(plugin, GetFunctionByName(plugin, "__CreateTimerPls"));
	Call_Finish();
	
	return;
}

public int __NoticeMe(Handle plugin, int numParams)
{
	int i = g_plugins.FindValue(plugin);
	if (i == -1)
		return;
	
	
	PrintToServer("Alright, i know you're ok");
	return;
}
