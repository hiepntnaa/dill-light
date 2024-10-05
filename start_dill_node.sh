#! /bin/bash

_ROOT="$(pwd)" && cd "$(dirname "$0")" && ROOT="$(pwd)"
ROOT=$(cd "$(dirname "$0")";pwd)
PJROOT="$ROOT"

tlog() {
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') > $*"
}

print_usage(){
    echo "Usage: $0 --pwdfile <wallet-password-file> --natIP [public-ip] --keydir [validator-key-dir] "
    echo
    echo "Example: $0"
    echo "Example: $0 --pwdfile /home/ubuntu/password.txt"
    echo "Example: $0 --pwdfile /home/ubuntu/password.txt --keydir /home/ubuntu/key"
    echo "Example: $0 --pwdfile /home/ubuntu/password.txt --keydir /home/ubuntu/key --natIP 23.91.97.101"
    exit
}

#if [ $# -lt 1 ];then
#    print_usage
#fi

TEMP=$(getopt -o 'k:n:p:' --long 'keydir:,natIP:,pwdfile:' -n 'example.bash' -- "$@")
if [ $? -ne 0 ]; then
        echo 'Terminating...' >&2
        exit 1
fi

# Note the quotes around "$TEMP": they are essential!
eval set -- "$TEMP"
unset TEMP

NODE_BIN="dill-node"
NAT_IP=""
PEER_ENR=""
PEER_ID=""
KEY_DIR="$PJROOT/keystore"
KEY_PWD_FILE=""

while true; do
        case "$1" in
                '-k'|'--keydir')
                        echo "Option --keydir, argument '$2'"
                        KEY_DIR=$2
                        shift 2
                        continue
                ;;
                '-p'|'--pwdfile')
                        echo "Option --pwdfile, argument '$2'"
                        KEY_PWD_FILE=$2
                        shift 2
                        continue
                ;;
                '-n'|'--natIP')
                        echo "Option --natIP, argument '$2'"
                        NAT_IP=$2
                        shift 2
                        continue;;
                '--') shift; break;;
                *) echo 'bad flag input!' >&2; exit 1;;
        esac
done

echo 'Remaining arguments:'
for arg; do
        echo "--> '$arg'"
done

if [ -z "$KEY_PWD_FILE" ];then
    KEY_PWD_FILE="$PJROOT/validator_keys/keystore_password.txt"    
    if [ ! -f "$KEY_PWD_FILE" ]; then
        KEY_PWD_FILE="$PJROOT/walletPw.txt"
        if [ ! -f "$KEY_PWD_FILE" ]; then
            echo "cannot find file: $PJROOT/validator_keys/keystore_password.txt, please make sure it exists and is a file with your password inside"
            exit 1
        fi
    fi
fi

LIGHT_PROC_ROOT=$PJROOT/light_node
FULL_PROC_ROOT=$PJROOT/full_node
has_light=0
has_full=0
if [ -d $LIGHT_PROC_ROOT ];then
    has_light=1
fi
if [ -d $FULL_PROC_ROOT ];then
    has_full=1
fi
if [ $has_light -eq 1 ] && [ $has_full -eq 1 ]; then
    echo "Error: Both light_node and full_node directories exist. Please ensure only one of them is present."
    exit 1
fi
if [ $has_light -eq 0 ] && [ $has_full -eq 0 ]; then
    echo "Error: Neither light_node nor full_node directory exists. Please ensure one of them is present."
    exit 1
fi

if [ $has_light -eq 1 ];then
    PROC_ROOT=$PJROOT/light_node
else
    PROC_ROOT=$PJROOT/full_node
fi
DATA_ROOT=$PROC_ROOT/data
LOG_ROOT=$PROC_ROOT/logs

default_port_file="default_ports.txt"

