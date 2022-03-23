// IW5 GSC SOURCE
// Decompiled by https://github.com/xensik/gsc-tool
// Rewritten by ReaaLx

main()
{
	if ( getdvar( "mapname" ) == "mp_background" )
		return;

	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	maps\mp\_utility::registerRoundSwitchDvar( level.gameType, 0, 0, 9 );
	maps\mp\_utility::registerTimeLimitDvar( level.gameType, 10 );
	maps\mp\_utility::registerScoreLimitDvar( level.gameType, 500 );
	maps\mp\_utility::registerRoundLimitDvar( level.gameType, 1 );
	maps\mp\_utility::registerWinLimitDvar( level.gameType, 1 );
	maps\mp\_utility::registerNumLivesDvar( level.gameType, 0 );
	maps\mp\_utility::registerHalfTimeDvar( level.gameType, 0 );

	level.teamBased = 1;
	level.objectiveBased = 1;
	level.onPrecacheGameType = ::onPrecacheGameType;
	level.onStartGameType = ::onStartGameType;
	level.getSpawnPoint = ::getSpawnPoint;
	level.onSpawnPlayer = ::onSpawnPlayer;
	level.onNormalDeath = ::onNormalDeath;
	level.onPlayerKilled = ::onPlayerKilled;
	level.onDeadEvent = ::onDeadEvent;
	game["dialog"]["gametype"] = "arena";

	if ( getdvarint( "g_hardcore" ) )
		game["dialog"]["gametype"] = "hc_" + game["dialog"]["gametype"];
	else if ( getdvarint( "camera_thirdPerson" ) )
		game["dialog"]["gametype"] = "thirdp_" + game["dialog"]["gametype"];
	else if ( getdvarint( "scr_diehard" ) )
		game["dialog"]["gametype"] = "dh_" + game["dialog"]["gametype"];

	game["strings"]["overtime_hint"] = &"MP_FIRST_BLOOD";
}

onPrecacheGameType()
{
	precacheshader( "compass_waypoint_captureneutral" );
	precacheshader( "compass_waypoint_capture" );
	precacheshader( "compass_waypoint_defend" );
	precacheshader( "waypoint_captureneutral" );
	precacheshader( "waypoint_capture" );
	precacheshader( "waypoint_defend" );
}

onStartGameType()
{
	setclientnamemode( "auto_change" );

	if ( !isdefined( game["switchedsides"] ) )
		game["switchedsides"] = 0;

	if ( game["switchedsides"] )
	{
		oldAttackers = game["attackers"];
		oldDefenders = game["defenders"];
		game["attackers"] = oldDefenders;
		game["defenders"] = oldAttackers;
	}

	maps\mp\_utility::setObjectiveText( "allies", &"OBJECTIVES_ARENA" );
	maps\mp\_utility::setObjectiveText( "axis", &"OBJECTIVES_ARENA" );

	if ( level.splitscreen )
	{
		maps\mp\_utility::setObjectiveScoreText( "allies", &"OBJECTIVES_ARENA" );
		maps\mp\_utility::setObjectiveScoreText( "axis", &"OBJECTIVES_ARENA" );
	}
	else
	{
		maps\mp\_utility::setObjectiveScoreText( "allies", &"OBJECTIVES_ARENA_SCORE" );
		maps\mp\_utility::setObjectiveScoreText( "axis", &"OBJECTIVES_ARENA_SCORE" );
	}

	maps\mp\_utility::setObjectiveHintText( "allies", &"OBJECTIVES_ARENA_HINT" );
	maps\mp\_utility::setObjectiveHintText( "axis", &"OBJECTIVES_ARENA_HINT" );
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_allies_start" );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_axis_start" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );
	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setmapcenter( level.mapCenter );
	allowed[0] = "dom";
	allowed[1] = "airdrop_pallet";
	allowed[2] = "arena";
	maps\mp\gametypes\_rank::registerScoreInfo( "capture", 200 );
	maps\mp\gametypes\_gameobjects::main( allowed );
	precacheFlag();
	thread arenaFlagWaiter();
	thread arenaTimeFlagWaiter();
}

