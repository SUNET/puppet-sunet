[[inputs.varnish]]
    use_sudo = <%= $use_sudo %> 
    binary = "<%= $binary %>"
    stats = [<% $stats.each |$stat| { %>"<%= $stat%>",<% } %>]
    <% if $instance_name { %>
    instance_name = "<%= $instance_name %>"
    <% } %>
    timeout = "<%= $timeout %>"
