#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <adt>
#include <datapack>

public Plugin myinfo = 
{
	name = "",
	author = "",
	description = "",
	version = "0.00",
	url = ""
};

enum EventType
{
	EventType_Gamemode = 0,
	EventType_Event
};

#define MAX_STR_LEN 64

Handle g_fwdCheckStatus;
Handle g_fwdOnPlayerFree;
Handle g_fwdOnPlayerBusy;

StringMap g_statusMap;
ArrayList g_statusList;
StringMap g_pluginsMap;

Menu mn_main;
Menu mn_gamemodes;
Menu mn_events;
Menu mn_convars;
Menu mn_convars_gamemodes;
Menu mn_convars_events;

/********************************************
				STRUCTS
********************************************/

methodmap StringProp < ArrayList
{
	public StringProp(char[] str)
	{
		ArrayList t_str = new ArrayList(MAX_STR_LEN, 1);
		t_str.SetString(0, str);
		return view_as<StringProp>(t_str);
	}
	
	public void Set(char[] str)
	{
		this.SetString(0, str);
	}
	
	public void Get(char[] buffer, int maxLen)
	{
		this.GetString(0, buffer, maxLen);
	}
}
	
methodmap BBEvent < ArrayList
{
	public BBEvent(Handle plugin, EventType type, char[] cmd, char[] name, char[] info, int id)
	{
		ArrayList ev = new ArrayList(1, 9);
		
		ev.Set(0, id);
		ev.Set(1, false);
		ev.Set(2, new StringProp(cmd));
		ev.Set(3, new StringProp(name));
		ev.Set(4, new StringProp(info));
		ev.Set(5, new ArrayList(1, 0));
		ev.Set(6, plugin);
		ev.Set(7, type);
		ev.Set(8, INVALID_HANDLE);
		
		return view_as<BBEvent>(ev);
	}
	
	property int Id
	{
		public get()
		{			
			return this.Get(0); 
		}
		public set(int id)
		{ 
			this.Set(0, id); 
		}
	}
	property bool Active
	{
		public get()
		{
			return this.Get(1);
		}
		public set(bool status)
		{
			this.Set(1, status);
		}
	}
	property StringProp StartCmd
	{
		public get()
		{
			return this.Get(2);
		}
	}
	property StringProp Name
	{
		public get()
		{
			return this.Get(3);
		}
	}
	property StringProp Info
	{
		public get()
		{
			return this.Get(4);
		}
	}
	property ArrayList ConVars
	{
		public get()
		{
			return this.Get(5);
		}
	}
	property Handle Plugin
	{
		public get()
		{
			return this.Get(6);
		}	
	}
	property EventType Type
	{
		public get()
		{
			return this.Get(7);
		}
		public set(EventType type)
		{
			this.Set(7, type);
		}
	}
	property Menu ConVarsMenu
	{
		public get()
		{
			return this.Get(8);
		}
		public set(Menu menu)
		{
			this.Set(8, menu);
		}
	}
	
	public bool AddConVar(char[] str_convar)
	{
		ConVar cv = FindConVar(str_convar);
		if (cv == null)
			return false;

		if (this.ConVars.FindValue(cv) != -1)
			return false;
		
		if (this.ConVars.Length == 0)
		{
			if (this.Type == EventType_Gamemode)
				AddEventToMenu(mn_convars_gamemodes, this);
			else
				AddEventToMenu(mn_convars_events, this);
				
			this.ConVarsMenu = new Menu(MenuHandler_ConvarsDynamic, MENU_ACTIONS_DEFAULT);
		}
		
		char buffer[200], desc[200];
		bool is_command;
		int flags;
		Handle iter = FindFirstConCommand(buffer, 200, is_command, flags, desc, 200);
		do
		{
			if (StrEqual(buffer, str_convar, false))
				break;
		}
		while (FindNextConCommand(iter, buffer, 200, is_command, flags, desc, 200));
		delete iter;
		
		this.ConVarsMenu.AddItem(desc, str_convar);
		this.ConVars.Push(cv);
		
		return true;
	}
	
	public void DeleteData()
	{	
		FreeEvent(this);
		delete this.StartCmd;
		delete this.Name;
		delete this.Info;
		delete this.ConVars;
		PrintToServer("delete lase!");
	}
}

