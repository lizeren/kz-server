//Changelog 1.2 
//Fix Connections to servers - freeze on changelevel if community unreachable
//Added Cvar to kick bot if count of player reach maxplayers - count 
//Fixed Crashes on changelevel 
//Fixed Godmode
//Change cvars
//Changing config file
//Fixed longjump stats
//Changelog 1.3
//Fixed Timer
//Fixed Freeze bot 
//Added additional functions for lan and server Forward Backward..
//
#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fun>
#include <cstrike>
#include <hamsandwich>
#include <curl>
#include <amxxarch>

#pragma tabsize 0
#pragma semicolon 1
#pragma dynamic 131072;

/*#if AMXX_VERSION_NUM < 183
	#assert "AMX Mod X v1.8.3 or greater library required!"
#endif
*/
#define PLUGIN	"KZ_WRBOT"
#define AUTHOR	"Destroman Edited"
#define VERSION	"1.3"
#define KZ_ADMIN_LEVEL ADMIN_MENU


#if defined client_disconnected
#define client_disconnect client_disconnected
#endif

//#define DEBUG

#define NUM_THREADS 256


static Float:next_think = 0.009;

new iArchiveName[128], RARArchive[128], g_szCurrentMap[32], iNavName[128], Old_iNavName[128], FLAG[10], url_sprite[32], url_sprite_xz[32], WR_TIME[12], WR_NAME[32], WR_PREFIX[3];

new g_Bot_Icon_ent, SyncHudTimer, g_bot_start_use, g_bot_stop_use, g_bot_enable, g_bot_frame, wr_bot_id, iDemo_header_size, iFile, g_Check_Files, maxplayers, g_timer, kz_bot_local_wr, kz_bot_flag, kz_bot_kick, kz_bot_hud, kz_bot_cooldown, a_Size;

new Interval = 1000;

new Array:fPlayerMoveType, Array:fPlayerAngle, Array:fPlayerKeys, Array:fPlayerVelo, Array:fPlayerOrigin, Array:update_file_data, Array:need_update_com, Array:Founded_Demos;

new Float:timer_time[33], bool:timer_started[33], bool:IsPaused[33], Float:g_pausetime[33], Float:finish_time[33];

new Trie:start_buttons;
new Trie:stop_buttons;

static iDemoName[128];
static g_FOUNDED_COMMUNITY, iParsedFile;

new bool:bFoundDemo = false;
new bool:CheckAgain = false;
//new bool:ChangingLevel = false;
new bool:g_Check_Filetime = false;
new bool:g_NOT_ENOUGH = false;
new bool:Prechached = false;
new bool:g_Connected[33] = false;
new bool:is_localhost = false;
new bool:start_on_use[33] = false;
new bool:g_start_on_use = false;
new bool:Called_Other = false;
new bool:Dem_Finished = false;
new bool:Nav_Finished = false;
new bool:HealsOnMap = false;
new bool:Call_Parse = false;
new bool:Countdown = false;

new const dl_dir[] = "addons/amxmodx/data/kz_downloader";
new const update_file[] = "addons/amxmodx/data/kz_downloader/wr_filetime.ini";
new const archive_dir[] = "addons/amxmodx/data/kz_downloader/archives";
new const temp_dir[] = "addons/amxmodx/data/kz_downloader/temp";
new local_demo_folder[32] = "addons/amxmodx/data/kz_wrbot";
new const bot_cfg[] = "addons/amxmodx/configs/kz_bot.cfg";

const COMMUNITIES = 2;

new const g_szDemoFiles[][][] = 
{
	{ "demofilesurl", "demosfilename", "rarfilelink", "community", "extension", "botname" },
	{ "https://xtreme-jumps.eu/demos.txt", "addons/amxmodx/data/kz_downloader/demos.txt", "http://files.xtreme-jumps.eu/demos", "Xtreme-Jumps", "rar" , "WR" },
	{ "https://cosy-climbing.net/demoz.txt", "addons/amxmodx/data/kz_downloader/demoz.txt", "https://cosy-climbing.net/files/demos", "Cosy-Climbing", "rar", "WR"  }
};

enum _:RecordDemo
{
	URLS,
	DEMOS,
	LINK,
	NAME,
	EXT,
	BOT
};

enum _:Consts
{
	HEADER_SIZE         = 544,
	HEADER_SIGNATURE_CHECK_SIZE = 6,
	HEADER_SIGNATURE_SIZE       = 8,
	HEADER_MAPNAME_SIZE     = 260,
	HEADER_GAMEDIR_SIZE     = 260,
	DIR_ENTRY_DESCRIPTION_SIZE  = 64,
	FRAME_CONSOLE_COMMAND_SIZE  = 64
};

enum DemoHeader 
{
	netProtocol,
	demoProtocol,
	mapName[HEADER_MAPNAME_SIZE],
	gameDir[HEADER_GAMEDIR_SIZE],
	mapCRC,
	directoryOffset
};

enum DemoEntry 
{
	dirEntryCount,
	type,
	description[DIR_ENTRY_DESCRIPTION_SIZE],
	flags,
	CDTrack,
	trackTime,
	frameCount,
	offset,
	fileLength,
	frames,
	ubuttons /* INT 16 */
};

enum FrameHeader
{
	Type,
	Float:Timestamp,
	Number
}

enum NetMsgFrame 
{
	Float:timestamp,
	Float:view[3],
	viewmodel
}

new iDemoEntry[DemoEntry];
new iDemoHeader[DemoHeader];
new iDemoFrame[FrameHeader];

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public plugin_precache()
{
	kz_bot_flag = register_cvar("kz_bot_flag","1");
	kz_bot_local_wr = register_cvar("kz_bot_local_wr","1");
	kz_bot_kick = register_cvar("kz_bot_kick","1");
	kz_bot_hud = register_cvar("kz_bot_hud","1");
	kz_bot_cooldown = register_cvar("kz_bot_cooldown","5");
	
	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));

	if(file_exists(bot_cfg))
	{
		server_cmd("exec %s", bot_cfg);
		server_exec();
	}
	else
	{
		server_print("[WR_BOT] Config file is not connected, please check.");
	}
	
	static szIP[16];
	get_user_ip( !is_dedicated_server(), szIP, charsmax(szIP));
	
	if(containi(szIP,"loopback") > -1 || containi(szIP,"127.0.0.1") > -1 || strlen(szIP) == 0)
	{
		is_localhost = true;
		set_pcvar_num(kz_bot_flag, 0);
	}
	
	new i;
	for(i = 1; i <= COMMUNITIES; i++)
	{
		if(bFoundDemo)
		{
			break;
		}
		if(file_exists(g_szDemoFiles[i][DEMOS]))
		{
			OnDemosComplete(i, false, true);
		}
		else
		{
			g_NOT_ENOUGH = true;
		}
	}
}
public plugin_init ()
{
	register_plugin( PLUGIN, VERSION , AUTHOR);
	maxplayers = get_maxplayers();
	register_concmd("amx_wrbotmenu", "ClCmd_ReplayMenu");
	register_clcmd( "say /bot","ClCmd_ReplayMenu" );

	if(get_pcvar_num(kz_bot_flag) && !g_NOT_ENOUGH)
	{
		register_forward(FM_AddToFullPack, "addToFullPack", 1);
	}

	new iEnt = -1;
	while( (iEnt = find_ent_by_class(iEnt, "func_door")) )
    {
		if( entity_get_float(iEnt, EV_FL_dmg) < -999.0 )
		{
			HealsOnMap = true;
			break;
		}
    }
	register_event("Damage", "Event_Damage", "b", "1=0", "2>0", "3=0", "4=0", "5=0", "6=0");

	
	SyncHudTimer = CreateHudSyncObj();
	start_buttons = TrieCreate();	
	stop_buttons = TrieCreate();
	
	new const start_names[][] = { "counter_start", "clockstartbutton", "firsttimerelay", "gogogo", "startcounter", "multi_start" };
	new const stop_names[][] = { "counter_off", "clockstopbutton", "clockstop", "stop_counter", "stopcounter", "multi_stop" };
	new i;
	for(i = 0; i < sizeof(start_names); i++)
	{
		TrieSetCell(start_buttons, start_names[i], 1);
	}
	for(i = 0; i < sizeof(stop_names); i++)
	{
		TrieSetCell(stop_buttons, stop_names[i], 1);
	}
	
	new Ent = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString,"info_target" ) );
	
	if(is_localhost)
	{
		register_forward(FM_AddToFullPack,"fw_addtofullpack", 1);
		RegisterHam( Ham_Use, "func_button", "fwdUse", 0);
	}
	set_pev(Ent, pev_classname, "BotThink");
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01 );
	
	register_forward( FM_Think, "fwd_Think", 0 );
	
	fPlayerMoveType  = ArrayCreate( 2 );
	fPlayerAngle  = ArrayCreate( 2 );
	fPlayerOrigin = ArrayCreate( 3 );
	fPlayerVelo   = ArrayCreate( 3 );
	fPlayerKeys   = ArrayCreate( 1 );
	update_file_data = ArrayCreate(32);
	need_update_com = ArrayCreate(COMMUNITIES);
	Founded_Demos = ArrayCreate(64);
	ParseMap(0);
	set_task(5.0, "checkwrs");
}


