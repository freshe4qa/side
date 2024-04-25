#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export SIDE_CHAIN_ID=side-testnet-3" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# install go
if ! [ -x "$(command -v go)" ]; then
ver="1.21.3" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \
go version
fi

# download binary
cd && rm -rf sidechain
git clone https://github.com/sideprotocol/sidechain.git
cd sidechain
git checkout v0.7.0-rc2
make install

# config
sided config chain-id $SIDE_CHAIN_ID
sided config keyring-backend os

# init
sided init $NODENAME --chain-id $SIDE_CHAIN_ID

# download genesis and addrbook
curl -L https://snapshots-testnet.nodejumper.io/side-testnet/genesis.json > $HOME/.side/config/genesis.json
curl -Ls https://ss-t.side.nodestake.org/addrbook.json > $HOME/.side/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.005uside\"|" $HOME/.side/config/app.toml

# set peers and seeds
SEEDS="3f472746f46493309650e5a033076689996c8881@side-testnet.rpc.kjnodes.com:17459"
PEERS="1404e6982f5db630bcd816e1b29c9c3fa4eed7ca@139.59.212.68:26656,2a6d31c23160e49db1f03a884dc7b9602fffe895@138.201.51.154:30004,9c14080752bdfa33f4624f83cd155e2d3976e303@65.108.231.124:45656,d70e7f531e0d3f93597aa6fde117e4d8b40202af@144.217.68.182:26356,e8009e2950cbf7cf36cbd870b489225cd69c15c9@95.216.242.118:36656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.side/config/config.toml

# disable indexing
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.side/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.side/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.side/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.side/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.side/config/app.toml
sed -i "s/snapshot-interval *=.*/snapshot-interval = 0/g" $HOME/.side/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.side/config/config.toml

# create service
sudo tee /etc/systemd/system/sided.service > /dev/null << EOF
[Unit]
Description=Side node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which sided) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# reset
sided tendermint unsafe-reset-all --home $HOME/.side --keep-addr-book
SNAP_NAME=$(curl -s https://ss-t.side.nodestake.org/ | egrep -o ">20.*\.tar.lz4" | tr -d ">")
curl -o - -L https://ss-t.side.nodestake.org/${SNAP_NAME}  | lz4 -c -d - | tar -x -C $HOME/.side

# start service
sudo systemctl daemon-reload
sudo systemctl enable sided
sudo systemctl restart sided

break
;;

"Create Wallet")
sided keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
SIDE_WALLET_ADDRESS=$(sided keys show $WALLET -a)
SIDE_VALOPER_ADDRESS=$(sided keys show $WALLET --bech val -a)
echo 'export SIDE_WALLET_ADDRESS='${SIDE_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export SIDE_VALOPER_ADDRESS='${SIDE_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
sided tx staking create-validator \
--amount=9000000uside \
--pubkey=$(sided tendermint show-validator) \
--moniker="$NODENAME" \
--chain-id=side-testnet-3 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--from=wallet \
--node=https://testnet-rpc.side.one:443 \ 
--fees=80uside \
--gas=300000 \
-y
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
