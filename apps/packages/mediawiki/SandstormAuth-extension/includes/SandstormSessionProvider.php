<?php

use MediaWiki\MediaWikiServices;
use MediaWiki\Session\SessionBackend;
use MediaWiki\Session\SessionInfo;
use MediaWiki\Session\SessionProvider;
use MediaWiki\Session\UserInfo;
use Wikimedia\Rdbms\DatabaseSqlite;

class SandstormSessionProvider extends SessionProvider {
	private $sandstormDB;

	protected function postInitSetup() {
		$this->sandstormDB = DatabaseSqlite::newStandaloneInstance( '/var/sandstorm-extension.sqlite' );
		$this->sandstormDB->query(
			"CREATE TABLE IF NOT EXISTS sandstorm_user\n" .
			"    ( user_id VARCHAR PRIMARY KEY\n" .
			"    , username VARCHAR UNIQUE NOT NULL\n" .
			"    , permissions VARCHAR NOT NULL\n" .
			"    )"
		);
	}

	public function provideSessionInfo( WebRequest $request ) {
		$h = $request->getAllHeaders();
		$userId = $h['X-SANDSTORM-USER-ID'] ?? '';
		$username = urldecode( $h['X-SANDSTORM-USERNAME'] ?? 'Anonymous' );
		$permissions = $h['X-SANDSTORM-PERMISSIONS'] ?? '';
		$tabId = $h['X-SANDSTORM-TAB-ID'] ?? 'anonymous-tab';
		$username = $this->ensureUser( $userId, $username, $permissions, $tabId );

		return new SessionInfo( SessionInfo::MAX_PRIORITY, [
			'provider' => $this,
			'id' => hash( 'sha256', $tabId ),
			'userInfo' => UserInfo::newFromName( $username, true ),
		] );
	}

	private function ensureUser( $userId, $username, $permissions, $tabId ) {
		if ( $userId === '' ) {
			$userId = 'anonymous-' . substr( $tabId, 0, 8 );
			$username .= ' ' . substr( $tabId, 0, 8 );
		} else {
			$userId = 'logged-in-' . $userId;
		}

		$db = $this->sandstormDB;
		$res = $db->select( 'sandstorm_user', [ 'username', 'permissions' ], [ 'user_id' => $userId ] );
		if ( $res->numRows() > 0 ) {
			$row = $res->fetchRow();
			$username = $row['username'];
			$oldPermissions = $row['permissions'];
			$res->free();
			if ( $permissions !== $oldPermissions ) {
				$this->updatePermissions( $username, $oldPermissions, $permissions );
			}
		} else {
			$res->free();
			while ( true ) {
				$db->insert(
					'sandstorm_user',
					[ 'user_id' => $userId, 'username' => $username, 'permissions' => '' ],
					__METHOD__,
					[ 'IGNORE' ]
				);
				if ( $db->affectedRows() > 0 ) {
					break;
				}
				$username .= ' 2';
			}
			$this->updatePermissions( $username, '', $permissions );
		}
		return $username;
	}

	private function diffPermissions( $oldString, $newString ) {
		$old = array_fill_keys( explode( ',', $oldString ), true );
		$new = array_fill_keys( explode( ',', $newString ), true );
		return [
			'add' => array_values( array_diff_key( $new, $old ) ),
			'remove' => array_values( array_diff_key( $old, $new ) ),
		];
	}

	private function updatePermissions( $username, $oldPermissions, $newPermissions ) {
		$db = MediaWikiServices::getInstance()->getDBLoadBalancer()->getConnection( DB_PRIMARY );
		$res = $db->select( 'user', [ 'user_id' ], [ 'user_name' => $username ] );
		if ( $res->numRows() === 0 ) {
			# UserInfo creates a new user later in this request. The unchanged empty
			# permission record makes the next request apply the initial role.
			$res->free();
			return;
		}
		$row = $res->fetchRow();
		$userId = $row['user_id'];
		$res->free();
		$diff = $this->diffPermissions( $oldPermissions, $newPermissions );
		foreach ( $diff['remove'] as $group ) {
			if ( $group !== '' ) {
				$db->delete( 'user_groups', [ 'ug_user' => $userId, 'ug_group' => $group ] );
			}
		}
		foreach ( $diff['add'] as $group ) {
			if ( $group !== '' ) {
				$db->insert(
					'user_groups',
					[ 'ug_user' => $userId, 'ug_group' => $group ],
					__METHOD__,
					[ 'IGNORE' ]
				);
			}
		}
		$this->sandstormDB->update(
			'sandstorm_user',
			[ 'permissions' => $newPermissions ],
			[ 'username' => $username ]
		);
	}

	public function getVaryHeaders() {
		return [
			'X-SANDSTORM-USERNAME',
			'X-SANDSTORM-USER-ID',
			'X-SANDSTORM-PERMISSIONS',
			'X-SANDSTORM-TAB-ID',
		];
	}

	public function persistsSessionId() { return false; }
	public function canChangeUser() { return false; }
	public function persistSession( SessionBackend $session, WebRequest $request ) {}
	public function unpersistSession( WebRequest $request ) {}
}