public checkwrs()
{
	Check_Download_Demos( 1, false, false);
}

public plugin_cfg()
{
	new file;
	if(!dir_exists(dl_dir))
	{
		mkdir(dl_dir);
	}
		
	if(!file_exists(update_file))
	{
		file = fopen(update_file, "w");
		fclose(file);
	}
	
	if(file_size(update_file, 1) < COMMUNITIES)
	{
		delete_file(update_file);
		file = fopen(update_file, "w");
		new line[32];
		for(new data = 1; data <= COMMUNITIES; data++)
		{
			format(line, charsmax(line), "%d 1337%d", data, data);
			write_file(update_file, line, -1);
		}
		fclose(file);
	}
	
	if(!dir_exists(archive_dir))
	{
		mkdir(archive_dir);
	}
	if(!dir_exists(temp_dir))
	{
		mkdir(temp_dir);
	}
	if(!dir_exists(local_demo_folder))
	{
		mkdir(local_demo_folder);
	}
	if(get_pcvar_num(kz_bot_local_wr) == 0)
	{
		rmdir_recursive(local_demo_folder);
	}
	
	//SetTouch();
}


public client_putinserver(id)
{
	g_Connected[id] = true;
	if(get_pcvar_num(kz_bot_kick) && wr_bot_id)
	{
		new Count, Players[32];
		get_players(Players, Count, "h");
		if(Count == maxplayers)
		{
			kick_bot(wr_bot_id);
		}
	}
}

public client_disconnect(id)
{
	g_Connected[id] = false;
	/*if (ChangingLevel)
	{
		return;
	}*/
	if(!wr_bot_id && bFoundDemo && get_pcvar_num(kz_bot_kick))
	{
		new Count, Players[32];
		get_players(Players, Count, "h");
		if(Count < maxplayers)
		{
			set_task( 5.0, "StartCountDown");
		}
	}
	if(id == wr_bot_id)
	{
		timer_time[id] = 0.0;
		IsPaused[wr_bot_id] = false;
		timer_started[wr_bot_id] = false;
		g_bot_enable = 0;
		g_bot_frame = 0;
		wr_bot_id = 0;
		destroy_bot_icon();
	}
}

/*public server_changelevel()
{
	ChangingLevel = true;
}

public plugin_end()
{
	ArrayDestroy(fPlayerMoveType);
	ArrayDestroy(fPlayerAngle);
	ArrayDestroy(fPlayerOrigin);
	ArrayDestroy(fPlayerVelo);
	ArrayDestroy(fPlayerKeys);
	ArrayDestroy(update_file_data);
	ArrayDestroy(need_update_com);
	ArrayDestroy(Founded_Demos);
}
*/

////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////CURL FOR CHECK AND DOWNLOAD DEMOS AND ARCHIVES////////////////////
////////////////////////////////////////Filetype////////////////////////////////////////////
/////////////////////////////// 0 - Demos, 1 - Archive /////////////////////////////////////

public Check_Download_Demos(Community, bool:Download, bool:Filetype)
{
	#if defined DEBUG
		server_print("PARSING CHECK COMMUNITY-%d, DOWNLOAD-%d, FILETYPE-%d", Community, Download ,Filetype );
	#endif
	new data[3];
	data[1] = Community;
	data[2] = Filetype;
	new CURL:curl = curl_easy_init();
	
	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, false);
	curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
	#if defined DEBUG
		//curl_easy_setopt(curl, CURLOPT_VERBOSE, 1);	//CURL ANALYZE OPTION
	#endif
	if(!Filetype)
	{
		curl_easy_setopt(curl, CURLOPT_URL, g_szDemoFiles[Community][URLS]);

		if(Download)
		{
			data[0] = fopen( g_szDemoFiles[Community][DEMOS], "wb");

			
			curl_easy_setopt(curl, CURLOPT_BUFFERSIZE, 512);
			curl_easy_setopt(curl, CURLOPT_WRITEDATA, data[0]);
			curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write");
		}		
		else
		{
			curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10);
			curl_easy_setopt(curl, CURLOPT_NOBODY, 1);	
			curl_easy_setopt(curl, CURLOPT_FILETIME, 1);
			curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write_null");
		}
	}
	else
	{
		static archivefile[128];
		format (archivefile, charsmax(archivefile), "%s/%s.rar", archive_dir, iArchiveName );	
		
		data[0] = fopen(archivefile, "wb");

		static Link[128];
		format(Link, charsmax(Link), "%s/%s.rar", g_szDemoFiles[Community][LINK], iArchiveName);
			
		#if defined DEBUG
			server_print("[LINK] : %s", Link);
		#endif
		
		curl_easy_setopt(curl, CURLOPT_URL, Link);
		curl_easy_setopt(curl, CURLOPT_BUFFERSIZE, 512);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, data[0]);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write");
	}
	curl_easy_perform(curl, "complete", data, sizeof(data));
}

public write(data[], size, nmemb, file)
{
	new actual_size = size * nmemb;
	fwrite_blocks(file, data, actual_size, BLOCK_CHAR);
	return actual_size;
}

public write_null(data[], size, nmemb, file)
{
	new actual_size = size * nmemb;		
	return actual_size;
}