methodmap EventsList < ArrayList
{
	public EventsList()
	{
		return view_as<EventsList>(new ArrayList(1, 0));
	}
	
	public void DeleteData()
	{
		int len = this.Length;
		for (int i = 0; i < len; ++i)
		{
			BBEvent ev = this.Get(i);
			ev.DeleteData();
			delete ev;
		}
	}
}

methodmap PluginData < ArrayList
{
	public PluginData(Handle plugin)
	{
		ArrayList pd = new ArrayList(1, 6);
		pd.Set(0, plugin);
		pd.Set(1, new EventsList());
		pd.Set(2, new StringMap());
		pd.Set(3, new EventsList());
		pd.Set(4, new StringMap());
		pd.Set(5, new ArrayList(MAX_STR_LEN, 0));
		
		return view_as<PluginData>(pd);
	}
	
	property Handle Plugin
	{
		public get()
		{
			return this.Get(0);
		}
	}
	property EventsList Gamemodes
	{
		public get()
		{
			return this.Get(1);
		}
	}
	property StringMap GamemodesMap
	{
		public get()
		{
			return this.Get(2);
		}
	}
	property EventsList Events
	{
		public get()
		{
			return this.Get(3);
		}
	}
	property StringMap EventsMap
	{
		public get()
		{
			return this.Get(4);
		}
	}
	property ArrayList Cmds
	{
		public get()
		{
			return this.Get(5);
		}
	}
	property int GamemodesCount
	{
		public get()
		{
			return (view_as<EventsList>(this.Get(1))).Length;
		}
	}
	property int EventsCount
	{
		public get()
		{
			return (view_as<EventsList>(this.Get(3))).Length;
		}
	}
	public void DeleteData()
	{	
		this.Gamemodes.DeleteData();
		this.Events.DeleteData();
		
		delete this.Gamemodes;
		delete this.GamemodesMap;
		delete this.Events;
		delete this.EventsMap;
		delete this.Cmds;
	}
	
	public BBEvent GetEvent(int id, EventType type)
	{
		char str_id[12];
		Format(str_id, 12, "%d", id);
		
		BBEvent ev = null;
		if (type == EventType_Gamemode)
			this.GamemodesMap.GetValue(str_id, ev);
		else
			this.EventsMap.GetValue(str_id, ev);
		return ev;
	}

	public bool AddEvent(char[] start_command, char[] display_name, char[] info, int id, EventType type)
	{
		char str_id[12];
		Format(str_id, 12, "%d", id);
		
		BBEvent ev;
		EventsList list;
		StringMap map;
		Menu menu;
		if (type == EventType_Gamemode)
		{
			list = this.Gamemodes;
			map = this.GamemodesMap;
			menu = mn_gamemodes;
		}
		else
		{
			list = this.Events;
			map = this.EventsMap;
			menu = mn_events;
		}
		
		if (map.GetValue(str_id, ev))
			return false;
		
		ev = new BBEvent(this.Plugin, type, start_command, display_name, info, id);
		map.SetValue(str_id, ev);
		list.Push(ev);
		
		AddEventToMenu(menu, ev);
		return true;
	}
	
	public bool AddCmd(char[] cmd)
	{
		char buffer[MAX_STR_LEN];
		int len = this.Cmds.Length;
		for (int i = 0; i < len; ++i)
		{
			this.Cmds.GetString(i, buffer, MAX_STR_LEN);
			if (StrEqual(cmd, buffer, false))
				return false;
		}
		
		this.Cmds.PushString(cmd);
		return true;
	}
}

BBEvent g_players[33];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	CreateNative("RegPlugin", __RegPlugin);
	CreateNative("UnloadPlugin", __UnloadPlugin);
	CreateNative("RegGamemode", __RegGamemode);
	CreateNative("RegEvent", __RegEvent);
	CreateNative("RegGamemodeConVar", __RegGamemodeConVar);
	CreateNative("RegEventConVar", __RegEventConVar);
	
	CreateNative("__EMValid", Valid);
	
	RegPluginLibrary("bs_events_manager");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_pluginsMap = new StringMap();
	
	g_statusMap = new StringMap();
	g_statusList = new ArrayList(1, 0);
	
	g_fwdCheckStatus = CreateForward(ET_Ignore);
	g_fwdOnPlayerFree = CreateGlobalForward("OnPlayerFree", ET_Ignore, Param_Cell);
	g_fwdOnPlayerBusy = CreateGlobalForward("OnPlayerBusy", ET_Ignore, Param_Cell);
	
	InitMenus();
	
	CreateTimer(5.0, CheckStatus, _, TIMER_REPEAT);
	
	RegConsoleCmd("sm_events", EventsMenu);
}

