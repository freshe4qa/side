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
echo "export SIDE_CHAIN_ID=side-testnet-2" >> $HOME/.bash_profile
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
git clone https://github.com/sideprotocol/side && cd side
git checkout v0.6.0
make install

# config
sided config chain-id $SIDE_CHAIN_ID
sided config keyring-backend test

# init
sided init $NODENAME --chain-id $SIDE_CHAIN_ID

# download genesis and addrbook
curl -L https://snapshots-testnet.nodejumper.io/side-testnet/genesis.json > $HOME/.side/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/side-testnet/addrbook.json > $HOME/.side/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.005uside\"|" $HOME/.side/config/app.toml

# set peers and seeds
SEEDS="693bdfec73a81abddf6f758aa49321de48456a96@13.231.67.192:26656"
PEERS="2803ac0536102d14d1231ee2ba2401220e6e5161@188.40.66.173:26356,5ed59d1430a0c99660233b03b614ca773e41d86d@154.38.169.8:26656,6202f202f52aca046f749ce8fc58ebf06a01e272@65.108.200.40:49656,520f98acd537007a9a4e3c640873d6c0cb489af7@161.97.83.250:26656,0677147b29e230036b1f4cf345e41b2e4f8b9a53@95.217.148.179:26656,e1752865a89e132f7877bae1adae5b39b6f50a9f@88.198.27.51:61056,07fd0d50993731aa3542bdec151f1c021a4c05ce@65.21.109.69:26656,907b2fe62d44e4692befce1954280647e03cd9e0@136.243.75.46:26656,70e3c646a0bd0bce52714a5d6b27cf1604405167@167.86.67.112:26656,62b28c726dbcf81ff3227af3f3da1a9cec7b2898@65.21.113.10:60856,ddfe330127fcf8a6560fa24015c28c0a29148ada@65.108.143.210:45656,e085e0a039b339afd4bb013f4533a33b34a2308b@162.55.90.36:11356,e2c6705ad3e801dd4b4e42b24df3aee4b12116e9@144.76.138.156:11356,56927fc111f04645062a3365991569e8c79e6ed6@135.181.116.152:44656,e70de8ac13045a059fb031e9e3d035252fb130eb@80.253.246.64:26656,afc5131919434d10d6912b1bb0048b887323b8f8@149.102.132.207:48656,45f2a80670a371eee2d15be7b13a607406b4b76f@23.88.70.109:11356,0d0cfeabef50825e217028f3549c437e8212d67d@135.181.112.166:11356,c3df7bc8a69f1d49186f53a51d799ebd2bf56952@65.108.206.118:46656"
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
--amount=10000000uside \
--pubkey=$(sided tendermint show-validator) \
--moniker="$NODENAME" \
--chain-id=side-testnet-2 \
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
