// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.11;

import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IReceiver.sol";
import "./interfaces/ILendingPool.sol";

/**
 * @title maToken contract
 * @notice Implements the altoken of the ERC20 token.
 * The maToken represent the liquidity shares of the holder on the ERC20 lending pool.
 * @author mara
 **/

contract MaToken is ERC20, Ownable, ReentrancyGuard {
  /**
   * @dev the lending pool of the MaToken
   */
  ILendingPool public lendingPool;

  /**
   * @dev the underlying ERC20 token of the MaToken
   */
  ERC20 public underlyingAsset;

  /**
   * @dev the unique reward token of the MaToken
   */
  ERC20 public rewardToken;

  /**
   * @dev the reward multiplier to calculate token rewards for the MaToken holder.
   */
  uint256 public multiplier;
  uint256 public multiplierToken;

  uint256 public startBlock;
  uint256 public lastRewardBlock;
  uint256 public tokensPerBlock;

  /**
   * @dev the latest reward of user after latest user activity.
   * Global      multiplier |-----------------|-----------------|---------------|
   *                                                                     multiplier
   * User's latest reward   |-----------------|-----------------|
   *                        start                         last block that user do any activity (received rewards)
                                                          user's latestMultiplier
   *
   * user address => latest rewards
   */
  mapping(address => uint256) public latestMultiplier;
  mapping(address => uint256) public latestMultiplierToken;

  event SetRewardToken(address rewardToken, uint256 startBlock, uint256 tokensPerBlock);
  event SetTokenPerBlock(address rewardToken, uint256 tokensPerBlock);
  event Withdraw(address token , uint256 amount);

  modifier onlyLendingPool() {
    require(msg.sender == address(lendingPool), "not from lending pool");
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    ILendingPool _lendingPool,
    ERC20 _underlyingAsset
  ) public ERC20(_name, _symbol) {
    lendingPool = _lendingPool;
    underlyingAsset = _underlyingAsset;
  }

  function setRewardToken(ERC20 _rewardToken, uint256 _startBlock, uint256 _tokensPerBlock) public onlyOwner {
    _rewardToken.totalSupply();
    rewardToken = _rewardToken;
    if(_startBlock == 0){
      _startBlock = block.number;
    }
    startBlock = _startBlock;
    tokensPerBlock = _tokensPerBlock;
    lastRewardBlock = block.number > startBlock ? block.number : startBlock;
    emit SetRewardToken(address(_rewardToken), _startBlock, _tokensPerBlock);
  }

  function setTokenPerBlock(uint256 _amount) public onlyOwner {
    tokensPerBlock = _amount;
    emit SetTokenPerBlock(address(rewardToken), tokensPerBlock);
  }

  function getTokenReleaseAmount() public view returns (uint256) {
    uint256 _toBlock = block.number;
    if (lastRewardBlock >= _toBlock || _toBlock <= startBlock) {
      return 0;
    }
    return (_toBlock - lastRewardBlock) * tokensPerBlock;
  }

  function withdraw(ERC20 _token, uint256 _amount) public onlyOwner {
    _token.transfer(address(msg.sender), _amount);
    emit Withdraw(address(_token), _amount);
  }

  /**
   * @dev mint maToken to the address equal to amount
   * @param _account the account address of receiver
   * @param _amount the amount of maToken to mint
   * Only lending pool can mint maToken
   */
  function mint(address _account, uint256 _amount) external onlyLendingPool {
    _claimCurrentReward(_account);
    _mint(_account, _amount);
  }

  /**
   * @dev burn maToken of the address equal to amount
   * @param _account the account address that will burn the token
   * @param _amount the amount of maToken to burn
   * Only lending pool can burn maToken
   */
  function burn(address _account, uint256 _amount) external onlyLendingPool {
    _claimCurrentReward(_account);
    _burn(_account, _amount);
  }

  /**
   * @dev receive token from the LendingPoolInfo
   * @param _amount the amount of to receive
   */
  function receiveToken(uint256 _amount, uint256 _tokenAmount) external {
    require(msg.sender == address(lendingPool), "Only lending pool can call receive Token");
    if(_amount > 0){
      lendingPool.lendingPoolInfo().mara().transferFrom(msg.sender, address(this), _amount);
    }

    // Don't change multiplier if total supply equal zero.
    if (totalSupply() == 0) {
      return;
    }
    multiplier = multiplier.add(_amount.mul(1e12).div(totalSupply()));
    multiplierToken = multiplierToken.add(_tokenAmount.mul(1e12).div(totalSupply()));
    lastRewardBlock = block.number;
  }

  /**
   * @dev calculate reward of the user
   * @param _account the user account address
   * @return the amount of rewards
   */
  function calculateMaraReward(address _account) public view returns (uint256) {
    //               reward start block                                        now
    // Global                |----------------|----------------|----------------|
    // User's latest reward  |----------------|----------------|
    // User's       rewards                                    |----------------|
    // reward = [(Global   multiplier - user's lastest multiplier) * user's token] / 1e12
    return
      (multiplier.sub(latestMultiplier[_account]).mul(balanceOf(_account))).div(1e12);
  }
  function calculateTokenReward(address _account) public view returns (uint256) {
    return
    (multiplierToken.sub(latestMultiplierToken[_account]).mul(balanceOf(_account))).div(1e12);
  }

  /**
   * @dev claim user's pending rewards(MARA and reward token) by lendingPool as a lender
   * @param _account the user account address
   */
  function claimCurrentRewardByLendingPool(address _account) external onlyLendingPool {
    _claimCurrentReward(_account);
  }

  /**
   * @dev claim user's pending rewards by owner as a lender
   * @param _account the user account address
   */
  function sendBorrowReward(address _account, uint256 _amount) external onlyLendingPool {
    _safeTransferRewardToken(_account, _amount);
  }

  /**
   * @dev  transfer maToken to another account
   * @param _from the sender account address
   * @param _to the receiver account address
   * @param _amount the amount of maToken to burn
   * Lending pool will check the account health of the sender. If the sender transfer alTokens to
   * the receiver then the sender account is not healthy, the transfer transaction will be revert.
   * Also claim the user rewards and set the new user's latest reward
   */
  function _transfer(
    address _from,
    address _to,
    uint256 _amount
  ) internal override {
    _claimCurrentReward(_from);
    _claimCurrentReward(_to);
    super._transfer(_from, _to, _amount);
    require(lendingPool.isAccountHealthy(_from), "Transfer tokens is not allowed");
  }

  /**
   * @dev claim the pending rewards from the latest rewards giving to now
   * @param _account the user account address
   */
  function _claimCurrentReward(address _account) internal {
    // No op if LendingPoolInfo didn't be set in lending pool.
    if (address(lendingPool.lendingPoolInfo()) == address(0)) {
      return;
    }
    uint256 pending = calculateMaraReward(_account);
    uint256 pendingToken = calculateTokenReward(_account);
    uint256 bal = lendingPool.lendingPoolInfo().mara().balanceOf(address(this));

    pending = pending < bal ? pending : bal;
    lendingPool.lendingPoolInfo().mara().transfer(_account, pending);
    _safeTransferRewardToken(_account, pendingToken);

    latestMultiplier[_account] = multiplier;
    latestMultiplierToken[_account] = multiplierToken;
  }

  function _safeTransferRewardToken(address _account, uint256 _amount) internal {
    if (address(rewardToken) == address(0)) {
      return;
    }
    uint256 bal = rewardToken.balanceOf(address(this));
    if (bal > 0 && _amount > 0){
      _amount = _amount < bal ? _amount : bal;
      rewardToken.transfer(_account, _amount);
    }
  }
}
