// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./interfaces/ILendingPoolInfo.sol";
import "./interfaces/IReceiver.sol";
import "./libraries/WadMath.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LendingPoolInfo contract
 * @notice Implements LendingPoolInfo to poke token reward to the receiver
 * follow by the release rules
 * @author Mara
 */

contract LendingPoolInfo is Ownable, ReentrancyGuard, ILendingPoolInfo {
  using SafeMath for uint256;
  using WadMath for uint256;

  /**
   * @dev the token(mara) to distribute
   */
  ERC20 public override mara;

  /**
   * @dev lending pool to receive mara
   */
  IReceiver public lendingPool;

  /**
   * @dev the last block the LendingPoolInfo distribute token(mara) to the receiver(lending pool)
   */
  uint256 public lastRewardBlock;

  /**
   * @dev the start block of distribution (week0 will start from startBlock + 1 )
   */
  uint256 public immutable startBlock;

  /**
   * @dev number of token per block
   */
  uint256 public tokensPerBlock;

  event WithdrawMara(address indexed withdrawer, uint256 amount);
  event SetLendingPool(address lendingPool);
  event SetTokenPerBlock(uint256 tokensPerBlock);

  constructor(ERC20 _mara, uint256 _startBlock, uint256 _tokensPerBlock) public {
    mara = _mara;
    if(_startBlock == 0){
      _startBlock = block.number;
    }
    startBlock = _startBlock;
    lastRewardBlock = block.number > _startBlock ? block.number : _startBlock;
    tokensPerBlock = _tokensPerBlock;
  }

  function setLendingPool(IReceiver _lendingPool) public onlyOwner {
    lendingPool = _lendingPool;
    emit SetLendingPool(address(_lendingPool));
  }

  function setTokenPerBlock(uint256 _amount) public onlyOwner {
    tokensPerBlock = _amount;
    emit SetTokenPerBlock(tokensPerBlock);
  }

  /**
   * @dev distributes token to the receiver from the last distributed block to the latest block
   */
  function distributeMara() public override nonReentrant {
    require(address(lendingPool) != address(0), "lendingPool not exist");
    if (block.number < startBlock) {
      lastRewardBlock = startBlock;
      return;
    }
    if (lastRewardBlock == block.number) {
      return;
    }

    uint256 value = getMaraReleaseAmount(block.number);
    lastRewardBlock = block.number;
    uint256 bal = mara.balanceOf(address(this));
    require(bal >= value, "mara balance not enough");
    mara.approve(address(lendingPool), value);
    lendingPool.receiveToken(value);
  }

  function withdrawMara(uint256 _amount) public onlyOwner {
    mara.transfer(msg.sender, _amount);
    emit WithdrawMara(msg.sender, _amount);
  }

  /**
   * @dev get the amount of distributed token from _fromBlock + 1 to _toBlock
   * @param _toBlock calculate to the _toBlock
   */
  function getMaraReleaseAmount(uint256 _toBlock) public view returns (uint256) {
    if (lastRewardBlock >= _toBlock || _toBlock <= startBlock) {
      return 0;
    }
    return (_toBlock - lastRewardBlock) * tokensPerBlock;
  }

}
