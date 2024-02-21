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
echo "export SIDE_CHAIN_ID=side-testnet-1" >> $HOME/.bash_profile
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
cd $HOME
git clone -b dev https://github.com/sideprotocol/sidechain && cd sidechain
git checkout 0.0.1-75-gbd63479
make install

# config
sided config chain-id $SIDE_CHAIN_ID
sided config keyring-backend test

# init
sided init $NODENAME --chain-id $SIDE_CHAIN_ID

# download genesis and addrbook
wget -O $HOME/.sidechain/config/genesis.json "https://raw.githubusercontent.com/sideprotocol/testnet/main/shambhala/genesis.json"
wget -O $HOME/.sidechain/config/addrbook.json "https://raw.githubusercontent.com/obajay/nodes-Guides/main/Projects/Side_Protocol/addrbook.json"

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.005uside\"|" $HOME/.sidechain/config/app.toml

# set peers and seeds
SEEDS="9c14080752bdfa33f4624f83cd155e2d3976e303@side-testnet-seed.itrocket.net:45656"
PEERS="bbbf623474e377664673bde3256fc35a36ba0df1@side-testnet-peer.itrocket.net:45656,2ca1a2f1170df5ecb55dcae5e976d6dbb85e3b6b@65.109.92.148:61456,5e0b5f26e4c069fbcaac1ae4b22aba151e463a52@65.108.79.241:60856,16cebdbf581b41757e66a8b5123db0248acf2ecc@207.244.230.15:26656,316af403caf9263cf55c721ae33b0a8e0ae27a8d@109.123.238.54:26656,a442702f898c77bd1d09ffbbc683946f437c2ac1@209.145.55.218:56656,91b6c3d622e28752c428091ca47eb463b63d14de@162.55.4.42:11356,08f006100a637b2fea09eab6c124949fe437af3e@37.27.69.161:36656,3e3c20f6881e8301b318d100d6cc37ac2cfcfa04@37.27.27.203:26656,47569def38066753b1d2f1193695ee7fe86571da@159.69.86.235:26656,656004608d89d1fd96b6118d877c3d11c26cd8ba@195.201.241.107:56146"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.sidechain/config/config.toml

# disable indexing
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.sidechain/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.sidechain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.sidechain/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.sidechain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.sidechain/config/app.toml
sed -i "s/snapshot-interval *=.*/snapshot-interval = 0/g" $HOME/.sidechain/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.sidechain/config/config.toml

# create service
sudo tee /etc/systemd/system/sided.service > /dev/null << EOF
[Unit]
Description=Side Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which sided) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

# reset
sided tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book 
curl https://testnet-files.itrocket.net/side/snap_side.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.sidechain

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
--amount=10000000uside \
--pubkey=$(sided tendermint show-validator) \
--moniker="$NODENAME" \
--chain-id=side-testnet-1 \
--commission-rate=0.1 \
--commission-max-rate=0.2 \
--commission-max-change-rate=0.05 \
--min-self-delegation=1 \
--from=wallet \
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