public complete(CURL:curl, CURLcode:code, data[])
{	
	new Community = data[1];
	static filetime, iResponceCode;
	curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, iResponceCode);
	curl_easy_getinfo(curl, CURLINFO_FILETIME, filetime);
	curl_easy_cleanup(curl);
	
	new comm[64];

	if(data[0])
	{
		fclose(data[0]);
	}
	else	
	{
		if(iResponceCode == 0 && filetime == -1)
		{
			#if defined DEBUG
				server_print("Can't Connect to %s", g_szDemoFiles[Community][NAME]);
			#endif
			set_task (1.0, "UpdateComplete");
			return;
		}
		#if defined DEBUG
			server_print("Connection to %s successfull", g_szDemoFiles[Community][NAME]);
		#endif
		new com, dat;
		new Line[32], ExplodedString[3][33], newLine[32];
				
		new recordsfile  = fopen( update_file, "rb" );
		while (!feof(recordsfile))
		{
			fgets (recordsfile, Line, charsmax(Line));
			ExplodeString(ExplodedString, 2, 32, Line, ' ');
			
			if(strlen(Line) > 0) {

			
				com = str_to_num(ExplodedString[0]);
				dat = str_to_num(ExplodedString[1]);

				
				if(com == Community && dat)
				{
					if((filetime != dat && filetime > 0) || file_exists( g_szDemoFiles[Community][DEMOS]) == 0)
					{
						dat = filetime;
						ArrayPushCell(need_update_com, Community);
					}
					format(newLine, charsmax(newLine), "%d %d", Community, dat);
					ArrayPushString(update_file_data, newLine);				
				}
			}
		}
		fclose(recordsfile);
		if(Community == COMMUNITIES)
		{
			g_Check_Filetime = true;
			new i_size = ArraySize(need_update_com);
			if(i_size)
			{
				bFoundDemo = false;
				g_Check_Files = i_size;
				delete_file(update_file);
				new file = fopen(update_file, "w");
				for(new i = 0; i  < COMMUNITIES; i++)
				{
					ArrayGetString(update_file_data, i, comm, charsmax(comm));
					write_file(update_file, comm, i);
				}
				fclose(file);
			}
		}
		else
		{
			Check_Download_Demos(Community + 1, false, false);
			return;
		}
	}
	if(g_Check_Filetime)
	{
		if(g_Check_Files > 0)
		{
			#if defined DEBUG
				server_print("UpdateNeeded() - %d", g_Check_Files);
			#endif
			new upd;
			upd = ArrayGetCell(need_update_com, g_Check_Files - 1);
			g_Check_Files--;
			Check_Download_Demos(upd, true, false);
			return;
		}
		else
		{
			g_Check_Filetime = false;
			set_task (1.0, "UpdateComplete");
			return;
		}
	}
	if(data[2])
	{
		static filename[128];
		format( filename, charsmax( filename ), "%s/%s.rar", archive_dir, iArchiveName);
		
		if (iResponceCode > 399 && !CheckAgain)
		{
			delete_file(filename);
			bFoundDemo = false;
			CheckAgain = true;
			#if defined DEBUG
				server_print("[ERROR] : iResponceCode: %d", iResponceCode);
			#endif
			
			OnDemosComplete(Community, true, true);
			return;
			
		}
		else if (iResponceCode > 399 && CheckAgain)
		{
			delete_file(filename);
			server_print("*No World Record on this map!");
		}
		else
		{
			if(iResponceCode > 0)
			{
				CheckAgain = false;
				#if defined DEBUG
					server_print("[COMPLETE] : iResponceCode: %d - file: %s", iResponceCode, filename);
				#endif
				DownloadArchiveComplete(filename);
				return;
			}
		}
	}
}
public UpdateComplete()
{
	#if defined DEBUG
		server_print("UpdateComplete()");
	#endif
	if(!bFoundDemo)
	{
		new i;
		for(i = 1; i <= COMMUNITIES; i++)
		{
			if(bFoundDemo)
			{
				break;
			}
			OnDemosComplete(i, false, true);
		}
	}
	if(bFoundDemo)
	{
		OnDemosComplete(g_FOUNDED_COMMUNITY, true, false);
	}
	else	
	{
		server_print("*No WR on this map!");
	}
}

