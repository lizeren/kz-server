#define is_zero_vec(%1) (%1[0] == 0 && %1[1] == 0 && %1[2] == 0)

new Float:VEC_NULL[3] = {0.0, 0.0, 0.0};

stock copy_vector(Float:flVec1[], Float:flVec2[])
{
	flVec2[0] = flVec1[0];
	flVec2[1] = flVec1[1];
	flVec2[2] = flVec1[2];
}

stock are_vectors_equal(Float:flVec1[], Float:flVec2[])
{
	return (flVec1[0] == flVec2[0] && flVec1[1] == flVec2[1] && flVec1[2] == flVec2[2]) ? true : false;
}

stock get_player_position(id, Float:flOrigin[3], Float:flAngles[3], &Float:flGravity)
{
	pev(id, pev_origin, flOrigin);
	pev(id, pev_v_angle, flAngles);
	pev(id, pev_gravity, flGravity);
}

stock get_player_origin(id, Float:flOrigin[3], Float:flAngles[3], &Float:flGravity, &Float:flFuser2)
{
	pev(id, pev_origin, flOrigin);
	pev(id, pev_v_angle, flAngles);
	pev(id, pev_gravity, flGravity);
	pev(id, pev_fuser2, flFuser2);
}

// for set_player_origin
new Float:VEC_DUCK_HULL_MIN[3]	= {-16.0, -16.0, -18.0 };
new Float:VEC_DUCK_HULL_MAX[3]	= { 16.0,  16.0,  32.0 };
new Float:VEC_DUCK_VIEW[3]      = { 0.0,   0.0,   12.0 };

stock set_player_origin(id, Float:flOrigin[3], Float:flAngles[3], Float:flGravity, Float:flFuser2)
{
	new iFlags = pev(id, pev_flags); 
	iFlags &= ~FL_BASEVELOCITY;					// in case player was on conveyor 
	iFlags |= FL_DUCKING;						// prevent stuck 
	set_pev(id, pev_flags, iFlags); 
	
	engfunc(EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX);	// prevent stuck 
	engfunc(EngFunc_SetOrigin, id, flOrigin);
	set_pev(id, pev_view_ofs, VEC_DUCK_VIEW); 
		

	set_pev(id, pev_velocity, VEC_NULL);		// reset speed 
	set_pev(id, pev_basevelocity, VEC_NULL);	// reset speed 
	if(flGravity > 0.0)
		set_pev(id, pev_gravity, flGravity);	
	set_pev(id, pev_fuser2, flFuser2);			

	if(!is_zero_vec(flAngles))
	{
		set_pev(id, pev_v_angle, VEC_NULL);		// reset v_angle so it will match angles 
		set_pev(id, pev_angles, flAngles);		// set view 
		set_pev(id, pev_punchangle, VEC_NULL);	// reset 
		set_pev(id, pev_fixangle, 1);			// update v_angle (and angles?) 
	}
}

stock register_cmd(command[], function[], flags = -1, info[] = "") 
{
	new szTemp[64];

	formatex(szTemp, charsmax(szTemp), "say /%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "say .%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "say_team /%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "say_team .%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "/%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), ".%s", command);
	register_clcmd(szTemp, function, flags, info);
}

stock register_saycmd(command[], function[], flags = -1, info[] = "") 
{
	new szTemp[64];

	formatex(szTemp, charsmax(szTemp), "say /%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "say .%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "say_team /%s", command);
	register_clcmd(szTemp, function, flags, info);
	
	formatex(szTemp, charsmax(szTemp), "say_team .%s", command);
	register_clcmd(szTemp, function, flags, info);
}

stock send_cmd(id, text[])
{
	message_begin(MSG_ONE, 51, _, id);
	write_byte(strlen(text) + 2);
	write_byte(10);
	write_string(text);
	message_end();
}

// Weapons

stock ham_give_weapon_by_name(id, weapon[])
{
	if(!equal(weapon, "weapon_", 7)) 
		return 0;

	new wEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, weapon));
	if(!pev_valid(wEnt)) 
		return 0;

	set_pev(wEnt,pev_spawnflags, SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn, wEnt);

	if(!ExecuteHamB(Ham_AddPlayerItem, id, wEnt))
	{
		if(pev_valid(wEnt)) 
			set_pev(wEnt,pev_flags, pev(wEnt,pev_flags) | FL_KILLME);
		return 0;
	}

	ExecuteHamB(Ham_Item_AttachToPlayer, wEnt, id);
	return 1;
}

stock ham_strip_weapon_by_name(id, weapon[])
{
	if(!equal(weapon, "weapon_", 7)) 
		return 0;

	new wId = get_weaponid(weapon);
	if(!wId) 
		return 0;

	new wEnt;
	while((wEnt = engfunc(EngFunc_FindEntityByString, wEnt, "classname", weapon)) && pev(wEnt, pev_owner) != id) {}
	if(!wEnt) 
		return 0;

	if(get_user_weapon(id) == wId) 
		ExecuteHamB(Ham_Weapon_RetireWeapon, wEnt);

	if(!ExecuteHamB(Ham_RemovePlayerItem, id, wEnt))
		return 0;
	ExecuteHamB(Ham_Item_Kill, wEnt);

	set_pev(id, pev_weapons, pev(id,pev_weapons) & ~(1<<wId));

	return 1;
}

