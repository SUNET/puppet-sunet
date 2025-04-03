<?php
$config['max_message_size']  = '40M';
$config['imap_auth_type'] = 'PLAIN';
$config['imap_host'] = 'tls://<%= @imap_host %>:143';
$config['smtp_host'] = 'tls://<%= @smtp_host %>:587';
$config['db_dsnw'] = 'mysql://<%= @mariadb_user %>:<%= @mariadb_password%>@<%= @mariadb_host %>/roundcubemail';
$config['plugins'] = ['markasjunk', 'shib_auth', 'carddav', 'managesieve', 'reconnect', 'calendar', 'custom_links'];
$config['dovecot_master_username'] = '';
$config['dovecot_master_password'] = '<%= @master_password %>';
$config['dovecot_master_user_separator'] = '';
$config['user_env'] = 'HTTP_SUBJECT_ID';
$config['product_name'] = 'Sunet Webmail';
$config['address_book_type'] = 'webdav';
$config['custom_links_taskbar'] = array(
array(
    "label" => "Code",
    "href" => "https://platform.sunet.se/",
    "target" => "_blank",
    "fontawesomeIcon" => "fa fa-code"
),
array(
    "label" => "Fediverse",
    "href" => "https://social.sunet.se/",
    "target" => "_blank",
    "fontawesomeIcon" => "fa fa-paper-plane"
),
array(
    "label" => "Files",
    "href" => "https://sunet.drive.sunet.se/",
    "target" => "_blank",
    "fontawesomeIcon" => "fa fa-briefcase"
),
);
$config['managesieve_host'] = 'tls://%h';
$config['managesieve_auth_type'] = 'LOGIN';
$config['managesieve_auth_pw'] = '<%= @master_password %>';
$config['calendar_nextcloud_url'] = 'https://sunet.drive.test.sunet.se/apps/calendar';
$config['markasjunk_toolbar'] = true;
