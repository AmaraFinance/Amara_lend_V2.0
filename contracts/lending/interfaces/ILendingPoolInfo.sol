// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title LendingPoolInfo interface
 * @notice The interface of lending pool info for token rewards
 * @author Mara
 **/

interface ILendingPoolInfo {
  /**
   * @notice get the token of the LendingPoolInfo
   * @return Token - the token
   */
  function mara() external view returns (ERC20);

  /**
   * @notice distribute the token to the receivers
   */
  function distributeMara() external;
}
