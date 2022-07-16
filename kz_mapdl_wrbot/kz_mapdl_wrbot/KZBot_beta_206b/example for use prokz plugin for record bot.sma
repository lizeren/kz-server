
// Rec Bot
new sClimbTime[32]
new Float:ftime[33]
native reset_run(id);
native pause_run(id);
native unpause_run(id);
native save_run(id, sz_time[32]);


start_climb(id)
{
	unpause_run(id);
	reset_run(id);
}
public Pause(id)
{
	if(paused[id])
		pause_run(id);
	else
		unpause_run(id);

}
finish_climb(id)
{
	ftime[id] = time;
}


save_record_pro_top(id)
{
	if((i == 1) && cData[1] != NUB_TOP)
	{
		fnConvertTime(ftime[id], sClimbTime, charsmax(sClimbTime))
		save_run(id, sClimbTime);
		emit_sound(0, CHAN_BODY, "vox/woop.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
}



stock fnConvertTime( Float:time, convert_time[], len )
{
	new sTemp[24];
	new Float:fSeconds = time, iMinutes;

	iMinutes		= floatround( fSeconds / 60.0, floatround_floor );
	fSeconds		-= iMinutes * 60.0;
	new intpart		= floatround( fSeconds, floatround_floor );
	new Float:decpart	= (fSeconds - intpart) * 100.0;
	intpart			= floatround( decpart );

	formatex( sTemp, charsmax( sTemp ), "%02i%02.0f.%02d", iMinutes, fSeconds, intpart );


	formatex( convert_time, len, sTemp );

	return(PLUGIN_HANDLED);
}