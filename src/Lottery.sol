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
    struct lottery{
        address addr;
        uint16 number;
    }


    uint256 public vault_balance; // 모인 돈
    // mapping(address => uint16) number_list; // 각 계정마다 제출한 번호
    // mapping(uint16 => address) number_list_swap; 
    lottery[] lottery_list; // lottery structure array
    uint public winners_num; // claim()안한 당첨자 수 체크 변수
    uint public index;
    address[] public users;

    // 약간 시간 흐름이 이해안되는데...
    // sellPhase를 어떻게 체크하지
    // 자 지금부터 sellPhase 입니다! 를 어케하쥐..
    // 하고 어케 딱 block.timestamp를 찍고 24 hours 기다리면 되나..?

    uint public time_prev;
    bool public isDraw;
    bool public isClaim;
    address[] public winners;
    uint16 public winningNum;

    // 첫번째 시도: 생성자에 time_ block.timestamp 찍어놓고 실험.. 아니면 아닌걸로..
    constructor() {
        time_prev = block.timestamp;
    }

    // 주소 중복 찾는 함수
    function find_duplicate(address[] memory user, address ad) public returns (bool) {
        for(uint i=0; i<user.length; i++){
            if(user[i] == ad){
                return false;
            }
        }
        return true;
    }

    function find_duplicate_lottery(lottery[] memory user, address ad) public returns (bool) {
        for(uint i=0; i<user.length; i++){
            if(user[i].addr == ad){
                return false;
            }
        }
        return true;
    }

    // 로또 번호를 받아서 로또 삼
    // 단, value가 없을 경우, 또는 음수, 또는 0.1 ether를 넘으면 안됨.
    // 그리고 주소가 중복이 없어야함. 로또 번호는 중복이 있을 수 있음!
    function buy(uint16 number) public payable {
        // draw time이 지났는지 확인
        require(block.timestamp-time_prev < 24 hours, "buy bbyeong");
        // 주소 중복 체크
        require(find_duplicate_lottery(lottery_list, msg.sender), "duplicate user");
        lottery_list.push(lottery(msg.sender, number));
        uint256 amount = msg.value;
        require(amount == 0.1 ether, "amount is not 1 ether");
        vault_balance += amount;
        payable(address(this)).transfer(msg.value);
        // require(address(this).balance < 0.1 ether, "not transferred");
    }

    // 추첨하는 함수
    function draw() public {
        // sellPhase인지 확인
        require(block.timestamp-time_prev >= 24 hours, "draw bbeyong");
        require(!isClaim, "claim is not yet");
        // 당첨 번호 선택
        // winner = number_list_swap[winningNum];
        winningNumber();
        for(uint i=0; i<lottery_list.length; i++){
            if(lottery_list[i].number == winningNum){
                winners.push(lottery_list[i].addr);
            }
        }
        winners_num = winners.length;
        // Draw 완료
        isDraw = true;
        // Claim 미완료
        isClaim = false;
    }

    // 당첨자들에게 당첨금 전송
    function claim() public{
        require(isDraw, "claim bbyeong");
        // winningNumber를 기재한 winners 찾음    
        for(uint i=0; i<winners.length; i++){
            if(msg.sender == winners[i]){
                payable(msg.sender).call{value: vault_balance/winners.length};
            }
        }
        winners_num--;
        // 모든 당첨자가 claim 했다면 claim 종료
        // 각종 변수 초기화
        if(winners_num == 0){
            isClaim = false;
            vault_balance = 0;
            isDraw = false;
            time_prev = block.timestamp;
            uint l = lottery_list.length;
            for(uint i=0; i<l; i++){
                lottery_list.pop();
            }
        }            
    }

    // draw하면서 당첨 번호 반환
    function winningNumber() public returns(uint16){
        uint win_idx = uint(keccak256(("win")));
        // 전역 변수에 당첨 번호 저장
        // winningNum = number_list[users[win_idx%users.length]];
        winningNum = lottery_list[win_idx%lottery_list.length].number;
        return winningNum;
    }

    receive() external payable {}
}