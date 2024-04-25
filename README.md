<p align="center">
  <img height="100" height="auto" src="https://github.com/freshe4qa/side/assets/85982863/f54440bc-c276-46f1-931b-c490fc0bf941">
</p>

# Side Testnet — side-testnet-3

Official documentation:
>- [Validator setup instructions](https://docs.side.one)

Explorer:
>- [https://betanet-scan.artela.network](https://testnet.side.explorers.guru)

### Minimum Hardware Requirements
 - 4x CPUs; the faster clock speed the better
 - 8GB RAM
 - 100GB of storage (SSD or NVME)

### Recommended Hardware Requirements 
 - 8x CPUs; the faster clock speed the better
 - 16GB RAM
 - 1TB of storage (SSD or NVME)

## Set up your artela fullnode
```
wget https://raw.githubusercontent.com/freshe4qa/artela/main/side.sh && chmod +x side.sh && ./side.sh
```

## Post installation

When installation is finished please load variables into system
```
source $HOME/.bash_profile
```

Synchronization status:
```
sided status 2>&1 | jq .SyncInfo
```

### Create wallet
To create new wallet you can use command below. Don’t forget to save the mnemonic
```
sided keys add $WALLET
```

Recover your wallet using seed phrase
```
sided keys add $WALLET --recover
```

To get current list of wallets
```
sided keys list
```

## Usefull commands
### Service management
Check logs
```
journalctl -fu sided -o cat
```

Start service
```
sudo systemctl start sided
```

Stop service
```
sudo systemctl stop sided
```

Restart service
```
sudo systemctl restart sided
```

### Node info
Synchronization info
```
sided status 2>&1 | jq .SyncInfo
```

Validator info
```
sided status 2>&1 | jq .ValidatorInfo
```

Node info
```
sided status 2>&1 | jq .NodeInfo
```

Show node id
```
sided tendermint show-node-id
```

### Wallet operations
List of wallets
```
sided keys list
```

Recover wallet
```
sided keys add $WALLET --recover
```

Delete wallet
```
sided keys delete $WALLET
```

Get wallet balance
```
sided query bank balances $SIDE_WALLET_ADDRESS
```

Transfer funds
```
sided tx bank send $SIDE_WALLET_ADDRESS <TO_SIDE_WALLET_ADDRESS> 10000000uside
```

### Voting
```
sided tx gov vote 1 yes --from $WALLET --chain-id=$SIDE_CHAIN_ID
```

### Staking, Delegation and Rewards
Delegate stake
```
sided tx staking delegate $SIDE_VALOPER_ADDRESS 10000000uside --from=$WALLET --chain-id=$SIDE_CHAIN_ID --gas=auto
```

Redelegate stake from validator to another validator
```
sided tx staking redelegate <srcValidatorAddress> <destValidatorAddress> 10000000uside --from=$WALLET --chain-id=$SIDE_CHAIN_ID --gas=auto
```

Withdraw all rewards
```
sided tx distribution withdraw-all-rewards --from=$WALLET --chain-id=$SIDE_CHAIN_ID --gas=auto
```

Withdraw rewards with commision
```
sided tx distribution withdraw-rewards $SIDE_VALOPER_ADDRESS --from=$WALLET --commission --chain-id=$SIDE_CHAIN_ID
```

Unjail validator
```
sided tx slashing unjail \
  --broadcast-mode=block \
  --from=$WALLET \
  --chain-id=$SIDE_CHAIN_ID \
  --gas=auto
```
