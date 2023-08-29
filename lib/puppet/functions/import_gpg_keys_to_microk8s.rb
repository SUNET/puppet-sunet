# frozen_string_literal: true

# Import gpg keys

Puppet::Functions.create_function(:import_gpg_keys_to_microk8s) do
  configmap = 'kind: ConfigMap
apiVersion: v1
metadata:
  labels:
    app.kubernetes.io/instance: argocd
    app.kubernetes.io/name: argocd-gpg-keys-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-gpg-keys-cm
  namespace: argocd
data:
'
  Dir.glob('/etc/cosmos/keys/*.pub') do |file|
    fingerprint = `gpg --quiet --with-colons --import-options show-only --import --fingerprint < #{file} | grep "^pub:" | awk -F ':' '{print $5}'`
    contents = `cat #{file} | sed 's/^/    /'`
    configmap += '  ' + fingerprint.chop + ": |-\n"
    configmap += contents
  end
  tempfile = Tempfile.new('configmap_temp')
  begin
    tempfile.write <<~FILE
      #{configmap}
    FILE
    tempfile.close
    `microk8s kubectl apply -f #{tempfile.path}`
  ensure
    tempfile.delete
  end
end
