// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address coordinator,
            bytes32 gasLine,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                coordinator,
                deployerKey
            );
        }

        //FundSubcription
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.functionSubscription(
            coordinator,
            subscriptionId,
            link,
            deployerKey
        );

        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            coordinator,
            gasLine,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        //AddConsumer
        AddConsumer addConsumerInDeploy = new AddConsumer();
        addConsumerInDeploy.addConsumer(
            address(raffle),
            coordinator,
            subscriptionId,
            deployerKey
        );
        return (raffle, helperConfig);
    }
}
