// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./ILendingPoolInfo.sol";

/**
 * @title ILendingPool interface
 * @notice The interface for the lending pool contract.
 * @author Mara
 **/

interface ILendingPool {
  /**
   * @notice Returns the health status of account.
   **/
  function isAccountHealthy(address _account) external view returns (bool);

  /**
   * @notice Returns the LendingPoolInfo.
   **/
  function lendingPoolInfo() external view returns (ILendingPoolInfo);

}
