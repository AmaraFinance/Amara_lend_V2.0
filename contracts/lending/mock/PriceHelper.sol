// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./HomoraMath.sol";

import "../interfaces/AggregatorV3Interface.sol";
import "../openzeppelin/contracts/access/Ownable.sol";

contract PriceHelper is Ownable {

    using SafeMath for uint;
    using HomoraMath for uint;

    event SetManagerInfo(address managerInfo);
    event setSwapAddress(address swapaddress);
    event SetProxy(address token, address proxy);
    event AddAlpTokens(address token);

    address public managerInfo;
    address public swapaddress;
    address[] public aLpTokens;
    mapping(address => address) public tokenToUsdaProxys;

    function setManagerInfo(address _managerInfo) public onlyOwner {
        managerInfo = _managerInfo;
        emit SetManagerInfo(_managerInfo);
    }

    function setswapAddress(address _swapaddress) public onlyOwner{
        swapaddress=_swapaddress;
        emit setSwapAddress(swapaddress);
    }

    function setProxy(address token, address proxy) public onlyOwner {
        tokenToUsdaProxys[token] = proxy;
        emit SetProxy(token, proxy);
    }

    function addAlpTokens(address token) public {
        require(address(msg.sender) == managerInfo, "not from managerInfo");
        for (uint256 i = 0; i < aLpTokens.length; i++) {
            require(aLpTokens[i] != token, "aLP token already exists");
        }
        aLpTokens.push(token);
        emit AddAlpTokens(token);
    }

    function isAlpToken(address token) public view returns (bool) {
        for (uint256 i = 0; i < aLpTokens.length; i++) {
            if (aLpTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    /**
     * @param _proxy https://docs.chain.link/docs/reference-contracts/
     * Returns the latest price
     */
    function getLatestPriceFromOracle(address _proxy) public view returns (int) {
        (, int price,,,) = AggregatorV3Interface(_proxy).latestRoundData();
        uint8 decimals = AggregatorV3Interface(_proxy).decimals();
        return price * (10 ** 8) / (int)(10 ** decimals);
    }

    function getTokenPriceAsUsd(address token) public view returns (uint) {
        return uint(getLatestPriceFromOracle(tokenToUsdaProxys[token]));
    }

    function getAssetPrice(address _asset) public view returns (uint256) {
        return getTokenPriceAsUsd(_asset);
    }
}