// Removing entity 

stock delete_ent_by_class(classname[])
{
	new ent = find_ent_by_class(ent, classname);

	while (ent)
	{
		remove_entity(ent);
		ent = find_ent_by_class(ent, classname);
	}
}

// Client Director Hud 

enum _:Properties 
{
	Color,
	Effect,
	AxisX,
	AxisY,
	FxTime,
	HoldTime,
	FadeInTime,
	FadeOutTime,
	Reliable
};

stock g_iDHudProperties[Properties];

stock set_dhudmessage(red = 0, green = 160, blue = 0, Float:x = -1.0, Float:y = 0.65, effects = 2, Float:fxtime = 6.0, Float:holdtime = 3.0, Float:fadeintime = 0.1, Float:fadeouttime = 1.5, bool:reliable = false)
{
	#define clamp_byte(%1)       (clamp(%1, 0, 255))
	#define pack_color(%1,%2,%3) (%3 + (%2 << 8) + (%1 << 16))
	
	g_iDHudProperties[Color] = pack_color( clamp_byte(red), clamp_byte(green), clamp_byte(blue));
	g_iDHudProperties[AxisX] = _:x;
	g_iDHudProperties[AxisY] = _:y;
	g_iDHudProperties[Effect] = effects;
	g_iDHudProperties[FxTime] = _:fxtime;
	g_iDHudProperties[HoldTime] = _:holdtime;
	g_iDHudProperties[FadeInTime] = _:fadeintime;
	g_iDHudProperties[FadeOutTime] = _:fadeouttime;
	g_iDHudProperties[Reliable] = reliable;
}

stock show_dhudmessage(id, const szMsg[], any:...)
{	
	if(!id)
	{
		new iPlayers[32], iNum;
		get_players(iPlayers, iNum, "ch");
		if(!iNum)
		{
			return;
		}
	}
	else if(!is_user_connected(id))
	{	
		return;
	}
	
	new szMessage[128];
	new iParams = numargs();
	
	if(iParams == 2)
	{
		copy(szMessage, sizeof(szMessage) - 1, szMsg);
	}
	else
	{
		vformat(szMessage, sizeof(szMessage) - 1, szMsg, 3);
	}	
	Send_DHudMessage(id, szMessage);
}

stock Send_DHudMessage(iReceiver, szMessage[])
{
	message_begin(g_iDHudProperties[Reliable] ? (iReceiver ? MSG_ONE : MSG_ALL) : (iReceiver ? MSG_ONE_UNRELIABLE : MSG_BROADCAST), SVC_DIRECTOR, .player = iReceiver); 
	{
		write_byte(strlen(szMessage) + 31);
		write_byte(DRC_CMD_MESSAGE);
		write_byte(g_iDHudProperties[Effect]);
		write_long(g_iDHudProperties[Color]);
		write_long(g_iDHudProperties[AxisX]);
		write_long(g_iDHudProperties[AxisY]);
		write_long(g_iDHudProperties[FadeInTime]);
		write_long(g_iDHudProperties[FadeOutTime]);
		write_long(g_iDHudProperties[HoldTime]);
		write_long(g_iDHudProperties[FxTime]);
		write_string(szMessage);
	}
	message_end();
}


// ColorChat

enum ColorType
{
	NORMAL = 1, // clients scr_concolor cvar color
	GREEN, // Green Color
	TEAM_COLOR, // Red, grey, blue
	GREY, // grey
	RED, // Red
	BLUE, // Blue
};

new TeamName[][] = 
{
	"",
	"TERRORIST",
	"CT",
	"SPECTATOR"
};

stock client_print_f(id, ColorType:type, const msg[], {Float,Sql,Result,_}:...)
{
	new message[256];

	switch(type)
	{
		case NORMAL: // clients scr_concolor cvar color
		{
			message[0] = 0x01;
		}
		case GREEN: // Green
		{
			message[0] = 0x04;
		}
		default: // White, Red, Blue
		{
			message[0] = 0x03;
		}
	}

	vformat(message[1], 251, msg, 4);

	// Make sure message is not longer than 192 character. Will crash the server.
	message[192] = '^0';

	new team, ColorChange, index, MSG_Type;
	
	if(id)
	{
		MSG_Type = MSG_ONE;
		index = id;
	} 
	else 
	{
		index = FindPlayer();
		MSG_Type = MSG_ALL;
	}
	
	team = get_user_team(index);
	
	if( team >= 0 && team < 4 )
    {
		ColorChange = ColorSelection(index, MSG_Type, type);

		ShowColorMessage(index, MSG_Type, message);
		
		if(ColorChange)
		{
			Team_Info(index, MSG_Type, TeamName[team]);
		}
	}
}

stock ShowColorMessage(id, type, message[])
{
	static bool:saytext_used;
	static get_user_msgid_saytext;
	if(!saytext_used)
	{
		get_user_msgid_saytext = get_user_msgid("SayText");
		saytext_used = true;
	}
	message_begin(type, get_user_msgid_saytext, _, id);
	write_byte(id);		
	write_string(message);
	message_end();	
}