public Action EventsMenu(int client, int args)
{
	if (client != 0)
		mn_main.Display(client, MENU_TIME_FOREVER);
		
	return Plugin_Handled;
}

/********************************************
				STATUS CHECK
********************************************/

public Action CheckStatus(Handle timer)
{
	Call_StartForward(g_fwdCheckStatus);
	Call_Finish();
	
	DataPack dp;
	bool status;
	Handle plugin;
	int pos = g_statusList.Length - 1;
	while (pos >= 0)
	{
		dp = g_statusList.Get(pos);
		status = ReadPackCell(dp);
		if (status)
		{
			ResetPack(dp);
			WritePackCell(dp, false);
			ResetPack(dp);
		}
		else
		{
			plugin = ReadPackCell(dp);
			delete dp;
			
			char str_plugin[12];
			Format(str_plugin, 12, "%d", plugin);
			
			g_statusMap.Remove(str_plugin);
			g_statusList.Erase(pos);
			DeletePlugin(plugin);
		}	
		--pos;
	}
	return Plugin_Continue;
}

public int Valid(Handle plugin, int num_params)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	DataPack dp;
	
	if (g_statusMap.GetValue(str_plugin, dp))
	{
		WritePackCell(dp, true);
		ResetPack(dp);
	}
	
	return;
}

void AddToStatusCheck(Handle plugin)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	DataPack dp = CreateDataPack();
	WritePackCell(dp, false);
	WritePackCell(dp, plugin);
	ResetPack(dp);
	g_statusMap.SetValue(str_plugin, dp);
	g_statusList.Push(dp);
	
	AddToForward(g_fwdCheckStatus, plugin, GetFunctionByName(plugin, "__EMCheckStatus"));
}

/********************************************
				PLUGINS
********************************************/

PluginData GetPluginData(Handle plugin, bool create = false, bool &exist = false)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	PluginData pd = null;
	g_pluginsMap.GetValue(str_plugin, pd);
	exist = true;
	
	if (pd == null)
	{
		exist = false;
		if (create)
		{
			pd = new PluginData(plugin);
			g_pluginsMap.SetValue(str_plugin, pd);
		}
	}
	
	return pd;
}

bool PluginExist(Handle plugin)
{
	return GetPluginData(plugin) != null;
}

bool AddPlugin(Handle plugin)
{	
	bool exist;
	GetPluginData(plugin, true, exist);
	return !exist;
}

bool DeletePlugin(Handle plugin)
{
	PluginData pd = GetPluginData(plugin);
	
	if (pd == null)
		return false;
	RemovePluginFromMenus(pd);
	pd.DeleteData();
	delete pd;
	
	return true;
}

/********************************************
				NATIVES
********************************************/

public int __RegPlugin(Handle plugin, int numParams)
{
	if (AddPlugin(plugin))
	{
		AddToStatusCheck(plugin);
		return true;
	}
	
	return false;
}

public int __UnloadPlugin(Handle plugin, int numParams)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	DataPack dp;
	if (!g_statusMap.GetValue(str_plugin, dp))
		return false;
		
	g_statusMap.Remove(str_plugin);
	g_statusList.Erase(g_statusList.FindValue(dp));
	DeletePlugin(plugin);
	
	delete dp;
	return true;
}

public int __RegGamemode(Handle plugin, int numParams)
{
	char start_cmd[MAX_STR_LEN], display_name[MAX_STR_LEN], info[MAX_STR_LEN];
	GetNativeString(1, start_cmd, MAX_STR_LEN);
	GetNativeString(2, display_name, MAX_STR_LEN);
	GetNativeString(3, info, MAX_STR_LEN);
	
	int id = GetNativeCell(4);
	
	bool exist;
	PluginData pd = GetPluginData(plugin, true, exist);
	if (!exist)
		AddToStatusCheck(plugin);
	
	return pd.AddEvent(start_cmd, display_name, info, id, EventType_Gamemode);
}

