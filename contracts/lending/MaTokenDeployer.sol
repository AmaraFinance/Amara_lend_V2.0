// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.11;

import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ILendingPool.sol";
import "./MaToken.sol";

/**
 * @title token deployer
 * @notice Implements token deployer
 * @author Al
 */

contract MaTokenDeployer {
  /**
   * @dev deploy for the lending pool
   * @param _name the name of
   * @param _symbol the token symbol
   * @param _underlyingAsset the underlying ERC20 token of the AlToken
   */
  function createNewMaToken(
    string memory _name,
    string memory _symbol,
    ERC20 _underlyingAsset,
    address _realOwner
  ) public returns (MaToken) {
    MaToken maToken = new MaToken(_name, _symbol, ILendingPool(msg.sender), _underlyingAsset);
    maToken.transferOwnership(_realOwner);
    return maToken;
  }
}
