// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

/**
 * @title receiver interface
 * @notice The interface of token reward receiver
 * @author Mara
 **/

interface IReceiver {
  /**
   * @notice receive token from the LendingPoolInfo
   * @param _amount the amount of token to receive
   */
  function receiveToken(uint256 _amount) external;
}