public OnDemosComplete(Community, Play_Bot, Check)
{
	#if defined DEBUG
		server_print("OnDemosComplete()");
	#endif
	
	if(Check)
	{
		#if defined DEBUG
			server_print( "Parsing %s Demo List", g_szDemoFiles[Community][NAME]);
		#endif
		
		new iDemosList  = fopen( g_szDemoFiles[Community][DEMOS], "rb" );
		new ExplodedString[7][64];
		new Line[64], Extens[32], Mapa[32], PlayerName[64], DLMap[64];
		new Float:BestTime = 10000000.0;

		if (iDemosList)
		{
			new parsedmap[64];
			new Float:Time;
		
			while ( !feof( iDemosList ) )
			{
				fgets(iDemosList, Line, charsmax(Line));
				ExplodeString(ExplodedString, 6, 63, Line, ' ');
				
				
				parsedmap = ExplodedString[0];
				trim(parsedmap);
		
				if (containi(parsedmap, g_szCurrentMap ) == 0 )
				{			
					Time = str_to_float( ExplodedString[1]);
					split(parsedmap, Mapa, charsmax(Mapa), Extens, charsmax(Extens), "[");
					trim(Mapa);
					trim(Extens);
					if(equali(Mapa, g_szCurrentMap))
					{
						if(Time < BestTime &&  Time > 0.0)
						{	
							BestTime = Time;
							if(containi(parsedmap, "[" ) > -1)
							{
								formatex( DLMap, charsmax( Mapa ), "%s[%s", Mapa, Extens );
								
								if(CheckAgain)
								{
									strtolower(DLMap);
								}
							}
							else {
								formatex( DLMap, charsmax( DLMap ), "%s", Mapa );
								
								if(CheckAgain)
								{
									strtolower(DLMap);
								}
							}
							formatex(PlayerName, charsmax(PlayerName), ExplodedString[2]);
							trim(PlayerName);
							
							formatex(FLAG, charsmax(FLAG), "%s", ExplodedString[3]);
							trim(FLAG);
							
							#if defined DEBUG
								server_print("Parsedmap |%s|", DLMap);
							#endif
							
							bFoundDemo = true;
							g_FOUNDED_COMMUNITY = Community;
						}
					}
				}
				if ((containi(parsedmap, g_szCurrentMap) == -1) && bFoundDemo)
				{
					break;
				}
			}
			
			fclose(iDemosList);
			
			if(bFoundDemo)
			{
				new sWRTime[24];
				fnConvertTime( BestTime, sWRTime, charsmax( sWRTime ) );

				format( iArchiveName, charsmax( iArchiveName ), "%s_%s_%s", DLMap, PlayerName, sWRTime );
				
				format( iNavName, charsmax(iNavName), "%s/%s.nav", local_demo_folder, iArchiveName );
				if(!Play_Bot)
					format( Old_iNavName, charsmax(Old_iNavName), "%s/%s.nav", local_demo_folder, iArchiveName );
				
				StringTimer(BestTime, WR_TIME, charsmax(WR_TIME) - 1);
				format( WR_NAME, charsmax(WR_NAME), PlayerName);

				format( WR_PREFIX, sizeof(WR_PREFIX), g_szDemoFiles[Community][BOT]);

				#if defined DEBUG
					server_print("Archivename %s", iArchiveName);
				#endif
			}

			if(!Play_Bot && bFoundDemo && get_pcvar_num(kz_bot_flag) && !g_NOT_ENOUGH && !Prechached)
			{
				parsing_country();
			}
		}
	}
	if(Play_Bot)
	{
		if(file_exists(Old_iNavName) && equal(Old_iNavName, iNavName)) 
		{
			#if defined DEBUG
				server_print("Call LoadParsedInfo()");
			#endif

			LoadParsedInfo( iNavName );
		}
		else if(bFoundDemo)
		{
			if(file_exists(Old_iNavName))
			{
				delete_file(Old_iNavName);
			}
			
			#if defined DEBUG
				server_print("Call Check_Download_Demos()");
			#endif
			Check_Download_Demos(Community, true, true);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////AMXXARCH FOR UNARCHIVE RAR FILES//////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public DownloadArchiveComplete(Archive[])
{
	#if defined DEBUG
		server_print("DownloadArchiveComplete()");
	#endif
	format( RARArchive, charsmax( RARArchive ), "%s", Archive);
	AA_Unarchive(RARArchive, temp_dir, "@OnComplete", 0);
}

@OnComplete(id, iError)
{
	#if defined DEBUG
		server_print("OnComplete()");
	#endif

	if(iError != AA_NO_ERROR)
	{
		#if defined DEBUG
			server_print("Failed to unpack. Error code: %d", iError);
		#endif
	}
	else
	{
		#if defined DEBUG
			server_print("Done. Download & Unpack WR file!");
		#endif

		delete_file(RARArchive);
		
		format( iDemoName, sizeof(iDemoName), "%s/%s.dem", temp_dir, iArchiveName );
		if ( !file_exists( iNavName ) )
		{
			iFile = fopen( iDemoName, "rb" );
			if ( iFile )
			{
				iParsedFile = fopen( iNavName, "w" );
				ReadHeaderX();
	
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public fwdUse(ent, id)
{
	if(is_user_bot(id) || !ent || id > 32 || !is_user_alive(id))
	{
		return HAM_IGNORED;
	}
	new szTarget[32];
	pev( ent, pev_target, szTarget, 31 );
	if ( TrieKeyExists( start_buttons, szTarget ) )
	{
		if(start_on_use[id] && wr_bot_id)
		{
			Start_Bot();
		}
	}
	return HAM_IGNORED;
}

public CheckButton(id)
{
	new Float:origin[3], Float:eorigin[3],  Float:Distance[2];
	pev( id, pev_origin, origin );
	new ent = -1;
	new szTarget[32], classname[32];

	while ( (ent = find_ent_in_sphere( ent, origin, 100.0 ) ) != 0 )
	{
		pev( ent, pev_classname, classname, charsmax( classname ) );

		get_brush_entity_origin( ent, eorigin );

		pev( ent, pev_target, szTarget, 31 );

		if ( TrieKeyExists( start_buttons, szTarget ) )
		{
			if(finish_time[id] && get_gametime() - finish_time[id] < 0.33) //some maps finish button bug
			{
				return;
			}
			if ( vector_distance( origin, eorigin ) >= Distance[0] && (get_gametime() - timer_time[id] > 0.5))
			{
				g_bot_start_use = g_bot_frame - 1;
				timer_time[id] = get_gametime();
				IsPaused[id] = false;
				timer_started[id] = true;
			}
			Distance[0] = vector_distance( origin, eorigin );
		}
		if ( TrieKeyExists( stop_buttons, szTarget ) )
		{
			if ( vector_distance( origin, eorigin ) >= Distance[1] )
			{
				if (timer_started[id])
				{
					timer_started[id] = false;
					if(!Countdown)
					{
						StartCountDown();
					}
					g_bot_stop_use = g_bot_frame;
					finish_time[id] = get_gametime();
				}
			}

			Distance[1] = vector_distance( origin, eorigin );
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////Damage/////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////



public Event_Damage(id) {
	if(id == wr_bot_id)
	{	
		if(!HealsOnMap)
		{
			new Dead[32], deadPlayers;
			get_players(Dead, deadPlayers, "bh");
			new specmode, target; 
			for(new i=0;i<deadPlayers;i++)
			{
				specmode = pev(Dead[i], pev_iuser1);
				if(specmode == 2 || specmode == 4)
				{
					target = pev(Dead[i], pev_iuser2);
					if(is_user_alive(target))
					{
						if (target == wr_bot_id && g_Connected[Dead[i]])
						{
							client_print(Dead[i], print_chat , "Bot lost %d HP", read_data(2));
						}
					}
				}
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////TIMER//////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////


public Pause()
{
	if(!IsPaused[wr_bot_id])
	{
		g_pausetime[wr_bot_id] = get_gametime() - timer_time[wr_bot_id];
		timer_time[wr_bot_id] = 0.0;
		IsPaused[wr_bot_id] = true;
		g_bot_enable = 2;
	}
	else
	{
		if(timer_started[wr_bot_id])
		{
			timer_time[wr_bot_id] = get_gametime() - g_pausetime[wr_bot_id];
		}
		IsPaused[wr_bot_id] = false;
		g_bot_enable = 1;
	}
}

public fwd_Think( iEnt )
{
	if ( !pev_valid( iEnt ) )
	{
		return(FMRES_IGNORED);
	}
	static className[32];
	pev( iEnt, pev_classname, className, 31 );

	if ( equal( className, "DemThink" ) )
	{
		for(new i = 0; i < NUM_THREADS; i++)
		{
			if(ReadFrames(iFile))
			{
				Dem_Finished = true;
				break;
			}
		}

		if(Dem_Finished)
		{
			fclose(iParsedFile);
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME);
			fclose( iFile );
			if(!Called_Other)
			{
				delete_file( iDemoName);
			}
			LoadParsedInfo( iNavName );
		}
		else
		{
			set_pev( iEnt, pev_nextthink, get_gametime() + 0.001 );
		}
	}
	if ( equal( className, "NavThink" ) )
	{
		for(new i = 0; i < NUM_THREADS; i++)
		{
			if(!ReadParsed(iEnt))
			{
				Nav_Finished = true;
				break;
			}
		}

		if(Nav_Finished)
		{
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME);
			fclose( iFile );
			set_task( 2.0, "StartCountDown");
		}
	}
	if ( equal( className, "BotThink" ) )
	{
		BotThink( wr_bot_id );
		set_pev( iEnt, pev_nextthink, get_gametime() + next_think );
	}
	
	
	new Dead[32], deadPlayers;
	static Float:ftime;
	static sz_time[12];
	static Timer;
	if(g_bot_start_use)
	{
		Timer = (g_bot_frame - g_bot_start_use);
		ftime = float(Timer) / 100;
	}
	fnConvertTime( ftime, sz_time, charsmax( sz_time ) );
	static Pause_Status[12];
	if(IsPaused[wr_bot_id])
	{
		formatex(Pause_Status, charsmax(Pause_Status), "| *Paused*");
	}
	else
	{
		Pause_Status = "";
	}
	get_players(Dead, deadPlayers, "bh");
	new specmode, target; 
	for(new i=0;i<deadPlayers;i++)
	{
		specmode = pev(Dead[i], pev_iuser1);
		if(specmode == 2 || specmode == 4)
		{
			target = pev(Dead[i], pev_iuser2);
			if(is_user_alive(target))
			{
				if ((timer_started[target] && target == wr_bot_id) && g_Connected[Dead[i]])
				{
					if(ftime > 0.0)
					{
						client_print( Dead[i], print_center, "[ %.2s:%.2s.%.2s ] %s", sz_time, sz_time[2], sz_time[5], Pause_Status);
					}
				}
			}
		}
	}
	
	return(FMRES_IGNORED);
}

public BotThink( id )
{
	static Float:MoveType[2], Float:ViewOrigin[3], Float:ViewAngle[3], Float:ViewVelocity[3], ViewKeys;
	
	static Float:last_check, Float:game_time, nFrame;
	game_time = get_gametime();

	if( game_time - last_check > 1.0 && !is_localhost)
	{
		if (nFrame < 100)
		{
			next_think = next_think - 0.0001;
		}
		if (nFrame > 100)
		{
			next_think = next_think + 0.0001;
		}
		nFrame = 0;
		last_check = game_time;
	}
	if(g_bot_enable == 1 && wr_bot_id)
	{
		g_bot_frame++;
		if ( g_bot_frame < ArraySize( fPlayerAngle ) )
		{
			ArrayGetArray( fPlayerOrigin, g_bot_frame, ViewOrigin );
			ArrayGetArray( fPlayerMoveType, g_bot_frame, MoveType );
			ArrayGetArray( fPlayerAngle, g_bot_frame, ViewAngle );
			ArrayGetArray( fPlayerVelo, g_bot_frame, ViewVelocity);
			ViewKeys = ArrayGetCell( fPlayerKeys, g_bot_frame );
			#define InMove (ViewKeys & IN_FORWARD || ViewKeys & IN_LEFT || ViewKeys & IN_RIGHT || ViewKeys & IN_BACK)

			new flag = pev(id, pev_flags);
			
			if (flag&FL_ONGROUND)
			{
				if ( ViewKeys & IN_DUCK && InMove )
				{
					set_pev( id, pev_gaitsequence, 5 );
				}
				else if ( ViewKeys & IN_DUCK )
				{
					set_pev( id, pev_gaitsequence, 2 );
				}
				else  
				{
					set_pev( id, pev_gaitsequence, 4 );
				}
				if ( ViewKeys & IN_JUMP )
				{
					set_pev( id, pev_gaitsequence, 6 );
				}
				else  
				{
					set_pev( id, pev_gaitsequence, 4 );
				}
			}
			else  
			{
				set_pev( id, pev_gaitsequence, 6 );
				if ( ViewKeys & IN_DUCK )
				{
					set_pev( id, pev_gaitsequence, 5 );
				}
			}
			if ( ViewKeys & IN_USE )
			{
				CheckButton(id);
				ViewKeys &= ~IN_USE;
			}
						
			ViewAngle[2] = 0.0;
			set_pev( id, pev_v_angle, ViewAngle );
			ViewAngle[0] /= -3.0;
			//set_pev(id, pev_movetype, MOVETYPE_NONE);
			set_pev(id, pev_angles, ViewAngle);
			set_pev(id, pev_fixangle, 1 );
			engfunc(EngFunc_RunPlayerMove, id, ViewAngle, MoveType[0], MoveType[1], 0.0, ViewKeys, 0, 10);

			set_pev(id, pev_velocity, ViewVelocity);
			set_pev(id, pev_origin, ViewOrigin);
			set_pev(id, pev_button, ViewKeys );
			set_pev(id, pev_maxspeed, 250.0);		//usp & knife only
		
						
			if(is_user_alive(id) && is_user_bot(id))
			{
				new hp = get_user_health(id);
				if(hp < 9999)
				{
					set_user_health ( id, 999999);
				}
				set_pev(id, pev_solid, SOLID_NOT);
			}
			if(g_bot_frame >= ArraySize(fPlayerAngle))
			{
				StartCountDown();
				return;
			}
		}
		else  
		{
			StartCountDown();
			g_bot_frame = 0;
			nFrame = 0;
			return;
		}
	}
	nFrame++;
}

/*
GaitSequence = 1 = Idle
GaitSequence = 2 = Duck
GaitSequence = 3 = Walk
GaitSequence = 4 = Run
GaitSequence = 5 = Duck + Walk
GaitSequence = 6 = Jump 
*/
//	EngFunc_RunPlayerMove,	// void )(edict_t *fakeclient, const float *viewangles, float forwardmove, float sidemove, float upmove, unsigned short buttons, byte impulse, byte msec);
////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////MENU//////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public ClCmd_ReplayMenu(id)
{
	if(!access(id, KZ_ADMIN_LEVEL))
	{
		return PLUGIN_HANDLED;
	}
	new title[128];
	formatex(title, charsmax(title), "\wBot Settings");
	new menu = menu_create(title, "ReplayMenu_Handler");
	menu_additem(menu, "Start/Reset", "1");

	if (g_bot_enable == 1)
	{
	   menu_additem(menu, "Pause", "2");
	}
	else
	{
		menu_additem(menu, "Play", "2");
	}

	menu_additem(menu, "Kick bot", "3");
	menu_additem(menu, "Other bot", "4");
	menu_additem(menu, "Fast Forward", "5");
	menu_additem(menu, "Fast Backward", "6");
	new Intval[32];
	formatex(Intval , charsmax(Intval), "Interval: \y%d\w sec^n", Interval / 100);
	menu_additem(menu, Intval , "7");
	
	if(is_localhost)
	{
		new msg[32];
		formatex(msg, charsmax(msg), "Restart on USE: %s^n", start_on_use[id] ? "\yOn" : "\rOff" );
		menu_additem( menu, msg, "8" );
	}
	else
	{
		menu_addblank(menu, 1);
	}
	
	menu_addblank(menu, 1);
	menu_additem(menu, "Exit", "0");
	menu_setprop(menu, MPROP_PERPAGE, 0);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);

	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public Use_Mode(id)
{
	if(!start_on_use[id]) 
	{
		start_on_use[id] = true;
		g_start_on_use = true;
		client_print(id, print_chat, "Restart on use enabled");
	}
	else
	{
		g_start_on_use = false;
		start_on_use[id] = false;
		client_print(id, print_chat, "Restart on use disabled");
	}
	return PLUGIN_HANDLED;
}

public ReplayMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		return PLUGIN_HANDLED;
	}
	switch(item)
	{
		case 0:
		{
			if(!wr_bot_id)
			{
				StartCountDown();
			}
			else
			{
				if(IsPaused[wr_bot_id])
				{
					IsPaused[wr_bot_id] = false;
					g_bot_enable = 1;
				}
				Start_Bot();
			}
			
		}
		case 1:
		{
				Pause();
		}		
		case 2:
		{
			kick_bot(wr_bot_id);
		}
		case 3:
		{
			ArrayClear(Founded_Demos);
			Call_Parse = true;
			ParseMap(id);
			return PLUGIN_HANDLED;
		}
		case 4:
		{
			if(g_bot_frame + Interval < ArraySize(fPlayerAngle))
			{
				g_bot_frame += Interval;
			}
			if(g_bot_stop_use && g_bot_frame > g_bot_stop_use)
			{
				g_bot_frame = 0;
			}
		}	
		case 5:
		{
			g_bot_frame -= Interval;
			if(g_bot_frame < 0)
			{
				g_bot_frame = 0;
			}
		}
		case 6:
		{
			if(Interval < 3000)
			{
				Interval += 1000;
			}
			else
			{
				Interval = 1000;
			}
		}	
		case 7:
		{
			Use_Mode(id);
		}
	}
	ClCmd_ReplayMenu(id);
	return PLUGIN_HANDLED;
}



public ParseMenu(id)
{

	new title[128], demoname[128];
	formatex(title, charsmax(title), "\wBot Settings");
	new menu = menu_create(title, "ParseMenu_Handler");
	if(a_Size)
	{
		for ( new i = 0; i < a_Size; i++ )
		{
			ArrayGetString(Founded_Demos, i, demoname, charsmax(demoname));
			menu_additem( menu, demoname, "", 0);
		}
	}
	else
	{
		menu_additem(menu, "Demo not founded for this map", "1");
	}
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public ParseMenu_Handler(id, menu, item)
{
	new demoname[128];
	if(item == MENU_EXIT)
	{
		ClCmd_ReplayMenu(id);
		return PLUGIN_HANDLED;
	}
	if(a_Size)
	{
		Dem_Finished = false;
		Nav_Finished = false;
		Called_Other = true;
		
		ArrayGetString(Founded_Demos, item, demoname, charsmax(demoname));
		client_print(id, print_chat, "Trying to parse and play demo: %s", demoname);
		ArrayClear(fPlayerMoveType);
		ArrayClear(fPlayerAngle);
		ArrayClear(fPlayerOrigin);
		ArrayClear(fPlayerVelo);
		ArrayClear(fPlayerKeys);
		
		kick_bot(wr_bot_id);

		format( iNavName, charsmax(iNavName), "%s/%s.nav", local_demo_folder, demoname );
		format( iDemoName, sizeof(iDemoName), "%s.dem", demoname );
		if ( !file_exists( iNavName ) )
		{
			iFile = fopen( iDemoName, "rb" );
			if ( iFile )
			{
				iParsedFile = fopen( iNavName, "w" );
				ReadHeaderX();

			}
		}
		else
		{
			LoadParsedInfo( iNavName );
		}
	}
	else
	{
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}


////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////BOT///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////


Create_Bot()
{
	new Count, Players[32];
	get_players(Players, Count, "h");
	if(Count == maxplayers || (Count == maxplayers - 1 && get_pcvar_num(kz_bot_kick)))
	{
		server_print( "Couldn't create a bot, server full? Players - %d, Maxplayers - %d, Cvar kz_bot_kick - %d", Count, maxplayers, get_pcvar_num(kz_bot_kick));
		return 0;
	}
	static name[64];
	if(Called_Other)
	{
		new dem[64], ext[2];
		split(iDemoName, dem, charsmax(dem), ext, charsmax(ext), ".dem");

		formatex(name, charsmax(name), "%s", dem);
	}
	else
	{
		formatex(name, charsmax(name), "[WR] %s %s", WR_NAME, WR_TIME);
	}
	new id = engfunc(EngFunc_CreateFakeClient, name);
	//engfunc( EngFunc_FreeEntPrivateData, id );

	set_user_info(id, "model", "gordon" );
	set_user_info(id, "rate", "3500");
	set_user_info(id, "cl_updaterate", "30");
	set_user_info(id, "cl_cmdrate", "60");
	set_user_info(id, "cl_lw", "0");
	set_user_info(id, "cl_lc", "0");
	set_user_info(id, "cl_dlmax", "128");
	set_user_info(id, "cl_righthand", "0");
	set_user_info(id, "ah", "1");
	set_user_info(id, "dm", "0");
	set_user_info(id, "tracker", "0");
	set_user_info(id, "friends", "0");
	
	set_user_info(id, "*bot", "1");
	set_user_info(id, "_cl_autowepswitch", "1" );
	set_user_info(id, "_vgui_menu", "0" );
	set_user_info(id, "_vgui_menus", "0");
	
	static szRejectReason[128];
	dllfunc(DLLFunc_ClientConnect, id, "WR BOT", "127.0.0.1" , szRejectReason);
	if ( !is_user_connected( id ) )
	{
		server_print( "Connection rejected: %s", szRejectReason );
		return 0;
	}
	
	dllfunc(DLLFunc_ClientPutInServer, id);
	set_pev( id, pev_spawnflags, pev( id, pev_spawnflags ) | FL_FAKECLIENT );
	set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT);

	cs_set_user_team(id, CS_TEAM_CT);
	cs_set_user_model(id, "sas");

	cs_set_user_bpammo(id, CSW_USP, 250);
	if(get_pcvar_num(kz_bot_flag) && !g_NOT_ENOUGH) 
	{
		create_bot_icon(id);
	}
	//if(!is_user_alive(id)) dllfunc(DLLFunc_Spawn, id);
	//ExecuteHamB( Ham_CS_RoundRespawn, id );
	
	cs_user_spawn(id);
	give_item(id,"weapon_knife");
	give_item(id,"weapon_usp");
	//set_user_godmode( id, 1 );

	return id;
}

////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////TIMER/////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public StartCountDown()
{
	Countdown = true;
	if(!wr_bot_id)
	{
		wr_bot_id = Create_Bot();
	}
	if(wr_bot_id && get_pcvar_num(kz_bot_hud))
	{
		g_timer = get_pcvar_num(kz_bot_cooldown);
		set_task(1.0, "Show");
	}
}

public Show()
{
	set_hudmessage(255, 255, 255, 0.05, 0.2, 0, 6.0, 1.0);

	if(g_timer && g_timer >= 0)
	{
		ShowSyncHudMsg( 0, SyncHudTimer, "WR bot starts run in: %i sec", g_timer);
		set_task(1.0, "Show");
		g_timer--;
	}
	else 
	{
		Countdown = false;
		g_bot_enable = 1;
		Start_Bot();
	}
}

Start_Bot()
{
	if(g_start_on_use)
	{
		g_bot_frame = g_bot_start_use - 1;
	}
	else
	{
		g_bot_frame = 0;
	}
	if(get_pcvar_num(kz_bot_hud))
	{
		set_hudmessage(255, 255, 255, 0.05, 0.2, 0, 6.0, 1.0);
		ShowSyncHudMsg( 0, SyncHudTimer, "Bot has started");
	}
	timer_started[wr_bot_id] = false;

}

////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////BOT ICON//////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public create_bot_icon(id)
{
	g_Bot_Icon_ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"));

	if(file_exists(url_sprite))
	{
		engfunc(EngFunc_SetModel, g_Bot_Icon_ent, url_sprite);
	}
	else if(file_exists(url_sprite_xz))
	{
		engfunc(EngFunc_SetModel, g_Bot_Icon_ent, url_sprite_xz);
	}
	else
	{
		return;
	}
	set_pev(g_Bot_Icon_ent, pev_solid, SOLID_NOT);
	set_pev(g_Bot_Icon_ent, pev_movetype, MOVETYPE_FLYMISSILE);
	set_pev(g_Bot_Icon_ent, pev_iuser2, id);
	set_pev(g_Bot_Icon_ent, pev_scale, 0.25);
}

destroy_bot_icon()
{
	if(g_Bot_Icon_ent)
	{
		engfunc(EngFunc_RemoveEntity, g_Bot_Icon_ent);
	}
	g_Bot_Icon_ent = 0;
}

public fw_addtofullpack(es_handle,e,ent,host,hostflags,player,pSet)
{
	if(wr_bot_id == host)
	{		
		return FMRES_IGNORED;
	}
	if(player)
	{		
		if(wr_bot_id == ent)
		{
			if(is_user_alive(host))
			{
				set_es es_handle, ES_RenderMode, kRenderTransAlpha ;
				set_es es_handle, ES_RenderAmt, floatround(entity_range(host, ent) * 255.0 / 400.0, floatround_floor) ;
			}
			else
			{
				set_es(es_handle, ES_RenderAmt, 150.0);
			}
			return FMRES_SUPERCEDE;
		}
	} 	
	return FMRES_IGNORED;
}


public addToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if(wr_bot_id == host)
	{
		return FMRES_IGNORED;
	}
	if(wr_bot_id)
	{
		if(pev_valid(ent) && (pev(ent, pev_iuser1) == pev(ent, pev_owner)))
		{
			new user = pev(ent, pev_iuser2);
			new specmode = pev(host, pev_iuser1);

			if(is_user_alive(user))
			{
				new Float: playerOrigin[3];
				pev(user, pev_origin, playerOrigin);
				playerOrigin[2] += 42;
				engfunc(EngFunc_SetOrigin, ent, playerOrigin);

				if(specmode == 4)
				{
					set_es(es, ES_Effects, EF_NODRAW);
				}
			}
		}
	}
	return FMRES_IGNORED;
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////LOAD//READ//PARSE///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public LoadParsedInfo(szNavName[])
{
	iFile = fopen( szNavName, "rb" );
	
	new iEntity = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString,"info_target" ) );
	set_pev(iEntity, pev_classname, "NavThink");
	set_pev(iEntity, pev_nextthink, get_gametime() + 0.01 );
	
}

public ReadHeaderX()
{
	if (IsValidDemoFile( iFile ))
	{
		ReadHeader( iFile );
		
		new iEntity = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString,"info_target" ) );
		set_pev(iEntity, pev_classname, "DemThink");
		set_pev(iEntity, pev_nextthink, get_gametime() + 0.01 );
	} 
	else 
	{
		server_print( "NOTVALID" );
	}
}

public bool:IsValidDemoFile( file )
{
	fseek( file, 0, SEEK_END );
	iDemo_header_size = ftell( file );
	if ( iDemo_header_size < HEADER_SIZE )
	{
		return(false);
	}
	fseek( file, 0, SEEK_SET );
	new signature[HEADER_SIGNATURE_CHECK_SIZE];
	fread_blocks( file, signature, sizeof(signature), BLOCK_CHAR );

	if ( !contain( "HLDEMO", signature ) )
	{
		return(false);
	}

	return(true);
}


public ReadHeader( file )
{
	fseek( file, HEADER_SIGNATURE_SIZE, SEEK_SET );

	fread( file, iDemoHeader[demoProtocol], BLOCK_INT );

	if ( iDemoHeader[demoProtocol] != 5 )
	{
		//do what ?
	}

	fread( file, iDemoHeader[netProtocol], BLOCK_INT );

	if ( iDemoHeader[netProtocol] != 48 )
	{
		//do what ?
	}
	fread_blocks( file, iDemoHeader[mapName], HEADER_MAPNAME_SIZE, BLOCK_CHAR );
	fread_blocks( file, iDemoHeader[gameDir], HEADER_GAMEDIR_SIZE, BLOCK_CHAR );

	fread( file, iDemoHeader[mapCRC], BLOCK_INT );
	fread( file, iDemoHeader[directoryOffset], BLOCK_INT );

	fseek( file, iDemoHeader[directoryOffset], SEEK_SET );

	new newPosition = ftell( file );

	if ( newPosition != iDemoHeader[directoryOffset] )
	{		  
		/*server_print( "kek :(" );*/
	}
	fread( file, iDemoEntry[dirEntryCount], BLOCK_INT );
	for ( new i = 0; i < iDemoEntry[dirEntryCount]; i++ )
	{
		fread( file, iDemoEntry[type], BLOCK_INT );
		fread_blocks( file, iDemoEntry[description], DIR_ENTRY_DESCRIPTION_SIZE, BLOCK_CHAR );
		fread( file, iDemoEntry[flags], BLOCK_INT );
		fread( file, iDemoEntry[CDTrack], BLOCK_INT );
		fread( file, iDemoEntry[trackTime], BLOCK_INT );
		fread( file, iDemoEntry[frameCount], BLOCK_INT );
		fread( file, iDemoEntry[offset], BLOCK_INT );
		fread( file, iDemoEntry[fileLength], BLOCK_INT );		
	}
	
	fseek( file, iDemoEntry[offset], SEEK_SET );
}

public ReadParsed( iEnt )
{
	if (iFile)
	{
		new szLineData[128];
		new sExplodedLine[12][16];
		if ( !feof( iFile ) )
		{
			fseek(iFile, 0, SEEK_CUR);
			new iSeek = ftell(iFile);
			fseek(iFile, 0, SEEK_END);
			fseek(iFile, iSeek, SEEK_SET);

			fgets( iFile, szLineData, charsmax( szLineData ) );

			ExplodeString( sExplodedLine, 12, 15, szLineData, '|' );
			if (equal( sExplodedLine[0], "ASD" ))
			{
				new Keys        = str_to_num( sExplodedLine[1] );
				new Float:Angles[3];
				Angles[0]   = str_to_float( sExplodedLine[2] );
				Angles[1]   = str_to_float( sExplodedLine[3] );
				new Float:Origin[3];
				Origin[0]   = str_to_float( sExplodedLine[4] );
				Origin[1]   = str_to_float( sExplodedLine[5] );
				Origin[2]   = str_to_float( sExplodedLine[6] );
				new Float:velocity[3];
				velocity[0] = str_to_float( sExplodedLine[7] );
				velocity[1] = str_to_float( sExplodedLine[8] );
				velocity[2] = str_to_float( sExplodedLine[9] );
				new Float:movetype[2];
				movetype[0] = str_to_float( sExplodedLine[10] );
				movetype[1] = str_to_float( sExplodedLine[11] );
				ArrayPushArray( fPlayerAngle, Angles );
				ArrayPushArray( fPlayerOrigin, Origin );
				ArrayPushArray( fPlayerVelo, velocity );
				ArrayPushCell( fPlayerKeys, Keys );
				ArrayPushArray( fPlayerMoveType, movetype );
			}
			set_pev( iEnt, pev_nextthink, get_gametime()+0.0001 );
			return true;
		}
		else
		{
			return false;
		}
	}

	return false;
}


public ReadFrames(file)
{
	if ( !feof( file ) )
	{
		new FrameType = ReadFrameHeader(file);
		new bool:breakme;		
		new Float:Origin[3], Float:ViewAngles[2], Float:velocity[3], iAsd[256];
		new Float:movetype[2];
		switch (FrameType)
		{
		case 0:
			{				
			}
		case 1:
			{				
				static length;	
				fseek( file, 92, SEEK_CUR );
				fread( file, _:velocity[0], BLOCK_INT );
				fread( file, _:velocity[1], BLOCK_INT );
				fread( file, _:velocity[2], BLOCK_INT );
				fread( file, _:Origin[0], BLOCK_INT );
				fread( file, _:Origin[1], BLOCK_INT );
				fread( file, _:Origin[2], BLOCK_INT );
				fseek( file, 124, SEEK_CUR );
				fread( file, _:ViewAngles[0], BLOCK_INT );
				fread( file, _:ViewAngles[1], BLOCK_INT );
				fseek( file, 4, SEEK_CUR );
				fread( file, _:movetype[0], BLOCK_INT );
				fread( file, _:movetype[1], BLOCK_INT );				
				fseek( file, 6, SEEK_CUR );
				fread( file, iDemoEntry[ubuttons], BLOCK_SHORT );
				fseek( file, 196, SEEK_CUR );
				fread( file, length, BLOCK_INT );
				fseek( file, length, SEEK_CUR );
				formatex( iAsd, charsmax( iAsd ), "ASD|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.1f|%.1f^n", iDemoEntry[ubuttons], ViewAngles[0], ViewAngles[1], Origin[0],Origin[1],Origin[2], velocity[0], velocity[1], velocity[2], movetype[0], movetype[1]);
				fputs( iParsedFile, iAsd );
			}
		case 2:
			{
			}
		case 3:
			{
				fseek( file, 64, SEEK_CUR);
			}
		case 4:
			{
				
				fseek( file, 32, SEEK_CUR );

			}
		case 5:
			{
				breakme = true;
			}
		case 6:
			{
				fseek( file, 84, SEEK_CUR );
			}
		case 7:
			{
				fseek( file, 8, SEEK_CUR );
			}
		case 8:
			{				
				static length;
				fseek( file, 4, SEEK_CUR );
				fread( file, length, BLOCK_INT );
				fseek( file, length, SEEK_CUR );
				fseek( file, 16, SEEK_CUR );
			}
		case 9:
			{
				static length;
				fread( file, length, BLOCK_INT );
				fseek( file, length, SEEK_CUR );
			}
		default:
			{
				breakme = true;
			}
		}

		if(breakme)
		{
			return true;
		}		
	}
	return false;
}


public ReadFrameHeader( file )
{
	fread( file, iDemoFrame[Type], BLOCK_BYTE );
	fread( file, _:iDemoFrame[Timestamp], BLOCK_INT );
	fread( file, iDemoFrame[Number], BLOCK_INT );
	return(iDemoFrame[Type]);
}

public parsing_country()
{
	Prechached = true;
	if(strlen(FLAG) == 0 || equali(FLAG, "n-")) 
	{
		FLAG = "xz";
	}
	
	formatex(url_sprite, charsmax(url_sprite), "sprites/wrbot/%s.spr", FLAG);
	formatex(url_sprite_xz, charsmax(url_sprite_xz), "sprites/wrbot/xz.spr");
	if(file_exists(url_sprite))
	{
		precache_model(url_sprite);
	}
	else if (file_exists(url_sprite_xz))
	{
		precache_model(url_sprite_xz);
	}
	else
	{
		return;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////STOCKS////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////


stock fnConvertTime( Float:time, convert_time[], len )
{
	static sTemp[24];
	new Float:fSeconds = time, iMinutes;
	iMinutes        = floatround( fSeconds / 60.0, floatround_floor );
	fSeconds        -= iMinutes * 60.0;
	new intpart     = floatround( fSeconds, floatround_floor );
	new Float:decpart   = (fSeconds - intpart) * 100.0;
	intpart         = floatround( decpart );
	formatex( sTemp, charsmax( sTemp ), "%02i%02.0f.%02d", iMinutes, fSeconds, intpart );
	formatex( convert_time, len, sTemp );
	return(PLUGIN_HANDLED);
}


stock ExplodeString( p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter )
{
	new nIdx = 0, l = strlen( p_szInput );
	new nLen = (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter ) );
	while ((nLen < l) && (++nIdx < p_nMax))
	{
		nLen += (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter ) );
	}
	return(nIdx);
}

stock rmdir_recursive(demo_folder[])
{
	new szFileName[64], sz_dest[256];
	new hDir = open_dir(demo_folder, szFileName, charsmax(szFileName));

	if(!hDir)
	{
		new file = fopen(demo_folder, "rb");
		if(file)
		{
			fclose(file);
		}
		return;
	}
	do
	{
		if(szFileName[0] != '.' && szFileName[1] != '.')
		{
			formatex(sz_dest, charsmax(sz_dest), "%s/%s", demo_folder, szFileName);
			
			if(!dir_exists(sz_dest)) {
				delete_file(sz_dest);
				//new result = delete_file(sz_dest);	
				//server_print("File delete? - %s - %s", sz_dest, result ? "Yes" : "No");		
			}
			else {
				rmdir(sz_dest);	
				rmdir_recursive(sz_dest);
			}
		}
	}	
	while ( next_file( hDir, szFileName, charsmax( szFileName )));
  	close_dir(hDir);
}


stock StringTimer(const Float:flRealTime, szOutPut[], const iSizeOutPut)
{
	new Float:flTime, iMinutes, iSeconds, iMiliSeconds, Float:iMili;
	new string[12];
	flTime = flRealTime;
	if(flTime < 0.0) 
	{
		flTime = 0.0;
	}
	iMinutes = floatround(flTime / 60, floatround_floor);
	iSeconds = floatround(flTime - (iMinutes * 60), floatround_floor);
	iMili = floatfract(flRealTime);
	formatex(string, 11, "%.02f", iMili >= 0 ? iMili + 0.005 : iMili - 0.005);
	iMiliSeconds = floatround(str_to_float(string) * 100, floatround_floor);
	formatex(szOutPut, iSizeOutPut, "%02d:%02d.%02d", iMinutes, iSeconds, iMiliSeconds);
}


stock ParseMap(id)
{

	new szFileName[256], hDir, dem[128], ext[1];
	hDir = open_dir( "", szFileName, charsmax(szFileName));
	
	if (hDir)
    {    
        while (next_file(hDir, szFileName, charsmax(szFileName)))
        {
            if (szFileName[0] == '.' && szFileName[1] != '.')
			{
                continue;
			}
            if (containi(szFileName, ".dem") != -1 && containi(szFileName, g_szCurrentMap ) == 0)
			{
				split(szFileName, dem, charsmax(dem), ext, charsmax(ext), ".dem");
				ArrayPushString(Founded_Demos, dem);
			}
        }
    }
  	close_dir(hDir);
	a_Size = ArraySize(Founded_Demos);
	
	hDir = open_dir( "../cstrike_downloads", szFileName, charsmax(szFileName));
	
	if (hDir)
    {    
        while (next_file(hDir, szFileName, charsmax(szFileName)))
        {
            if (szFileName[0] == '.' && szFileName[1] != '.')
			{
                continue;
			}
            if (containi(szFileName, ".dem") != -1 && containi(szFileName, g_szCurrentMap ) == 0)
			{
				split(szFileName, dem, charsmax(dem), ext, charsmax(ext), ".dem");
				if(!in_array(Founded_Demos, dem))
				{
					ArrayPushString(Founded_Demos, dem);
				}
			}
        }
    }
  	close_dir(hDir);
	a_Size = ArraySize(Founded_Demos);
	
	hDir = open_dir( local_demo_folder, szFileName, charsmax(szFileName));

	if (hDir)
    {    
        while (next_file(hDir, szFileName, charsmax(szFileName)))
        {
            if (szFileName[0] == '.' && szFileName[1] != '.')
			{
                continue;
			}
            if (containi(szFileName, ".nav") != -1 && containi(szFileName, g_szCurrentMap ) == 0)
			{
				split(szFileName, dem, charsmax(dem), ext, charsmax(ext), ".nav");
				if(!in_array(Founded_Demos, dem))
				{
					ArrayPushString(Founded_Demos, dem);
				}
			}
        }
    }
  	close_dir(hDir);
	a_Size = ArraySize(Founded_Demos);
	
	if(Call_Parse)
	{
		Call_Parse = false;
		ParseMenu(id);
	}
}


bool:in_array(Array:array, index[] )
{
	new str[64];
	for(new i, size = ArraySize(array); i < size; i++) 
	{
		ArrayGetString(array, i, str, charsmax(str));
		if(equali(str, index))
		{
			return true;
		}
	}
	return false;
} 

stock kick_bot(id)
{
	if(wr_bot_id)
	{
		server_cmd("kick #%d", get_user_userid(id));
	}
}