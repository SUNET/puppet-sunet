#!/bin/bash

ceph="/usr/sbin/cephadm shell ceph"

ssh "<%= @firstmon %>" /opt/ceph/bootstrap.sh # Run bootstrap script on first monitor
scp "<%= @firstmon %>:/etc/ceph/*" /etc/ceph/ # Copy over config <% monitors = [] %><% osd = [] %><% @nodes.each do |node| %>
${ceph} orch host add "<%= node['hostname'] %>" # Add <%= node['hostname'] %><% node['labels'].each do |label| %><% if label == 'mon' %><% monitors.append(node['hostname']) %><% elsif label == 'osd' %><% osd.append(node['hostname']) %><% end %>
${ceph} orch host label add "<%= node['hostname'] %>" "<%= label %>" # <% end %> <% end %>
${ceph} orch apply mon "<%= monitors.length() %>" # Number of monitors
${ceph} orch apply mon "<%= monitors.join(',') %>" # Monitor servers <% osd.each do |osd| %><% ['b','c','d','e','f','g','h','i','j','k'].each do |device| %>
${ceph} orch daemon add osd "<%= osd %>:/dev/sd<%= device %>" # Add <%= osd %><% end %><% end %>
