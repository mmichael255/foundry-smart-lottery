-include .env

.PHONY: all test deploy

help:
	@echo "Usage:"
	@echo " make deploy [ARGS=...]"

build:; forge build

install :; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

test:; forge test

NETWORK_ARGS := --rpc-url http//localhost:8545 --private-key $(PRIVATE_KEY_ANVIL) --broadcast

ifeq ($(findstring --network sepolia, $(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
endif

deploy:
	forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)