public int __RegEvent(Handle plugin, int num_params)
{
	char start_cmd[MAX_STR_LEN], display_name[MAX_STR_LEN], info[MAX_STR_LEN];
	GetNativeString(1, start_cmd, MAX_STR_LEN);
	GetNativeString(2, display_name, MAX_STR_LEN);
	GetNativeString(3, info, MAX_STR_LEN);
	
	int id = GetNativeCell(4);
	
	bool exist;
	PluginData pd = GetPluginData(plugin, true, exist);
	if (!exist)
		AddToStatusCheck(plugin);
	
	return pd.AddEvent(start_cmd, display_name, info, id, EventType_Event);
}

public int __RegGamemodeConVar(Handle plugin, int num_params)
{
	char str_convar[MAX_STR_LEN];
	GetNativeString(1, str_convar, MAX_STR_LEN);
	int id = GetNativeCell(2);
	
	PluginData pd = GetPluginData(plugin);
	if (pd == null)
		return false;
	
	BBEvent ev = pd.GetEvent(id, EventType_Gamemode);
	if (ev == null)
		return false;
	
	return ev.AddConVar(str_convar);
}

public int __RegEventConVar(Handle plugin, int num_params)
{
	char str_convar[MAX_STR_LEN];
	GetNativeString(1, str_convar, MAX_STR_LEN);
	int id = GetNativeCell(2);
	
	PluginData pd = GetPluginData(plugin);
	if (pd == null)
		return false;
	
	BBEvent ev = pd.GetEvent(id, EventType_Event);
	if (ev == null)
		return false;
	
	return ev.AddConVar(str_convar);
}

/*
public int __GrabPlayer(Handle plugin, int num_params)
{
	int client = GetNativeCell(1);
	if (!IsFree(client))
		return false;

	int id = GetNativeCell(2);
	BBEvent ev = g_plugins.GetEvent(plugin, id);
	if (ev == null)
		return false;
	
	SetEvent(client, ev);
	return true;
}

public int __FreePlayer(Handle plugin, int num_params)
{
	int client = GetNativeCell(1);
	int id = GetNativeCell(2);
	BBEvent ev = g_plugins.GetEvent(plugin, id);
	if (ev == null || GetEvent(client) != ev)
		return false;
		
	Free(client);
	return true;
}

public int __FreeAllPlayers(Handle plugin, int num_params)
{
	int id = GetNativeCell(1);
	BBEvent ev = g_plugins.GetEvent(plugin, id);
	if (ev == null)
		return false;
	
	FreeEvent(ev);
	return true;
}
*/

/********************************************
				MENUS
********************************************/

void InitMenus()
{
	mn_main = new Menu(MenuHandler_Main, MENU_ACTIONS_DEFAULT);
	mn_main.AddItem("1", "Gamemodes");
	mn_main.AddItem("2", "Events");
	mn_main.AddItem("5", "ConVars description");
	
	mn_gamemodes = new Menu(MenuHandler_Gamemodes, MENU_ACTIONS_DEFAULT);
	mn_events = new Menu(MenuHandler_Events, MENU_ACTIONS_DEFAULT);
	//mn_custom = new Menu(MenuHandler_Custom, MENU_ACTIONS_DEFAULT);
	//mn_custom_save = new Menu(MenuHandler_CustomSave, MENU_ACTIONS_DEFAULT);
	//mn_custom_save_gamemodes = new Menu(MenuHandler_CustomSaveGamemodes, MENU_ACTIONS_DEFAULT);
	//mn_custom_save_events = new Menu(MenuHandler_CustomSaveEvents, MENU_ACTIONS_DEFAULT);
	//mn_custom_gamemodes = new Menu(MenuHandler_CustomGamemodes, MENU_ACTIONS_DEFAULT);
	//mn_custom_events = new Menu(MenuHandler_CustomEvents, MENU_ACTIONS_DEFAULT);
	
	//mn_commands = new Menu(MenuHandler_Commands, MENU_ACTIONS_DEFAULT);
	mn_convars = new Menu(MenuHandler_Convars, MENU_ACTIONS_DEFAULT);
	mn_convars.AddItem("1", "Gamemodes");
	mn_convars.AddItem("2", "Events");
	
	mn_convars_gamemodes = new Menu(MenuHandler_ConvarsGamemodes, MENU_ACTIONS_DEFAULT);
	mn_convars_events = new Menu(MenuHandler_ConvarsEvents, MENU_ACTIONS_DEFAULT);
	
}

