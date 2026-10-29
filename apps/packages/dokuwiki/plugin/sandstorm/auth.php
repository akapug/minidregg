<?php
/** Sandstorm identity and permission authentication for DokuWiki. */

if (!defined('DOKU_INC')) die();

class auth_plugin_sandstorm extends \dokuwiki\Extension\AuthPlugin
{
    public function __construct()
    {
        parent::__construct();
        $this->cando['external'] = true;
        $this->cando['logout'] = false;
        $this->success = true;
    }

    public function trustExternal($user, $pass, $sticky = false)
    {
        global $USERINFO;

        $userid = $_SERVER['HTTP_X_SANDSTORM_USER_ID'] ?? '';
        if ($userid === '') return false;

        $name = rawurldecode($_SERVER['HTTP_X_SANDSTORM_USERNAME'] ?? '');
        if ($name === '') $name = 'Sandstorm user';
        $groups = str_getcsv($_SERVER['HTTP_X_SANDSTORM_PERMISSIONS'] ?? '');
        $groups = array_values(array_filter(array_map('trim', $groups), fn($group) => $group !== ''));

        $USERINFO = [
            'name' => $name,
            'mail' => '',
            'grps' => $groups,
        ];
        $_SERVER['REMOTE_USER'] = $userid;
        $_SESSION[DOKU_COOKIE]['auth']['user'] = $userid;
        $_SESSION[DOKU_COOKIE]['auth']['pass'] = '';
        $_SESSION[DOKU_COOKIE]['auth']['info'] = $USERINFO;
        $this->remember($userid, $USERINFO);
        return true;
    }

    public function getUserData($user, $requireGroups = true)
    {
        $path = $this->userPath($user);
        if (!is_file($path)) return false;
        $data = json_decode(file_get_contents($path), true);
        if (!is_array($data) || !isset($data['name'], $data['mail'], $data['grps'])) return false;
        return $data;
    }

    private function remember($userid, $info)
    {
        $directory = dirname($this->userPath($userid));
        if (!is_dir($directory)) mkdir($directory, 0777, true);
        file_put_contents(
            $this->userPath($userid),
            json_encode($info, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            LOCK_EX
        );
    }

    private function userPath($userid)
    {
        return '/var/lib/dokuwiki/users/' . hash('sha256', $userid) . '.json';
    }
}
