#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

main()
{
	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	registerRoundSwitchDvar( level.gameType, 0, 0, 9 );
	registerTimeLimitDvar( level.gameType, 10 );
	setOverrideWatchDvar( "scorelimit", 0 );
	registerRoundLimitDvar( level.gameType, 1 );
	registerWinLimitDvar( level.gameType, 1 );
	registerNumLivesDvar( level.gameType, 0 );
	registerHalfTimeDvar( level.gameType, 0 );

	level.gtnw = true;
	level.teamBased = true;
	level.onPrecacheGameType = ::onPrecacheGameType;
	level.onStartGameType = ::onStartGameType;
	level.getSpawnPoint = ::getSpawnPoint;
	level.onTimeLimit = ::onTimeLimit;
	level.onNormalDeath = ::onNormalDeath;

	game["dialog"]["offense_obj"] = "capture_obj";
	game["dialog"]["defense_obj"] = "capture_obj";
	game["dialog"]["gametype"] = "gtw";

	level thread onPlayerConnect();
}

onPlayerConnect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		player.touchingNuke = false; // Custom
		player.useBar = player createPrimaryProgressBar();
		player.useBar.useTime = 100;
		player.useBar hideElem();
		player.useBarText = player createPrimaryProgressBarText();
		player.useBarText setText( &"MP_CAPTURING_NUKE" );
		player.useBarText hideElem();
	}
}

onPrecacheGameType()
{
	precacheShader( "waypoint_defend" );
	precacheShader( "waypoint_capture" );
	precacheString( &"MP_CAPTURING_NUKE" );
}

onStartGameType()
{
	if ( !isdefined( game["switchedsides"] ) )
		game["switchedsides"] = false;

	if ( !isdefined( game["original_defenders"] ) )
		game["original_defenders"] = game["defenders"];

	if ( game["switchedsides"] )
	{
		oldAttackers = game["attackers"];
		oldDefenders = game["defenders"];
		game["attackers"] = oldDefenders;
		game["defenders"] = oldAttackers;
	}

	setClientNameMode( "auto_change" );

	setObjectiveText( game["attackers"], &"OBJECTIVES_GTNW" );
	setObjectiveText( game["defenders"], &"OBJECTIVES_GTNW" );
	setObjectiveHintText( game["attackers"], &"OBJECTIVES_GTNW_HINT" );
	setObjectiveHintText( game["defenders"], &"OBJECTIVES_GTNW_HINT" );
	setObjectiveScoreText( game["attackers"], &"OBJECTIVES_GTNW_SCORE" );
	setObjectiveScoreText( game["defenders"], &"OBJECTIVES_GTNW_SCORE" );

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_ctf_spawn_allies_start" );
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_ctf_spawn_axis_start" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_ctf_spawn_allies" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_ctf_spawn_axis" );

	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );

	maps\mp\gametypes\_rank::registerScoreInfo( "kill", 50 );
	maps\mp\gametypes\_rank::registerScoreInfo( "headshot", 100 );
	maps\mp\gametypes\_rank::registerScoreInfo( "assist", 20 );
	maps\mp\gametypes\_rank::registerScoreInfo( "capture", 500 );

	allowed[0] = "gtnw";
	allowed[1] = "dd_bombzone";

	maps\mp\gametypes\_gameobjects::main( allowed );

	thread setupNukeSite();
}

setupNukeSite()
{
	// Check for GTNW ents first, as some maps may include them. Otherwise use DD overtime bombsite.
	nukeZone  = getEnt( "gtnw_zone", "targetname" );
	bombZones = getEntArray( "dd_bombzone", "targetname" );

	// Do not check here nukeZone as some maps do not include them, check bombZones
	assertEx( isDefined( bombZones ), "DD Zone doesn't exist in this map" );

	foreach ( bombZone in bombZones )
	{
		visuals = getEntArray( bombZone.target, "targetname" );
		label = bombZone.script_label;
		collision = getEnt( "dd_bombzone_clip" + label, "targetname" );

		if ( isDefined( nukeZone  ) || label == "_a" || label == "_b" )
		{
			bombZone delete ();
			visuals[0] delete ();
			collision delete ();
		}

		if ( !isDefined( nukeZone ) && label == "_c" )
		{
			nukeZone  = bombZone;
		}
	}

	level.lastStatus["allies"] = 0;
	level.lastStatus["axis"] = 0;

	nukeSite = maps\mp\gametypes\_gameobjects::createUseObject( "neutral", nukeZone, [], ( 0, 0, 100 ) );
	nukeSite maps\mp\gametypes\_gameobjects::set2DIcon( "friendly", "waypoint_defend" );
	nukeSite maps\mp\gametypes\_gameobjects::set3DIcon( "friendly", "waypoint_defend" );
	nukeSite maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "waypoint_captureneutral" );
	nukeSite maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_captureneutral" );
	nukeSite maps\mp\gametypes\_gameobjects::allowUse( "none" );
	nukeSite maps\mp\gametypes\_gameobjects::setVisibleTeam( "any" );
	nukeSite.onBeginUse = ::onBeginUse;
	nukeSite.onEndUse = ::onEndUse;
	nukeSite.noUseBar = true;
	nukeSite.touchRadius = 100;
	nukeSite thread scoring( nukeZone.origin );

	thread waitForNuke();
}

waitForNuke()
{
	level endon( "game_ended" );
	level waittill( "nuke_death" );
	team = level.nukeOwner.pers["team"];

	thread maps\mp\gametypes\_gamelogic::endgame( team, game["strings"][getOtherTeam( team ) + "_eliminated"] );
}

onBeginUse( player )
{
	player.useBar showElem();
	player.useBarText showElem();
	return;
}

