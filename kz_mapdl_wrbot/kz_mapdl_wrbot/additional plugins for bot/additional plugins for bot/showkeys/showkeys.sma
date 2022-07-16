#include <amxmodx>
#include <fakemeta>



new const PLUGIN[] = "Showkeys";
new const VERSION[] = "1.1";
new const AUTHOR[] = "Destroman";

/////////////showkeys

new g_iPlayerKeys[33];
new bool:g_bShowKeys[33];
new Float:fShowKeyTime = 0.0;
new g_showkeys;
new g_color;
new g_SyncShowKeys;
new g_iMaxPlayers;
///////////// end showkeys


public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	/////////showkeys
	g_showkeys = register_cvar("amx_showkeys","1");
	g_color = register_cvar("amx_showkeys_color","175 175 175");
	
	register_clcmd( "say /showkeys", "ClientShowKeys");
	
	g_iMaxPlayers = get_maxplayers();
	
	register_forward(FM_StartFrame, "fw_StartFrame");
	g_SyncShowKeys = CreateHudSyncObj();
	////////// end showkeys
	

}

public client_putinserver(id) {
	g_bShowKeys[id] = true;
}

/////////////showkeys


public ClientShowKeys(id)
{
	if(!is_user_alive(id)) {
		g_bShowKeys[id] = !g_bShowKeys[id];
		set_hudmessage(0, 100, 255, -1.0, 0.74, 0, 0.0, 0.1, 0.0, 0.0, 4);
		if (g_bShowKeys[id])
		{
			show_hudmessage( id, "Showkeys: ON" );
		}
		else
		{
			show_hudmessage( id, "Showkeys: OFF" );
		}
	}

}

public fw_StartFrame()
{
	if(!get_pcvar_num(g_showkeys))
		return FMRES_IGNORED;
	
	static Float:fGameTime, Float:fDelay;
	fGameTime = get_gametime();
	fDelay = 0.1;
	
	if((fShowKeyTime + fDelay) <= fGameTime)
	{
		show_keyinfo();
		fShowKeyTime = fGameTime;
	}
	static id;
	for(id = 1; id <= g_iMaxPlayers; id++)
	{
		if(is_user_alive(id))
		{
			new Button = pev(id, pev_button);
			if(Button & IN_FORWARD)
				g_iPlayerKeys[id] |= IN_FORWARD;
			if(Button & IN_BACK)
				g_iPlayerKeys[id] |= IN_BACK;
			if(Button & IN_MOVELEFT)
				g_iPlayerKeys[id] |= IN_MOVELEFT;
			if(Button & IN_MOVERIGHT)
				g_iPlayerKeys[id] |= IN_MOVERIGHT;
			if(Button & IN_DUCK)
				g_iPlayerKeys[id] |= IN_DUCK;
			if(Button & IN_JUMP )
				g_iPlayerKeys[id] |= IN_JUMP;
		}
	}
	return FMRES_IGNORED;
}

stock show_keyinfo() 
{
	static id;
	for(id = 1; id <= g_iMaxPlayers; id++)
	{
		if(!is_user_alive(id))
		{
			new specmode = pev(id, pev_iuser1);
			if(specmode == 2 || specmode == 4)
			{
				new target = pev(id, pev_iuser2);
				
				if(target != id && g_bShowKeys[id])
				{	
					if(!is_user_alive(target))
						g_iPlayerKeys[target] = 0;
					
					static plr_key[64], r, g, b;
					HudMsgColor(g_color, r, g, b);
					set_hudmessage(r, g, b, -1.0, -0.40, 0, 0.0, 0.1, 0.0, 0.0, 4);
					formatex(plr_key, 63, "%s^n            %s   %s   %s   %s ^n %s",
					g_iPlayerKeys[target] & IN_FORWARD ? "W" : " .",
					g_iPlayerKeys[target] & IN_MOVELEFT ? "A" : ".",
					g_iPlayerKeys[target] & IN_BACK ? "S" : ".",
					g_iPlayerKeys[target] & IN_MOVERIGHT ? "D" : ".",
					g_iPlayerKeys[target] & IN_DUCK ? "DUCK" : "-      ",
					g_iPlayerKeys[target] & IN_JUMP ? "JUMP" : "  .  ");
					ShowSyncHudMsg(id, g_SyncShowKeys, "%s", plr_key);
					
//					g_iPlayerKeys[target] = 0;
				}
			}
		}
	}
	for(id = 1; id <= g_iMaxPlayers; id++)
	{
		g_iPlayerKeys[id] = 0;
	}
	return PLUGIN_CONTINUE;
}

public HudMsgColor(cvar, &r, &g, &b)
{
	static color[16], piece[5];
	get_pcvar_string(cvar, color, 15);
	
	
	#if AMXX_VERSION_NUM < 183
		strbreak( color, piece, 4, color, 15);
	#else
		argbreak( color, piece, 4, color, 15);
	#endif
	
	r = str_to_num(piece);
	
	#if AMXX_VERSION_NUM < 183
		strbreak( color, piece, 4, color, 15);
	#else
		argbreak( color, piece, 4, color, 15);
	#endif
	g = str_to_num(piece);
	b = str_to_num(color);
}



////////////////end showkeys
