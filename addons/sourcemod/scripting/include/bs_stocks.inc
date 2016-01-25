#if defined _bs_stocks_included
 #endinput
#endif
#define _bs_stocks_included

/**
 * Checks if client is valid.
 *
 * @param client		Client entity index to check.
 *
 * @return				True if valid, false otherwise. 
 */
stock bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientInGame(client));
}

/**
 * Finds client entity index by client name.
 *
 * @param name_substr	Substring to be searched for.
 *
 * @return				-1 if no matches were found, 0 if >1 matches,
 *						client index if exactly 1 match was found. 
 */
stock int FindPlayerByName(char[] name_substr)
{
	int last_match = -1;
	int num_matches = 0;
	
	char name[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i))
		{
			bool bRes = GetClientName(i, name, sizeof(name));
			if (!bRes)
				continue;
			
			if (StrContains(name, name_substr, true) != -1)
			{
				last_match = i;
				num_matches += 1;
			}
		}
	}
	
	if (num_matches == 0)
		return -1;
	
	if (num_matches > 1)
		return 0;
	
	return last_match;
}
