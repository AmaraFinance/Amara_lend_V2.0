// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;
import "../LendingPool.sol";
import "../LendingPoolInfo.sol";
contract LendingInfoGetter is Ownable {
    using SafeMath for uint256;
    using WadMath for uint256;
    using Math for uint256;
    struct Reward {
        uint256 rewardMultiplier;
        uint256 pendingBorrowMara;
        uint256 pendingBorrowReward;
    }
    struct PoolStruct {
        ERC20 token;
        string symbol;
        uint256 balance;
        uint256 price;
        ERC20 rewardToken;
        string rewardTokenSymbol;
        uint256 totalBorrowInUSD;
        uint256 totalSupplyInUSD;
        uint256 maxBorrowInUSD;
        MaToken maToken;
        IPoolConfiguration poolConfig;
        uint256 rewardTokenPrice;
    }
    struct UserTokenList {
        ERC20 token;
        string symbol;
        uint256 status;// 0 no use, 1 deposit, 2 borrow, 3 deposit and borrow
        uint256 depositBal;
        uint256 borrowBal;
        uint256 myBalance;
        uint256 totalBorrows;
        uint256 totalBorrowShares;
        uint256 borrowShares;
        uint256 maxPurchaseShares;
        uint256 maxPurchase;
    }
    struct LiquidationInfo {
        address user;
        bool isAccountHealthy;
        uint256 totalLiquidityBalanceBase;
        uint256 totalCollateralBalanceBase;
        uint256 totalBorrowBalanceBase;
        UserTokenList[] userTokenList;
    }
    struct AccountHealthy {
        uint256 index;
        address user;
        bool isAccountHealthy;
        uint256 totalLiquidityBalanceBase;
        uint256 totalCollateralBalanceBase;
        uint256 totalBorrowBalanceBase;
        uint256 debtRatio;
    }
    struct TotalInfo {
        uint256 maraPerBlock;
        uint256 totalBorrowInUSD;
        uint256 totalSupplyInUSD;
        uint256 maraPrice;
    }
    LendingPool lendingPool;
    LendingPoolInfo lendingPoolInfo;
    IPriceOracle priceOracle;
    uint256 constant UNIT = 1 * 1e18;
    constructor(LendingPool _lendingPool, LendingPoolInfo _lendingPoolInfo) public {
        lendingPool = _lendingPool;
        lendingPoolInfo = _lendingPoolInfo;
        emit SetLendingPool(address(_lendingPool));
        emit SetLendingPoolInfo(address(_lendingPoolInfo));
    }
    function getTotalInfo() public view returns (TotalInfo memory totalInfo) {
        totalInfo.maraPerBlock = lendingPoolInfo.tokensPerBlock();
        uint256 poolLength = lendingPool.poolLength();
        totalInfo.maraPrice = priceOracle.getAssetPrice(address(lendingPoolInfo.mara()));
        for (uint256 i = 0; i < poolLength; i++) {
            (LendingPool.PoolStatus poolStatus,,,,,,uint256 totalLiquidity,,) = lendingPool.getPool(lendingPool.tokenList(i));
            if (poolStatus == LendingPool.PoolStatus.ACTIVE) {
                uint256 poolBorrow = lendingPool.totalBorrowInUSD(lendingPool.tokenList(i));
                totalInfo.totalBorrowInUSD = totalInfo.totalBorrowInUSD.add(poolBorrow);
                uint256 price = priceOracle.getAssetPrice(address(lendingPool.tokenList(i)));
                totalInfo.totalSupplyInUSD = totalInfo.totalSupplyInUSD.add(totalLiquidity.mul(price));
            }
        }
    }
    function setLendingPool(LendingPool _lendingPool) public onlyOwner {
        lendingPool = _lendingPool;
    }
    function setLendingPoolInfo(LendingPoolInfo _lendingPoolInfo) public onlyOwner {
        lendingPoolInfo = _lendingPoolInfo;
    }
    function setPriceOracle(IPriceOracle _oracle) external onlyOwner {
        priceOracle = _oracle;
    }
    function getPools() public view returns (PoolStruct[] memory tokens) {
        uint256 poolLength = lendingPool.poolLength();
        tokens = new PoolStruct[](poolLength);
        for (uint256 i = 0; i < poolLength; i++) {
            ERC20 token = lendingPool.tokenList(i);
            uint256 price = priceOracle.getAssetPrice(address(token));
            LendingPool.Pool memory pool = getPool(token);
            ERC20 rewardToken = pool.maToken.rewardToken();
            uint256 rewardTokenPrice = 0;
            string memory rewardTokenSymbol = "";
            if (address(rewardToken) != address(0)) {
                rewardTokenSymbol = rewardToken.symbol();
                rewardTokenPrice = priceOracle.getAssetPrice(address(rewardToken));
            }
            uint256 totalBorrowInUSD = lendingPool.totalBorrowInUSD(token);
            uint256 totalSupplyInUSD = lendingPool.getTotalLiquidity(token).mul(price);
            tokens[i] = PoolStruct(token, token.symbol(), token.balanceOf(msg.sender), price, rewardToken, rewardTokenSymbol, totalBorrowInUSD, totalSupplyInUSD, pool.poolConfig.getMaxBorrowInUSD(), pool.maToken, pool.poolConfig, rewardTokenPrice);
        }
    }
    function getPrice(ERC20 _token) public view returns (
        uint256 maraPrice,
        uint256 poolTokenPrice,
        uint256 rewardTokenPrice
    ) {
        LendingPool.Pool memory pool = getPool(_token);
        ERC20 mara = lendingPool.lendingPoolInfo().mara();
        ERC20 rewardToken = pool.maToken.rewardToken();
        maraPrice = priceOracle.getAssetPrice(address(mara));
        poolTokenPrice = priceOracle.getAssetPrice(address(_token));
        if (address(rewardToken) != address(0)){
            rewardTokenPrice = priceOracle.getAssetPrice(address(rewardToken));
        }
    }
    function getPoolInfo(ERC20 _token) public view returns (
        bool active,
        bool ableBorrow,
        uint256 borrowInterestRate,
        string memory maraSymbol,
        string memory rewardTokenSymbol,
        uint256 totalBorrows,
        uint256 totalBorrowShares,

    
        
          
    

        
    
    @@ -169,8 +165,6 @@ contract LendingInfoGetter is Ownable {
  
        uint256 totalLiquidity,
        uint256 maraPerBlock,
        uint256 tokenPerBlock,
        uint256 totalAvailableLiquidity
    ) {
        LendingPool.Pool memory pool = getPool(_token);
        active = pool.status == LendingPool.PoolStatus.ACTIVE ? true : false;
        ableBorrow = pool.ableBorrow;
        totalLiquidity = lendingPool.getTotalLiquidity(_token);
        totalAvailableLiquidity = lendingPool.getTotalAvailableLiquidity(_token);
        borrowInterestRate = pool.poolConfig.calculateInterestRate(pool.totalBorrows, totalLiquidity);
        totalBorrows = pool.totalBorrows;
        totalBorrowShares = pool.totalBorrowShares;

        (uint256 borrow, uint256 totalBorrow) = _getBorrowValue(_token);
        if (totalBorrow != 0 && pool.status == LendingPool.PoolStatus.ACTIVE) {
            maraPerBlock = lendingPoolInfo.tokensPerBlock().mul(borrow).div(totalBorrow);
            tokenPerBlock = pool.maToken.tokensPerBlock();
        }
        ERC20 rewardToken = pool.maToken.rewardToken();
        if (address(rewardToken) != address(0)) {
            rewardTokenSymbol = rewardToken.symbol();
        }
        ERC20 mara = lendingPool.lendingPoolInfo().mara();
        if (address(mara) != address(0)) {
            maraSymbol = mara.symbol();
        }
    }
}