onEndUse( team, player, success )
{
	player.useBar hideElem();
	player.useBarText hideElem();
	return;
}

scoring( origin )
{
	level endon( "game_ended" );

	for ( ;; )
	{
		touching["allies"] = 0;
		touching["axis"] = 0;

		foreach ( player in level.players )
		{
			if ( isAlive( player ) && distance2D( origin, player.origin ) < self.touchRadius )
			{
				if ( !player.touchingNuke )
				{
					player.startTouchTime = getTime();
				}

				player.touchingNuke = true;
				touching[player.pers["team"]]++;
				player.useBar showElem();
				player.useBarText showElem();
			}
			else
			{
				if ( player.touchingNuke )
				{
					player.startTouchTime = undefined;
				}

				player.touchingNuke = false;
				player.useBar hideElem();
				player.useBarText hideElem();
			}
		}

		if ( touching["allies"] == 0 && touching["axis"] == 0 )
		{
			setDvar( "ui_danger_team", "none" );
			self maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "waypoint_captureneutral" );
			self maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_captureneutral" );
			self maps\mp\gametypes\_gameobjects::setOwnerTeam( "none" );
			wait 1;
			continue;
		}

		self maps\mp\gametypes\_gameobjects::set2DIcon( "friendly", "waypoint_defend" );
		self maps\mp\gametypes\_gameobjects::set3DIcon( "friendly", "waypoint_defend" );
		self maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "waypoint_capture" );
		self maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_capture" );

		if ( touching["allies"] < touching["axis"] )
		{
			if ( maps\mp\gametypes\_gamescore::_getTeamScore( "axis" ) < 100 )
			{
				maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( "axis", 1 );
			}

			self thread setUseBarScore( "axis" );
			setDvar( "ui_danger_team", "allies" );
			self maps\mp\gametypes\_gameobjects::setOwnerTeam( "axis" );

			if ( maps\mp\gametypes\_gamescore::_getTeamScore( "axis" ) >= 100 )
			{
				self maps\mp\gametypes\_gameobjects::allowUse( "none" );
				activateNuke( "axis" );
				return;
			}
		}
		else if ( touching["allies"] > touching["axis"] )
		{
			if ( maps\mp\gametypes\_gamescore::_getTeamScore( "allies" ) < 100 )
			{
				maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( "allies", 1 );
			}

			self thread setUseBarScore( "allies" );
			setDvar( "ui_danger_team", "axis" );
			self maps\mp\gametypes\_gameobjects::setOwnerTeam( "allies" );

			if ( maps\mp\gametypes\_gamescore::_getTeamScore( "allies" ) >= 100 )
			{
				self maps\mp\gametypes\_gameobjects::allowUse( "none" );
				activateNuke( "allies" );
				return;
			}
		}
		else
		{
			self maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "waypoint_captureneutral" );
			self maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_captureneutral" );

			self maps\mp\gametypes\_gameobjects::setOwnerTeam( "none" );
			setDvar( "ui_danger_team", "contested" );
		}

		wait 1;

	}
}

activateNuke( team )
{
	self nukeCaptured( team );
	self maps\mp\gametypes\_gameobjects::setVisibleTeam( "none" );
	self maps\mp\gametypes\_gameobjects::allowUse( "none" );
	// Reward the player who has been on the capture for the longest recently.
	bestTime = 99999999;
	level.nukeOwner = undefined;

	foreach ( player in level.players )
	{
		player.useBar hideElem();
		player.useBarText hideElem();

		if ( player.team == team && player.touchingNuke )
		{
			if ( player.startTouchTime < bestTime )
			{
				level.nukeOwner = player;
				bestTime = player.startTouchTime;
			}
		}
	}

	assert( isDefined( level.nukeOwner ) );
	level.nukeOwner maps\mp\killstreaks\_nuke::tryUseNuke( 1 );
}

nukeCaptured( team )
{
	level endon( "game_ended" );
	wait 0.05;
	WaitTillSlowProcessAllowed();

	foreach ( player in level.players )
	{
		if ( player.team == team )
		{
			player thread maps\mp\gametypes\_hud_message::SplashNotify( "captured_nuke", maps\mp\gametypes\_rank::getScoreInfoValue( "capture" ) );
			player thread [[level.onXPEvent]]( "capture" );
			maps\mp\gametypes\_gamescore::givePlayerScore( "capture", player );
		}
	}
}

setUseBarScore( team )
{
	teamScore = getTeamScore( team );

	foreach ( player in level.players )
	{
		if ( player.team == team && player.touchingNuke )
			player.useBar updateBar( teamScore / 100, 0 );
	}
}

getSpawnPoint()
{
	spawnteam = self.pers["team"];

	if ( game["switchedsides"] )
		spawnteam = getOtherTeam( spawnteam );

	if ( level.inGracePeriod )
	{
		spawnPoints = getentarray( "mp_ctf_spawn_" + spawnteam + "_start", "classname" );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( spawnPoints );
	}
	else
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( spawnteam );
		spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam( spawnPoints );
	}

	return spawnPoint;
}

onTimeLimit()
{
	if ( game["teamScores"]["allies"] == game["teamScores"]["axis"] )
	{
		thread maps\mp\gametypes\_gamelogic::endGame( "tie", game["strings"]["time_limit_reached"] );
	}
	else if ( game["teamScores"]["axis"] > game["teamScores"]["allies"] )
	{
		thread maps\mp\gametypes\_gamelogic::endGame( "axis", game["strings"]["time_limit_reached"] );
	}
	else
	{
		thread maps\mp\gametypes\_gamelogic::endGame( "allies", game["strings"]["time_limit_reached"] );
	}
}

onNormalDeath( victim, attacker, lifeId )
{
	return;
}
