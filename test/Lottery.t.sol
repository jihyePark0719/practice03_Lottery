// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    uint256 received_msg_value;
    function setUp() public {
       lottery = new Lottery();
       received_msg_value = 0;
       vm.deal(address(this), 100 ether);
       vm.deal(address(1), 100 ether);
       vm.deal(address(2), 100 ether);
       vm.deal(address(3), 100 ether);
    }

    // 로또를 사기위해 0.1 ether와 로또 번호를 넣음
    function testGoodBuy() public {
        lottery.buy{value: 0.1 ether}(0);
    }

    // 이더 안주면 안됨!
    function testInsufficientFunds1() public {
        vm.expectRevert();
        lottery.buy(0);
    }

    function testInsufficientFunds2() public {
        vm.expectRevert();
        // 이건 뭐지..? 0.1 ether - 1 같은 값은 넘겨주면안됨......
        lottery.buy{value: 0.1 ether - 1}(0);
    }

    function testInsufficientFunds3() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether + 1}(0);
    }

    // ㅇㅇ가 중복되면 안됨. 뭐가..? 아 주소네
    function testNoDuplicate() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.expectRevert();
        lottery.buy{value: 0.1 ether}(0);
    }

    // 근데 이건 된단말이지..?
    // sellPhase 동안 (24 hours) 에는 사도됨
    function testSellPhaseFullLength() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        // 주소바꿔서 로또삼
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }

    // phase가 끝난 후에는 살 수 없음
    function testNoBuyAfterPhaseEnd() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        vm.expectRevert();
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }

    // sellPhase동안에는 draw할 수 없음
    function testNoDrawDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.draw();
    }

    // sell기간동안에는 claim을 할 수 없음
    function testNoClaimDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.claim();
    }

    // draw 테스트
    function testDraw() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
    }

    // 다음 우승 번호를 획득
    function getNextWinningNumber() private returns (uint16) {
        // 현재 스냅샷 찍음
        uint256 snapshotId = vm.snapshot();
        // 로또 삼
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        // sellPhase = 24 hours 지난 후 draw 진행
        lottery.draw();
        // winning number 얻음
        uint16 winningNumber = lottery.winningNumber();
        vm.revertTo(snapshotId);
        return winningNumber;
    }

    // 이겼을때 claim 되는지 확인
    function testClaimOnWin() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        // 이게 약간.. 이해가 안가는디;; 뭔소리야
        // lottery 컨트랙트의 balance가 0.1여야한다는거임..??
        uint256 expectedPayout = address(lottery).balance;
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, expectedPayout);
    }

    // 졌을때 claim 걸리면 안됨
    function testNoClaimOnLose() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0);
    }

    // claimPhase 일때는 draw를 할 수 없음.
    function testNoDrawDuringClaimPhase() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        vm.expectRevert();
        lottery.draw(); // 여기서 draw되면 안됨
    }

    // Rollover 테스트
    // 두 번 참여해서 한번만 당첨되었을 때, 최종적으로 0.2 ether를 가지고 있어야 함.
    function testRollover() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();

        winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0.2 ether);
    }

    // 같은 번호로 당첨됐을 경우, 다른 주소들이 각각 받을 수 있는가
    // 당첨금 나눠야함!
    function testSplit() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.deal(address(1), 0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();

        lottery.claim();
        assertEq(received_msg_value, 0.1 ether);

        vm.prank(address(1));
        lottery.claim();
        assertEq(address(1).balance, 0.1 ether);
    }

    receive() external payable {
        // 외부에서 받은 값 여기에 저장
        received_msg_value = msg.value;
    }
}