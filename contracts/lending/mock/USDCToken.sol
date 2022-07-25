pragma solidity 0.6.11;

import "../openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDTToken is ERC20("USDC", "USDC") {
  constructor() public {
    _setupDecimals(6);
  }

  function mint(address _account, uint256 _amount) external {
    _mint(_account, _amount);
  }

  function burn(address _account, uint256 _amount) external {
    _burn(_account, _amount);
  }
}