void AddEventToMenu(Menu menu, BBEvent ev)
{
	char info[20], name[MAX_STR_LEN];
	Format(info, 20, "%d", ev);
	
	ev.Name.Get(name, MAX_STR_LEN);
	
	menu.AddItem(info, name);
}

void RemovePluginFromMenus(PluginData plugin)
{
	int len = plugin.Events.Length;
	for (int i = 0; i < len; ++i)
		RemoveEventFromMenus(view_as<BBEvent>(plugin.Events.Get(i)));
	
	len = plugin.Gamemodes.Length;
	for (int i = 0; i < len; ++i)
		RemoveEventFromMenus(view_as<BBEvent>(plugin.Gamemodes.Get(i)));
}

void RemoveEventFromMenus(BBEvent ev)
{
	char str_ev[50];
	Format(str_ev, 50, "%d", ev);
	
	Menu menu1, menu2;
	if (ev.Type == EventType_Gamemode)
	{
		menu1 = mn_gamemodes;
		menu2 = mn_convars_gamemodes;
	}
	else
	{
		menu1 = mn_events;
		menu2 = mn_convars_events;
	}
	
	RemoveItem(menu1, str_ev);

	if (ev.ConVars.Length != 0)
	{
		RemoveItem(menu2, str_ev);
	}
}

void RemoveItem(Menu menu, char[] str_ev)
{
	char info[50], buff[50];
	int style;
	int sz = menu.ItemCount - 1;
	
	while (sz >= 0)
	{
		menu.GetItem(sz, info, 50, style, buff, 50);
		
		if (StrEqual(str_ev, info, false))
		{
			menu.RemoveItem(sz);
			break;
		}
		--sz;
	}
}

public int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				mn_gamemodes.Display(param1, MENU_TIME_FOREVER);
			}
			case 1:
			{
				mn_events.Display(param1, MENU_TIME_FOREVER);
			}
			case 2:
			{
				mn_convars.Display(param1, MENU_TIME_FOREVER);
			}
		}
	}
	
	return;
}

public int MenuHandler_Gamemodes(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		char cmd[MAX_STR_LEN];
		ev.StartCmd.Get(cmd, MAX_STR_LEN);
		ServerCommand(cmd);
	}
	return;
}

public int MenuHandler_Events(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		char cmd[MAX_STR_LEN];
		ev.StartCmd.Get(cmd, MAX_STR_LEN);
		ServerCommand(cmd);
	}
	return;
}

public int MenuHandler_Convars(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 0)
			mn_convars_gamemodes.Display(param1, MENU_TIME_FOREVER);
		else
			mn_convars_events.Display(param1, MENU_TIME_FOREVER);
	}
			
	return;
}

public int MenuHandler_ConvarsGamemodes(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		ev.ConVarsMenu.Display(param1, MENU_TIME_FOREVER);
	}
	return;
}

public int MenuHandler_ConvarsEvents(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		ev.ConVarsMenu.Display(param1, MENU_TIME_FOREVER);
	}
	return;
}

public int MenuHandler_ConvarsDynamic(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[200], name[100];
		int style;
		menu.GetItem(param2, info, 200, style, name, 100);
		
		PrintToChat(param1, info);
	}
	return;
}

/********************************************
				PLAYERS
********************************************/

bool IsFree(int client)
{
	return view_as<BBEvent>(g_players[client]) == null;
}

BBEvent GetEvent(int client)
{
	return view_as<BBEvent>(g_players[client]);
}

void SetEvent(int client, BBEvent ev)
{
	g_players[client] = ev;
	
	Call_StartForward(g_fwdOnPlayerBusy);
	Call_PushCell(client);
	Call_Finish();
}

void Free(int client)
{
	g_players[client] = null;
		
	Call_StartForward(g_fwdOnPlayerFree);
	Call_PushCell(client);
	Call_Finish();
}

void FreeAll()
{
	for (int i = 0; i < 33; ++i)
		Free(i);
}

void FreeEvent(BBEvent ev)
{
	for (int i = 0; i < 33; ++i)
		if (g_players[i] == ev)
			Free(i);
}

