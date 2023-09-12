<?php
    $config['oauth_provider'] = 'generic';
    $config['oauth_provider_name'] = 'Sunet';
    $config['oauth_client_id'] = '<%= @oauth_client_id %>';
    $config['oauth_client_secret'] = '<%= @oauth_client_secret%>';
    $config['oauth_auth_uri'] = 'https://sso-proxy.mail.<%= @domain %>/Saml2SP/oidc-front/authorization';
    $config['oauth_token_uri'] = 'https://sso-proxy.mail.<%= @domain %>/oidc-front/token';
    $config['oauth_identity_uri'] = 'https://sso-proxy.<%= @domain %>/oidc-front/userinfo';
    $config['oauth_scope'] = "email profile openid";
    $config['oauth_auth_parameters'] = [];
    $config['oauth_identity_fields'] = ['sub'];
    $config['plugins'] = [];
    $config['log_driver'] = 'stdout';
    $config['zipdownload_selection'] = true;
    $config['des_key'] = '<%= @des_key %>';
    $config['enable_spellcheck'] = true;
    $config['spellcheck_engine'] = 'pspell';
    $config['db_dsnw'] = 'mysql://roundcube:<%= @roundcube_password %>@sogo-db:3306/roundcube';
    $config['db_dsnr'] = '';
    $config['imap_host'] = 'tls://imap.<%= @domain %>:143';
    $config['smtp_host'] = 'tls://smtp.<%= @domain %>:587';
    $config['temp_dir'] = '/tmp/roundcube-temp';
    $config['skin'] = 'elastic';
    $config['request_path'] = '/';
    $config['plugins'] = ['archive', 'zipdownload'];

