function auth_passdb_lookup(req)
  -- Get the hash out using php
  local salt = "<%= @nextcloud_salt %>"
  local command = "php -r " .. "'print(hash(" .. '"sha512","' .. req.password .. salt .. '"' .. "));'"
  local handle = assert(io.popen(command))
  local hash = handle:read("*a")
  handle:close()

  -- Get the stored app passwords from Nextcloud
  local db        = '<%= @nextcloud_db %>'
  local user      = '<%= @nextcloud_db_user %>'
  local password  = '<%= @nextcloud_mysql_password %>'
  local db_server = '<%= @nextcloud_mysql_server %>'
  local mysql     = require "luasql.mysql"
  local query     = "SELECT token FROM oc_authtoken where uid = '" .. req.user .. "@<%= @account_domain %>'"
  local env       = assert(mysql.mysql())
  local conn      = assert(env:connect(db, user, password, db_server))
  local cur       = assert(conn:execute(query))
  local row       = cur:fetch({}, "a")
  while row do
    local token = row.token
    if token == hash then
      return dovecot.auth.PASSDB_RESULT_OK, "password=" .. req.password
    end
    row = cur:fetch(row, "a")
  end
  return dovecot.auth.PASSDB_RESULT_USER_UNKNOWN, "no such user"
end
