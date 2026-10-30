<?php
# MediaWiki 1.46.2, configured for one Sandstorm grain per wiki.
if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

$wgSitename = "Wiki";
$wgScriptPath = "";
$wgServer = '//' . ( $_SERVER['HTTP_HOST'] ?? 'localhost' );
$wgResourceBasePath = $wgScriptPath;
$wgLogos = [ '1x' => "$wgResourceBasePath/resources/assets/mediawiki.png" ];

$wgEnableEmail = false;
$wgEnableUserEmail = false;
$wgEmergencyContact = "nobody@localhost.invalid";
$wgPasswordSender = "nobody@localhost.invalid";
$wgEnotifUserTalk = false;
$wgEnotifWatchlist = false;
$wgEmailAuthentication = false;
$wgPingback = false;

$wgDBtype = "sqlite";
$wgDBserver = "";
$wgDBname = "wiki";
$wgDBuser = "";
$wgDBpassword = "";
$wgSQLiteDataDir = "/var/wiki";

$wgObjectCaches[CACHE_DB] = [
	'class' => SqlBagOStuff::class,
	'loggroup' => 'SQLBagOStuff',
	'server' => [
		'type' => 'sqlite',
		'dbname' => 'wikicache',
		'tablePrefix' => '',
		'variables' => [ 'synchronous' => 'NORMAL' ],
		'dbDirectory' => $wgSQLiteDataDir,
		'trxMode' => 'IMMEDIATE',
		'flags' => 0,
	],
];
$wgLocalisationCacheConf['storeServer'] = [
	'type' => 'sqlite',
	'dbname' => "{$wgDBname}_l10n_cache",
	'tablePrefix' => '',
	'variables' => [ 'synchronous' => 'NORMAL' ],
	'dbDirectory' => $wgSQLiteDataDir,
	'trxMode' => 'IMMEDIATE',
	'flags' => 0,
];
$wgJobTypeConf['default'] = [
	'class' => JobQueueDB::class,
	'claimTTL' => 3600,
	'server' => [
		'type' => 'sqlite',
		'dbname' => "{$wgDBname}_jobqueue",
		'tablePrefix' => '',
		'variables' => [ 'synchronous' => 'NORMAL' ],
		'dbDirectory' => $wgSQLiteDataDir,
		'trxMode' => 'IMMEDIATE',
		'flags' => 0,
	],
];
$wgMainCacheType = CACHE_NONE;
$wgMemCachedServers = [];
$wgCacheDirectory = "/var/mediawiki-cache";

$wgEnableUploads = true;
$wgUseImageMagick = false;
$wgUseInstantCommons = false;
$wgShellLocale = "C.UTF-8";
$wgLanguageCode = "en";
$wgLocaltimezone = "UTC";
$wgDiff3 = "/usr/bin/diff3";
$wgDefaultSkin = "vector";
$wgExternalLinkTarget = "_blank";

require_once '/var/wgSecretKey.php';
$wgAuthenticationTokenVersion = "1";
$wgRightsPage = "";
$wgRightsUrl = "";
$wgRightsText = "";
$wgRightsIcon = "";

wfLoadSkin( 'MonoBook' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'Vector' );
wfLoadExtension( 'WikiEditor' );
wfLoadExtension( 'ParserFunctions' );
wfLoadExtension( 'SandstormAuth' );

$wgBreakFrames = false;
$wgEditPageFrameOptions = false;
$wgShowExceptionDetails = false;