precacheFlag()
{
	game["flagmodels"] = [];
	game["flagmodels"]["neutral"] = "prop_flag_neutral";
	game["flagmodels"]["allies"] = maps\mp\gametypes\_teams::getTeamFlagModel( "allies" );
	game["flagmodels"]["axis"] = maps\mp\gametypes\_teams::getTeamFlagModel( "axis" );
	precachemodel( game["flagmodels"]["neutral"] );
	precachemodel( game["flagmodels"]["allies"] );
	precachemodel( game["flagmodels"]["axis"] );
	precachestring( &"MP_CAPTURING_FLAG" );
	precachestring( &"MP_LOSING_FLAG" );
	precachestring( &"MP_DOM_YOUR_FLAG_WAS_CAPTURED" );
	precachestring( &"MP_DOM_ENEMY_FLAG_CAPTURED" );
	precachestring( &"MP_DOM_NEUTRAL_FLAG_CAPTURED" );
	precachestring( &"MP_ENEMY_FLAG_CAPTURED_BY" );
	precachestring( &"MP_NEUTRAL_FLAG_CAPTURED_BY" );
	precachestring( &"MP_FRIENDLY_FLAG_CAPTURED_BY" );
}

arenaTimeFlagWaiter()
{
	level endon( "down_to_one" );
	level endon( "game_end" );

	for ( ;; )
	{
		timeLeft = maps\mp\gametypes\_gamelogic::getTimeRemaining();

		if ( timeLeft < 61000 )
			break;

		wait 1;
	}

	level notify( "arena_flag_time" );
	thread arenaFlag();
}

arenaFlagWaiter()
{
	level endon( "game_end" );
	level endon( "arena_flag_time" );

	for ( ;; )
	{
		if ( level.inGracePeriod == 0 )
			break;

		wait 0.05;
	}

	for ( ;; )
	{
		if ( getteamplayersalive( "axis" ) == 1 )
		{
			thread arenaFlag();
			level notify( "down_to_one" );
			break;
		}

		if ( getteamplayersalive( "allies" ) == 1 )
		{
			thread arenaFlag();
			level notify( "down_to_one" );
			break;
		}

		wait 1;
	}
}

getSpawnPoint()
{
	spawnteam = self.pers["team"];

	if ( game["switchedsides"] )
		spawnteam = maps\mp\_utility::getOtherTeam( spawnteam );

	if ( level.inGracePeriod )
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_tdm_spawn_" + spawnteam + "_start" );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( spawnPoints );
	}
	else
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( spawnteam );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam( spawnPoints );
	}

	return spawnPoint;
}

onSpawnPlayer()
{
	self.usingObj = undefined;
	level notify( "spawned_player" );
}

onNormalDeath( victim, attacker, lifeId )
{
	score = maps\mp\gametypes\_rank::getScoreInfoValue( "kill" );
	attacker maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( attacker.pers["team"], score );
	team = victim.team;

	if ( game["state"] == "postgame" )
		attacker.finalKill = 1;
}

onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration, killId )
{
	thread checkAllowSpectating();
}

onTimeLimit()
{
	if ( game["status"] == "overtime" )
		winner = "forfeit";
	else if ( game["teamScores"]["allies"] == game["teamScores"]["axis"] )
		winner = "overtime";
	else if ( game["teamScores"]["axis"] > game["teamScores"]["allies"] )
		winner = "axis";
	else
		winner = "allies";

	thread maps\mp\gametypes\_gamelogic::endGame( winner, game["strings"]["time_limit_reached"] );
}

checkAllowSpectating()
{
	wait 0.05;
	update = 0;

	if ( !level.aliveCount[game["attackers"]] )
	{
		level.spectateOverride[game["attackers"]].allowEnemySpectate = 1;
		update = 1;
	}

	if ( !level.aliveCount[game["defenders"]] )
	{
		level.spectateOverride[game["defenders"]].allowEnemySpectate = 1;
		update = 1;
	}

	if ( update )
		maps\mp\gametypes\_spectating::updateSpectateSettings();
}

