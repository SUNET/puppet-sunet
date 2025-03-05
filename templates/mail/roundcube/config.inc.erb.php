<?php
$config['imap_auth_type'] = 'PLAIN';
$config['imap_host'] = 'tls://<%= @imap_host %>:143';
$config['smtp_host'] = 'tls://<%= @smtp_host %>:587';
$config['db_dsnw'] = 'mysql://<%= @mariadb_user %>:<%= @mariadb_password%>@<%= @mariadb_host %>/roundcubemail';
$config['plugins'] = ['carddav', 'managesieve', 'custom_links', 'shib_auth'];
$config['dovecot_master_username'] = '';
$config['dovecot_master_password'] = '<%= @master_password %>';
$config['dovecot_master_user_separator'] = '';
$config['user_env'] = 'REMOTE_USER';
$config['product_name'] = 'Sunet Webmail';
$config['address_book_type'] = 'webdav';
$config['custom_links_taskbar'] = array(
array(
    "label" => "Calendar",
    "href" => "https://sunet.drive.sunet.se/apps/calendar/",
    "target" => "_blank",
    "fontawesomeIcon" => "fa fa-calendar"
),
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