PORT_FLAGS=""
port_occupied=""
declare -A ports_used
while read line; do
    kv=($line)
    flag=${kv[0]}
    port=${kv[1]}
    protocol=${kv[2]}
    for ((i=0; i<1000; i++)); do
        port_start=$port
        if [[ ${ports_used[$port]} -eq 1 ]]; then
            port=$(($port+1))
            continue
        fi

        if [ "$protocol" == "udp" ]; then
            lsof -iUDP:$port -n -P > /dev/null
        elif [ "$protocol" == "tcp" ]; then
            lsof -iTCP:$port -n -P -s tcp:listen > /dev/null
        else
            lsof -iTCP:$port -n -P -s tcp:listen > /dev/null || lsof -iUDP:$port -n -P > /dev/null
        fi
        if [ $? -eq 0 ]; then
            tlog "$protocol port $port occupied, try port $(($port+1))"
            port=$(($port+1))
            port_occupied="yes"
        else 
            port_occupied=""
            break
        fi
    done
    if [ ! -z "$port_occupied" ]; then
        echo "after try 1000 times, no available ports [$port_start, $port] found, exit"
        exit 1
    fi
    PORT_FLAGS="$PORT_FLAGS --$flag $port"
    ports_used[$port]=1
done < $default_port_file

echo "using password file at $KEY_PWD_FILE"


ensure_path(){
    path=$1
    if [ ! -d $path ]; then
        mkdir -p $path
    fi
}

if [ ! -z "$NAT_IP" ]; then
    DISCOVERY_FLAGS="--exec-nat extip:$NAT_IP --p2p-host-ip $NAT_IP"
fi

VALIDATOR_FLAGS="--embedded-validator --validator-datadir $DATA_ROOT/validatordata --wallet-password-file $KEY_PWD_FILE "

if [ ! -z "$KEY_DIR" ]; then
    VALIDATOR_FLAGS="$VALIDATOR_FLAGS --wallet-dir $KEY_DIR "
fi

if [ $has_light -eq 1 ];then
    # start light node
    COMMON_FLAGS="--light --datadir $DATA_ROOT/beacondata \
    --genesis-state $ROOT/genesis.ssz --grpc-gateway-host 0.0.0.0 --initial-validators $ROOT/validators.json \
    --block-batch-limit 128 --min-sync-peers 1 --minimum-peers-per-subnet 1 \
    --alps --enable-debug-rpc-endpoints \
    --suggested-fee-recipient 0x1a5E568E5b26A95526f469E8d9AC6d1C30432B33 \
    --log-format json --verbosity error --log-file $LOG_ROOT/dill.log \
    --exec-http --exec-http.api eth,net,web3 --exec-gcmode archive --exec-syncmode full --exec-mine=false --accept-terms-of-use "
    
    echo "start light node"
    
    $PJROOT/$NODE_BIN $COMMON_FLAGS $DISCOVERY_FLAGS $VALIDATOR_FLAGS $PORT_FLAGS > /dev/null &
    
    echo "start light node done"
else
    # start full node
    COMMON_FLAGS=" --datadir $DATA_ROOT/beacondata \
    --genesis-state $ROOT/genesis.ssz --grpc-gateway-host 0.0.0.0 --initial-validators $ROOT/validators.json \
    --block-batch-limit 128 --min-sync-peers 1 --minimum-peers-per-subnet 1 \
    --alps --enable-debug-rpc-endpoints \
    --suggested-fee-recipient 0x1a5E568E5b26A95526f469E8d9AC6d1C30432B33 \
    --log-format json --verbosity error --log-file $LOG_ROOT/dill.log \
    --exec-http --exec-http.api eth,net,web3 --exec-gcmode archive --exec-syncmode full --exec-mine=false --accept-terms-of-use "
    
    echo "start full node"
    
    $PJROOT/$NODE_BIN $COMMON_FLAGS $DISCOVERY_FLAGS $VALIDATOR_FLAGS $PORT_FLAGS > /dev/null &
    
    echo "start full node done"
fi