arenaFlag()
{
	level.lastStatus["allies"] = 0;
	level.lastStatus["axis"] = 0;
	arenaFlag = getentarray( "flag_arena", "targetname" );
	primaryFlags = getentarray( "flag_primary", "targetname" );
	secondaryFlags = getentarray( "flag_secondary", "targetname" );

	if ( !isdefined( arenaFlag[0] ) )
	{
		if ( primaryFlags.size + secondaryFlags.size < 1 )
		{
			maps\mp\gametypes\_callbacksetup::AbortLevel();
			return;
		}

		setupDomFlag( primaryFlags, secondaryFlags );
	}
	else
		level.arenaFlag = arenaFlag[0];

	trigger = level.arenaFlag;

	if ( isdefined( trigger.target ) )
		visuals[0] = getent( trigger.target, "targetname" );
	else
	{
		visuals[0] = spawn( "script_model", trigger.origin );
		visuals[0].angles = trigger.angles;
	}

	visuals[0] setmodel( game["flagmodels"]["neutral"] );

	arenaFlag = maps\mp\gametypes\_gameobjects::createUseObject( "neutral", trigger, visuals, ( 0, 0, 100 ) );
	arenaFlag maps\mp\gametypes\_gameobjects::allowUse( "enemy" );
	arenaFlag maps\mp\gametypes\_gameobjects::setUseTime( 20.0 );
	arenaFlag maps\mp\gametypes\_gameobjects::setUseText( &"MP_CAPTURING_FLAG" );
	label = arenaFlag maps\mp\gametypes\_gameobjects::getLabel();
	arenaFlag.label = label;
	arenaFlag maps\mp\gametypes\_gameobjects::set2DIcon( "friendly", "compass_waypoint_defend" );
	arenaFlag maps\mp\gametypes\_gameobjects::set3DIcon( "friendly", "waypoint_defend" );
	arenaFlag maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "compass_waypoint_captureneutral" );
	arenaFlag maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_captureneutral" );
	arenaFlag maps\mp\gametypes\_gameobjects::setVisibleTeam( "any" );
	arenaFlag.onUse = ::onUse;
	arenaFlag.onBeginUse = ::onBeginUse;
	arenaFlag.onUseUpdate = ::onUseUpdate;
	arenaFlag.onEndUse = ::onEndUse;
	arenaFlag.isArena = 1;
	iprintlnbold( "Arena flag spawned" );
	level.arenaFlag playsound( "flag_spawned" );
	traceStart = visuals[0].origin + ( 0, 0, 32 );
	traceEnd = visuals[0].origin + ( 0, 0, -32 );
	trace = bullettrace( traceStart, traceEnd, 0, undefined );
	upangles = vectortoangles( trace["normal"] );
	arenaFlag.baseeffectforward = anglestoforward( upangles );
	arenaFlag.baseeffectright = anglestoright( upangles );
	arenaFlag.baseeffectpos = trace["position"];
	arenaFlag.levelFlag = level.arenaFlag;
	level.arenaFlag = arenaFlag;
}

setupDomFlag( primaryFlags, secondaryFlags )
{
	for ( index = 0; index < index.size; index++ )
	{
		label = primaryFlags[index].script_label;

		if ( label != "_b" )
		{
			primaryFlags[index] delete();
			continue;
		}

		level.arenaFlag = primaryFlags[index];
		return;
	}
}

onDeadEvent( team )
{
	if ( team == game["attackers"] )
		level thread arena_endGame( game["defenders"], game["strings"][game["attackers"] + "_eliminated"] );
	else if ( team == game["defenders"] )
		level thread arena_endGame( game["attackers"], game["strings"][game["defenders"] + "_eliminated"] );
}

arena_endGame( winningTeam, endReasonText )
{
	thread maps\mp\gametypes\_gamelogic::endGame( winningTeam, endReasonText );
}

