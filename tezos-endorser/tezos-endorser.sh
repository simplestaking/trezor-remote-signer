#!/bin/sh
export TEZOS_CLIENT_UNSAFE_DISABLE_DISCLAIMER=Y

# wait for remote signer to load, move to Docker file 
sleep 5s 

# remote Tezos node 
ADDRESS=zeronet.simplestaking.com
PORT=3000
TLS='--tls'

# signer node 
SIGNER_ADDRESS=trezor-remote-signer
SIGNER_PORT=5000

# BIP32 path for Trezor T
HW_WALLET_HD_PATH='"m/44'\''/1729'\''/3'\''"'

# stop staking
"$(curl --request GET http://$SIGNER_ADDRESS:$SIGNER_PORT/stop_staking --silent \
         --header 'Content-Type: application/json' )"

# register/get public key hash for BIP32 path
PUBLIC_KEY_HASH="$(
    curl --request POST http://$SIGNER_ADDRESS:$SIGNER_PORT/register --silent \
         --header 'Content-Type: application/json' \
         --data $HW_WALLET_HD_PATH  | jq -r '.pkh' )"

if [ -z $PUBLIC_KEY_HASH ]; then
    echo "[-][ERROR]Can not get Tezos address for $HW_WALLET_HD_PATH"
    exit 0;
fi

echo "[+][hw-wallet] address: $PUBLIC_KEY_HASH "
echo "[+][hw-wallet] path: $HW_WALLET_HD_PATH"
echo "[+][hw-wallet] balance: $(tezos-client --addr $ADDRESS --port $PORT $TLS get balance for $PUBLIC_KEY_HASH)"

# register HD wallet for remote signer 
echo -e "\n[+][hw-wallet] import remote wallet secret key:\n$(
    tezos-client --addr $ADDRESS --port $PORT $TLS \
    import secret key $PUBLIC_KEY_HASH http://$SIGNER_ADDRESS:$SIGNER_PORT/$PUBLIC_KEY_HASH --force
)"

echo -e "\n[+][hw-wallet] import remote wallet public key:\n$(
    tezos-client --addr $ADDRESS --port $PORT $TLS \
    import public key $PUBLIC_KEY_HASH http://$SIGNER_ADDRESS:$SIGNER_PORT/$PUBLIC_KEY_HASH --force
)"


# start staking !!! only before 
"$(curl --request GET http://$SIGNER_ADDRESS:$SIGNER_PORT/start_staking --silent \
         --header 'Content-Type: application/json' )"

# echo -e "\n[+][hw-wallet] launch endorser:\n$(
#     tezos-endorser-alpha man
# )"

echo -e "\n[+][hw-wallet] launch endorser:\n$(
    tezos-endorser-alpha --addr $ADDRESS --port $PORT $TLS \
    --remote-signer http://$SIGNER_ADDRESS:$SIGNER_PORT run
)"

# nohup ./tezos-endorser-alpha --remote-signer http://<signer address>:<signer port> run > endorser.out &
