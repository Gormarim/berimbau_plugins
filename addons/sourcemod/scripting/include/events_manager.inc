#if defined _events_manager_included
 #endinput
#endif
#define _events_manager_included

/**
 * 
 */
native void RememberMe();

native void __NoticeMe();

public void __CreateTimerPls()
{
	CreateTimer(2.0, __TimerFunc, 1, TIMER_REPEAT);
}

public Action __TimerFunc(Handle timer, any data)
{
	__NoticeMe();
	return Plugin_Continue;
}

public SharedPlugin __pl_events_manager =
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
public void __pl_events_manager_SetNTVOptional()
{

}
#endif
