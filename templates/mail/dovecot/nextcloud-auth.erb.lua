function auth_passdb_lookup(req)
  -- Get the stored app passwords from Nextcloud
  local db        = '<%= @nextcloud_db %>'
  local user      = '<%= @nextcloud_db_user %>'
  local password  = '<%= @nextcloud_mysql_password %>'
  local db_server = '<%= @nextcloud_mysql_server %>'
  local mysql     = require "luasql.mysql"
  local query     = "SELECT hash,hash_type,salt FROM oc_imap_manager_users where user_id = '" ..
  req.user .. "@<%= @account_domain %>'"
  local env       = assert(mysql.mysql())
  local conn      = assert(env:connect(db, user, password, db_server))
  local cur       = assert(conn:execute(query))
  local row       = cur:fetch({}, "a")
  while row do
    -- Get the hash out using php
    local command = "php -r " ..
    "'print(hash(" .. '"' .. row.hash_type .. '","' .. row.salt .. req.password .. '"' .. "));'"
    local handle = assert(io.popen(command))
    local hash = handle:read("*a")
    handle:close()
    if hash == row.hash then
      return dovecot.auth.PASSDB_RESULT_OK, "password=" .. req.password
    end
    row = cur:fetch(row, "a")
  end
  return dovecot.auth.PASSDB_RESULT_USER_UNKNOWN, "no such user"
end
