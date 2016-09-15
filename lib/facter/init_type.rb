Facter.add(:init_type) do
  setcode '(test x`pidof init | awk \'{print $NF}\'` = x1 && echo init) || (test x`pidof systemd | awk \'{print $NF}\'` = x1 && echo systemd) || echo unknown'
end
