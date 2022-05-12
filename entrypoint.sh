#!/bin/bash

set -e

mkdir -p /data/fdb

if [ ! -f "/data/mds_key.pub" ]; then
  openssl genpkey -algorithm ed25519 -outform DER -out /data/mds_key.der
  cat /data/mds_key.der | tail -c +17 | base64 > /data/mds_key.secret
  openssl pkey -outform DER -pubout -inform DER -in /data/mds_key.der | tail -c +13 | xxd -p | tr -d '\n' > /data/mds_key.pub
  echo "Generated MDS key at /data/mds_key.secret. Public key is $(cat /data/mds_key.pub)."
fi

if [ ! -f "/data/fdb.cluster" ]; then
  echo "Setting up /data/fdb.cluster."
  cp /etc/foundationdb/fdb.cluster /data/
fi

/usr/sbin/fdbserver --cluster_file /data/fdb.cluster \
  --datadir /data/fdb \
  --listen_address 127.0.0.1:4500 \
  --logdir /var/log/foundationdb \
  --public_address 127.0.0.1:4500 &

sleep 1
/fdbinit.sh

/usr/bin/blueboat-mds -l 0.0.0.0:2999 -c /mds.yaml &

/usr/bin/minio server --address 127.0.0.1:1932 --console-address :4001 /data/minio &

sleep 1

MDS_KEY="$(cat /data/mds_key.secret)" /start_blueboat.sh &

wait -n
last_status=$?

echo "A service has crashed. Shutting down."
kill $(jobs -p)
wait
exit $last_status