stock Team_Info(id, type, team[])
{
	static bool:teaminfo_used;
	static get_user_msgid_teaminfo;
	if(!teaminfo_used)
	{
		get_user_msgid_teaminfo = get_user_msgid("TeamInfo");
		teaminfo_used = true;
	}
	message_begin(type, get_user_msgid_teaminfo, _, id);
	write_byte(id);
	write_string(team);
	message_end();

	return 1;
}

stock ColorSelection(index, type, ColorType:Type)
{
	switch(Type)
	{
		case RED:
		{
			return Team_Info(index, type, TeamName[1]);
		}
		case BLUE:
		{
			return Team_Info(index, type, TeamName[2]);
		}
		case GREY:
		{
			return Team_Info(index, type, TeamName[0]);
		}
	}

	return 0;
}

stock FindPlayer()
{
	new i = -1;

	while(i <= get_maxplayers())
	{
		if(is_user_connected(++i))
			return i;
	}

	return -1;
}

// timer

stock stringTimer(const Float:flRealTime, szOutPut[], const iSizeOutPut, iMilliSecNumber = 2, gametime = true)
{
	static Float:flTime, iMinutes, iSeconds;
	
	if(gametime)
		flTime = get_gametime() - flRealTime;
	else
		flTime = flRealTime;
	
	if(flTime < 0.0)
		flTime = -flTime;
	
	iMinutes = floatround(flTime / 60, floatround_floor);
	iSeconds = floatround(flTime - (iMinutes * 60), floatround_floor);

	if(iMinutes <= 99)
		formatex(szOutPut, iSizeOutPut, "%02d:%02d", iMinutes, iSeconds);
	else
		formatex(szOutPut, iSizeOutPut, "%d:%02d", iMinutes, iSeconds);
	
	static iMilliSeconds;
	
	if(iMilliSecNumber == 1)
	{
		iMilliSeconds = floatround((flTime - (iMinutes * 60 + iSeconds)) * 10, floatround_floor);
		format(szOutPut, iSizeOutPut, "%s.%01d", szOutPut, iMilliSeconds);
	}
	else if(iMilliSecNumber == 2)
	{
		iMilliSeconds = floatround((flTime - (iMinutes * 60 + iSeconds)) * 100, floatround_floor);
		format(szOutPut, iSizeOutPut, "%s.%02d", szOutPut, iMilliSeconds);
	}
	else if(iMilliSecNumber == 3)
	{
		iMilliSeconds = floatround((flTime - (iMinutes * 60 + iSeconds)) * 1000, floatround_floor);
		format(szOutPut, iSizeOutPut, "%s.%03d", szOutPut, iMilliSeconds);
	}
}

stock Float:floatTimer(const szInPut[])
{
	new Float:flTime = 0.0;
	
	if(szInPut[2] == ':' && szInPut[5] == '.')
	{
		flTime+= ((szInPut[0] - 48) * 600.0) + ((szInPut[1] - 48) * 60.0);
		flTime+= ((szInPut[3] - 48) * 10.0) + (szInPut[4] - 48);
		flTime+= ((szInPut[6] - 48) / 10.0) + ((szInPut[7] - 48) / 100.0);
	}
	else
	{
		flTime = str_to_float(szInPut);
	}
	return flTime;
}

// menu

stock isMenuOpened(plaeyrId, menuId)
{
	new oldMenuId, newMenuId;
	player_menu_info(plaeyrId, oldMenuId, newMenuId);
	return (oldMenuId == menuId);
}

// IsUserSurfing by ConnorMcLeod 
stock is_player_sliding(id)
{
	if(!is_user_alive(id))
		return 0;

	new flags = entity_get_int(id, EV_INT_flags);
	if(flags & FL_ONGROUND)
		return 0;

	new Float:origin[3], Float:dest[3];
	pev(id, pev_origin, origin);

	dest[0] = origin[0];
	dest[1] = origin[1];
	dest[2] = origin[2] - 1.0;

	new ptr = create_tr2();
	engfunc(EngFunc_TraceHull, origin, dest, 0, flags & FL_DUCKING ? HULL_HEAD : HULL_HUMAN, id, ptr);
	new Float:flFraction;
	get_tr2(ptr, TR_flFraction, flFraction);
	if( flFraction >= 1.0 )
	{
		free_tr2(ptr);
		return 0;
	}

	get_tr2(ptr, TR_vecPlaneNormal, dest);
	free_tr2(ptr);

	return dest[2] <= 0.7;
}

// localhost

stock is_user_localhost(id) 
{
	new szIP[16];
	get_user_ip(id, szIP, charsmax(szIP), 1);
	
	if(equal(szIP, "loopback") || equal(szIP, "127.0.0.1")) 
	{
		return true;
	}
	return false;
}

stock get_localhost()
{
	new players[32], pnum;
	
	get_players(players, pnum);

	for(new i = 0; i < pnum; i++)
	{
		if(is_user_localhost(players[i]))
			return players[i];
	}
	
	return 0;
}