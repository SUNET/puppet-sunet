#!/bin/bash

ceph="/usr/sbin/cephadm shell ceph"

ssh "<%= @firstmon>" /opt/ceph/bootstrap.sh
scp "<%- @firstmon>:/etc/ceph/*" /etc/ceph/
# <% monitors = [] %>
# <% osd = [] %>
# <%- @nodes.each do |node| %>
${ceph} orch host add "<%= node['hostname'] %>"
# <%- node['labels'].each do |label| %>
# <%- if label == 'mon' %>
# <%- monitors.append(node['hostname']) %>
# <%- elsif label == 'osd' -%>
# <%- osd.append(node['hostname']) %>
# <%- endif %>
${ceph} orch host label add "<%= node['hostname'] %>" "<%= label %>"
# <%- end %>
# <%- end %>
# <%- monitors.each do |mon| %>
${ceph} orch apply mon "<%= mon.length() %>"
${ceph} orch apply mon "<%= mon.join(',') %>"
# <%- end %>
# <%- osd.each do |osd| %>
# <%- ['b','c','d','e','f','g','h','i','j','k'].each do |device| %>
${ceph} orch daemon add osd "<%= osd %>:/dev/sd<%= device %>"
# <%- end %>
# <%- end %>
