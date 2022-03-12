pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import 'hardhat/console.sol';
import './ExampleExternalContract.sol';

contract Staker {
  mapping(address => uint256) private _balances;

  event Stake(address from, uint256 amount);

  uint256 public constant threshold = 1 ether;

  uint256 private _stakeDeadline;
  bool private _openForWithdraw = false;

  error WithdrawalNotOpenedYet();
  error YouhaveNothingToWithdraw();
  error AlreadyCompleted();

  ExampleExternalContract public exampleExternalContract;

  modifier notCompleted() {
    if (exampleExternalContract.completed()) revert AlreadyCompleted();
    _;
  }

  constructor(address exampleExternalContractAddress) {
    exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  function balances(address staker) external view returns (uint256) {
    return _balances[staker];
  }

  // Collect funds in a payable `stake()` function and track individual `_balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() external payable notCompleted {
    _balances[msg.sender] += msg.value;
    _stakeDeadline = block.timestamp + 30 seconds;
    _openForWithdraw = false;
    emit Stake(msg.sender, msg.value);
  }

  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() external {
    uint256 time = this.timeLeft();

    if (time == 0 && address(this).balance >= threshold) {
      exampleExternalContract.complete();
    } else {
      _openForWithdraw = time == 0;
    }
  }

  // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  function withdraw(address payable destination) external returns (bool) {
    if (_openForWithdraw == false) revert WithdrawalNotOpenedYet();

    uint256 amount = _balances[msg.sender];
    if (amount > 0) {
      _balances[msg.sender] = 0;

      (bool success, ) = destination.call{value: amount}('');

      if (!success) {
        _balances[msg.sender] = amount;
        return false;
      }
    }
    return true;
  }

  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() external view returns (uint256) {
    if (block.timestamp >= _stakeDeadline) {
      return 0;
    } else {
      return _stakeDeadline - block.timestamp;
    }
  }

  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable {
    this.stake();
  }
}