giveFlagCaptureXP( touchList )
{
	level endon( "game_ended" );
	wait 0.05;
	maps\mp\_utility::WaitTillSlowProcessAllowed();
	players = getarraykeys( touchList );

	for ( index = 0; index < players.size; index++ )
	{
		player = touchList[players[index]].player;
		player thread [[ level.onXPEvent ]]( "capture" );
		maps\mp\gametypes\_gamescore::givePlayerScore( "capture", player );
		player thread maps\mp\_matchdata::logGameEvent( "capture", player.origin );
	}
}

onUse( player )
{
	team = player.pers["team"];
	oldTeam = maps\mp\gametypes\_gameobjects::getOwnerTeam();
	label = maps\mp\gametypes\_gameobjects::getLabel();

	player logString( "flag captured: " + self.label );

	self.captureTime = gettime();
	maps\mp\gametypes\_gameobjects::setOwnerTeam( team );
	maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "compass_waypoint_capture" );
	maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_capture" );
	self.visuals[0] setmodel( game["flagmodels"][team] );

	if ( oldTeam == "neutral" )
	{
		otherTeam = maps\mp\_utility::getOtherTeam( team );
		thread maps\mp\_utility::printAndSoundOnEveryone( team, otherTeam, &"MP_NEUTRAL_FLAG_CAPTURED_BY", &"MP_NEUTRAL_FLAG_CAPTURED_BY", "mp_war_objective_taken", undefined, player );
		statusDialog( "secured_a", team );
		statusDialog( "enemy_has_a", otherTeam );
	}
	else
		thread maps\mp\_utility::printAndSoundOnEveryone( team, oldTeam, &"MP_ENEMY_FLAG_CAPTURED_BY", &"MP_FRIENDLY_FLAG_CAPTURED_BY", "mp_war_objective_taken", "mp_war_objective_lost", player );

	thread giveFlagCaptureXP( self.touchList[team] );
	player notify( "objective", "captured" );
	thread flagCaptured( team, &"MP_DOM_NEUTRAL_FLAG_CAPTURED" );
}

onBeginUse( player )
{
	ownerTeam = maps\mp\gametypes\_gameobjects::getOwnerTeam();
	self.didStatusNotify = 0;

	if ( ownerTeam == "neutral" )
	{
		otherTeam = maps\mp\_utility::getOtherTeam( player.pers["team"] );
		statusDialog( "securing_a", player.pers["team"] );
		self.objPoints[player.pers["team"]] thread maps\mp\gametypes\_objpoints::startFlashing();
		statusDialog( "losing_a", otherTeam );
		return;
	}

	self.objPoints["allies"] thread maps\mp\gametypes\_objpoints::startFlashing();
	self.objPoints["axis"] thread maps\mp\gametypes\_objpoints::startFlashing();
}

onUseUpdate( team, progress, change )
{
	if ( progress > 0.05 && change && !self.didStatusNotify )
	{
		otherTeam = maps\mp\_utility::getOtherTeam( team );
		statusDialog( "losing_a", otherTeam );
		statusDialog( "securing_a", team );
		self.didStatusNotify = 1;
	}
}

onEndUse( team, player, success )
{
	self.objPoints["allies"] thread maps\mp\gametypes\_objpoints::stopFlashing();
	self.objPoints["axis"] thread maps\mp\gametypes\_objpoints::stopFlashing();
}

statusDialog( dialog, team )
{
	if ( gettime() < level.lastStatus[team ] + 6000 )
		return;

	thread delayedLeaderDialog( dialog, team );
	level.lastStatus[team ] = gettime();
}

delayedLeaderDialog( sound, team )
{
	level endon( "game_ended" );
	wait 0.1;
	maps\mp\_utility::WaitTillSlowProcessAllowed();
	maps\mp\_utility::leaderDialog( sound, team );
}

flagCaptured( winningTeam, endReasonText )
{
	maps\mp\gametypes\_gamelogic::endGame( winningTeam, endReasonText );
}
