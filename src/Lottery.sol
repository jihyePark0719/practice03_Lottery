// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract Lottery{
    // << 전체적인 흐름 >>
    // 1. 로또 값과 로또 번호가 기입된 로또를 팜
    // 2. 로또 값을 돈에다 모으고, 로또 번호도 mapping?해서 모음
    // 3. 위 과정을 일정 시간(sellPhase) 동안 진행
    // 4. 일정 시간(sellPhase)이 끝나면 draw 진행
    // 5. 당첨된 번호는 claim을 걸어 값 수령

    // 필요한 변수
    // (1) 건 돈을 모으는 변수 나중에 claim할때 필요
    // (2) block.time 해서 시간 제한 걸어두기. sellPhase 등등을 확인


    // mapping(address => uint256) balance;
    uint256 public vault_balance; // 모인 돈

    // 약간 시간 흐름이 이해안되는데...
    // sellPhase를 어떻게 체크하지
    // 자 지금부터 sellPhase 입니다! 를 어케하쥐..
    // 하고 어케 딱 block.timestamp를 찍고 24 hours 기다리면 되나..?

    uint public time_prev;
    address[] public winners;
    uint16 public winningNum = 1234;

    mapping(address => uint256) public balance;
    // 참여했는지 확인
    mapping(address => bool) public isIn;

     constructor() {
        time_prev = block.timestamp;
    }

    // 로또 번호를 받아서 로또 삼
    // 단, value가 없을 경우, 또는 음수, 또는 0.1 ether를 넘으면 안됨.
    // 그리고 주소가 중복이 없어야함. 로또 번호는 중복이 있을 수 있음!
    function buy(uint16 number) public payable {
        // draw time이 지났는지 확인
        require(block.timestamp-time_prev < 24 hours, "buy");
        // 참여했는지 체크
        require(isIn[msg.sender] == false, "duplicate user");
        // 0.1 ether가 맞는지 체크
        require(msg.value == 0.1 ether, "amount is not 1 ether");
        balance[msg.sender] = msg.value;
        vault_balance += msg.value;
        isIn[msg.sender] = true;
        // winning number와 같다면
        if(number == winningNum){
            winners.push(msg.sender);
        }
    }

    // 추첨하는 함수
    function draw() public {
        // sellPhase인지 확인
        require(block.timestamp-time_prev >= 24 hours, "draw");
    }

    // 당첨자들에게 당첨금 전송
    function claim() public{
        require(block.timestamp-time_prev >= 24 hours, "not claim time");
        uint winnum = winners.length;
        isIn[msg.sender] = false;
        // winners에 있는지 확인
        for(uint i=0; i<winners.length; i++){
            if(msg.sender == winners[i]){
                payable(msg.sender).call{value: vault_balance/winners.length}("");
                balance[msg.sender] = 0;
                winnum--;
            }
        }
        if(winnum == 0){
            // vault_balance = 0;
            time_prev = block.timestamp;
            uint l = winners.length;
            for(uint i=0; i<l; i++){
                winners.pop();
            }
        }                 
    }

    // draw하면서 당첨 번호 반환
    function winningNumber() public returns(uint16){
        return 1234;
    }

    receive() external payable {}
}