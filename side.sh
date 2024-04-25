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
curl -Ls https://snapshots.kjnodes.com/side-testnet/addrbook.json > $HOME/.side/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.005uside\"|" $HOME/.side/config/app.toml

# set peers and seeds
SEEDS="3f472746f46493309650e5a033076689996c8881@side-testnet.rpc.kjnodes.com:17459"
PEERS="1ff34876dfe93595162be61d78077c659da12f83@5.78.72.132:45656,64bc7a0fb50832ff70b11d633038486c912d5220@170.64.163.55:26656,df9dca402aff2752fc4d9ec6cb34aa37081e3e8b@94.72.104.144:34656,c64269c9bf680c8e138a5c0edd96930dcd0e2d70@213.136.82.215:22656,d5519e378247dfb61dfe90652d1fe3e2b3005a5b@65.109.68.190:17456,13fed4c734fc7ce5ab8a45bb6ee6f17f56a2b81b@95.216.102.121:63656,0002b621cdbcfc3f1add3665388d4b2fb010f7bb@65.21.177.45:26656,2159231e79d9ef2f4449e2dc058051b249911a03@86.48.3.91:22656,c3121ca01e8ad3c42c9a0e882d25867f6bd43d5b@103.107.183.177:26656,090568980667d1eb93e1582e6364ed75af30d353@45.137.192.145:34656,226302b68593cb7555ef477ba3973a606ecf4ac7@62.195.206.235:26656,49b11f36ad5ae37b9dc64ee5d4f02b8b1d62fa52@46.4.244.57:17656,bb2ef83a901a1eda9c2afb3acf90209e50edca8e@94.130.22.89:46656,7f092f83a887a3403885ea50e287747fefff6bfb@95.217.119.244:46656,9653dac771d12ed7859ade9638bd41c6652daedb@95.217.160.137:26656,98b9341458cab1b33f8968950ed005b77e076417@161.97.149.123:26656,62681254a4e21617957126647cc0464ea8c3e245@185.197.194.75:26656,19d7be686bef69b85199ce2d7dfacb10f1551f00@38.242.237.35:26656,d70e7f531e0d3f93597aa6fde117e4d8b40202af@144.217.68.182:26356,9c22ba21ebbc1ddd2099a6f9d72a5b70536fb13e@95.164.16.240:34656,11ad75d38e3e3bf1a33152d1469e79e96c9179f9@65.109.38.208:55656,ccfd161662ec4450ffdf2dfa118d817dbe3fe5e2@157.90.181.186:16456,f9f33e95997933f77ee71c835105e045f8ac6402@37.60.240.206:45656,50dc0d16484b08a7bd3f60526336976fc8d9cc34@85.208.48.44:26656,cbecdcc25c3990ec1f59839ae50f27faeb665527@65.21.32.36:46656,fe54f3964664592b3be89eb685cc72e9aecb14e9@135.181.210.171:21306,1095a2610a21b46263d9e0b1c5e97d1872d008c2@109.199.96.103:34656,85cfebdb59615a1bf427106a32b30c91568fd52a@135.181.216.54:3450"
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
curl https://snapshots-testnet.nodejumper.io/side-testnet/side-testnet_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.side

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
