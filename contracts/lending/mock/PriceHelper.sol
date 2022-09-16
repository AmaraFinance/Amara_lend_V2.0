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
    /// @dev Return the value of the given input as ETH per unit.
    /// @param pair The Uniswap pair to check the value.
    function getLpPriceAsUsdFromUniswap(address pair) public view returns (uint) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint totalSupply = IUniswapV2Pair(pair).totalSupply();
        (uint r0, uint r1, ) = IUniswapV2Pair(pair).getReserves();
        uint sqrtK = HomoraMath.sqrt(r0.mul(r1)).fdiv(totalSupply); // in 2**112
        uint px0 = getTokenPriceAsUsd(token0);
        uint px1 = getTokenPriceAsUsd(token1);
        // fair token0 amt: sqrtK * sqrt(px1/px0)
        // fair token1 amt: sqrtK * sqrt(px0/px1)
        // fair lp price = 2 * sqrt(px0 * px1)
        // split into 2 sqrts multiplication to prevent uint overflow (note the 2**112)
        return sqrtK.mul(2).mul(HomoraMath.sqrt(px0)).div(2**56).mul(HomoraMath.sqrt(px1)).div(2**56);
    }

    /// @dev Return the value of the given input as ETH per unit.
    /// @param pair The Pancakeswap pair to check the value.
    function getLpPriceAsUsdFromPancakeswap(address pair) public view returns (uint) {
        address token0 = IPancakePair(pair).token0();
        address token1 = IPancakePair(pair).token1();
        uint totalSupply = IPancakePair(pair).totalSupply();
        (uint r0, uint r1, ) = IPancakePair(pair).getReserves();
        uint sqrtK = HomoraMath.sqrt(r0.mul(r1)).fdiv(totalSupply); // in 2**112
        uint px0 = getTokenPriceAsUsd(token0);
        uint px1 = getTokenPriceAsUsd(token1);
        // fair token0 amt: sqrtK * sqrt(px1/px0)
        // fair token1 amt: sqrtK * sqrt(px0/px1)
        // fair lp price = 2 * sqrt(px0 * px1)
        // split into 2 sqrts multiplication to prevent uint overflow (note the 2**112)
        return sqrtK.mul(2).mul(HomoraMath.sqrt(px0)).div(2 ** 56).mul(HomoraMath.sqrt(px1)).div(2 ** 56);
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
