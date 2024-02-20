// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address coordinator;
    // bytes32 gasLine;
    // uint64 subscriptionId;
    // uint32 callbackGasLimit;
    // address link;
    uint256 deployerKey;

    address player = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    event EnteredRaffle(address indexed player);

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (entranceFee, interval, coordinator, , , , , deployerKey) = helperConfig
            .activeNetworkConfig();
        vm.deal(player, STARTING_BALANCE);
    }

    function testRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleEnterRevert() public {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle_NotEnoughEtherSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleEnterSuccess() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayers(0), player);
    }

    function testEnterEmitOnEvent() public {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testEnterRaffleCalculating() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_NotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnFalseHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnFalseNotOpen() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepneeded, ) = raffle.checkUpkeep("");

        assert(!upkeepneeded);
    }

    function testPerformUpkeepRunCheckUpkeepIsTrue() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    modifier enterRaffleAndPassTime() {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid == 31337) {
            return;
        }
        _;
    }

    function testPerformUpkeepRunNotEnoughTime() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRaffleStateAndEmitsRequestedId()
        public
        enterRaffleAndPassTime
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // bytes32 eventRequestId = entries[1].topics[0];
        // console.log("event:", uint256(eventRequestId));
        console.log("length", entries[1].topics.length);
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    function testFulfilRandomWordOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public enterRaffleAndPassTime {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicsAWinnerResetsAndSendMoney()
        public
        enterRaffleAndPassTime
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address playerAdditional = address(uint160(i));
            hoax(playerAdditional, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (startingIndex + additionalEntrants);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestedId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        (uint96 balance, , , ) = VRFCoordinatorV2Mock(coordinator)
            .getSubscription(1);

        console.log("SubBalance:", balance);
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            uint256(requestedId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getLastestWinner() != address(0));
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getLastestWinner().balance ==
                (STARTING_BALANCE + prize - entranceFee)
        );
    }
}
