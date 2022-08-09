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
    
    event SetLendingPool(address lendingPool);

    event SetLendingPoolInfo(address lendingPoolInfo);

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
    // address maTokenAddress,
    // address poolConfigAddress,
    //        ERC20 mara,
        string memory maraSymbol,
    //        ERC20 rewardToken,
        string memory rewardTokenSymbol,
        uint256 totalBorrows,
        uint256 totalBorrowShares,
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
        // maTokenAddress = address(pool.maToken);
        // poolConfigAddress = address(pool.poolConfig);
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

    function getLiquidationInfo(address[] memory users) public view returns (LiquidationInfo[] memory liquidationInfos){
        liquidationInfos = new LiquidationInfo[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            liquidationInfos[i].user = users[i];
            liquidationInfos[i].isAccountHealthy = lendingPool.isAccountHealthy(users[i]);
            (uint256 totalLiquidityBalanceBase, uint256 totalCollateralBalanceBase, uint256 totalBorrowBalanceBase) = lendingPool.getUserAccount(users[i]);
            liquidationInfos[i].totalLiquidityBalanceBase = totalLiquidityBalanceBase;
            liquidationInfos[i].totalCollateralBalanceBase = totalCollateralBalanceBase;
            liquidationInfos[i].totalBorrowBalanceBase = totalBorrowBalanceBase;

            uint256 poolLength = lendingPool.poolLength();
            liquidationInfos[i].userTokenList = new UserTokenList[](poolLength);
            for (uint256 j = 0; j < poolLength; j++) {
                LendingPool.Pool memory pool = getPool(lendingPool.tokenList(j));
                uint256 maBalance = pool.maToken.balanceOf(users[i]);
                liquidationInfos[i].userTokenList[j].token = lendingPool.tokenList(j);
                liquidationInfos[i].userTokenList[j].symbol = liquidationInfos[i].userTokenList[j].token.symbol();
                liquidationInfos[i].userTokenList[j].myBalance = liquidationInfos[i].userTokenList[j].token.balanceOf(msg.sender);
                (,uint256 borrowShares,,) = lendingPool.userPoolData(users[i], address(lendingPool.tokenList(j)));
                liquidationInfos[i].userTokenList[j].totalBorrows = pool.totalBorrows;
                liquidationInfos[i].userTokenList[j].totalBorrowShares = pool.totalBorrowShares;
                liquidationInfos[i].userTokenList[j].borrowShares = borrowShares;
                liquidationInfos[i].userTokenList[j].maxPurchaseShares = borrowShares.wadMul(lendingPool.CLOSE_FACTOR());
                // 50%
                liquidationInfos[i].userTokenList[j].maxPurchase = calculateRoundUpBorrowAmount(pool, liquidationInfos[i].userTokenList[j].maxPurchaseShares);
                if (maBalance > 0) {
                    liquidationInfos[i].userTokenList[j].status = 1;
                    liquidationInfos[i].userTokenList[j].depositBal = maBalance;
                }
                (,uint256 compoundedBorrowBalance,) = lendingPool.getUserPoolData(address(users[i]), ERC20(lendingPool.tokenList(j)));
                if (compoundedBorrowBalance > 0) {
                    liquidationInfos[i].userTokenList[j].status = liquidationInfos[i].userTokenList[j].status + 2;
                    liquidationInfos[i].userTokenList[j].borrowBal = compoundedBorrowBalance;
                }
            }
        }
    }

    function calculateRoundUpBorrowAmount(LendingPool.Pool memory pool, uint256 _shareAmount) public pure returns (uint256) {
        if (pool.totalBorrows == 0 || pool.totalBorrowShares == 0) {
            return _shareAmount;
        }
        return _shareAmount.mul(pool.totalBorrows).divCeil(pool.totalBorrowShares);
    }

    function getSortAccountHealthy(address[] memory users) public view returns (AccountHealthy[] memory accountHealthy, uint256 liquidationPercent){
        liquidationPercent = lendingPool.liquidationPercent();
        uint256[] memory debtRatio = new uint256[](users.length);
        uint256[] memory arrayIds = new uint256[](users.length);
        AccountHealthy[] memory acctHealthy = new AccountHealthy[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            acctHealthy[i].isAccountHealthy = lendingPool.isAccountHealthy(users[i]);
            acctHealthy[i].user = users[i];
            acctHealthy[i].index = i;
            (acctHealthy[i].totalLiquidityBalanceBase, acctHealthy[i].totalCollateralBalanceBase, acctHealthy[i].totalBorrowBalanceBase) = lendingPool.getUserAccount(users[i]);
            if (acctHealthy[i].totalCollateralBalanceBase > 0) {
                debtRatio[i] = acctHealthy[i].totalBorrowBalanceBase.mul(10000).div(acctHealthy[i].totalCollateralBalanceBase.wadMul(liquidationPercent));
            } else {
                debtRatio[i] = 0;
            }
            acctHealthy[i].debtRatio = debtRatio[i];
            arrayIds[i] = i;
        }
        quickSort(debtRatio, arrayIds, 0, arrayIds.length - 1);
        accountHealthy = new AccountHealthy[](arrayIds.length);
        for (uint256 i = 0; i < arrayIds.length; i++) {
            accountHealthy[arrayIds.length - 1 - i] = acctHealthy[arrayIds[i]];
        }
    }

    // Fast scheduling algorithm .
    function quickSort(uint256[] memory arr, uint256[] memory ids, uint256 left, uint256 right) public view {
        uint256 i = left;
        uint256 j = right;
        if (i == j) return;
        uint256 pivot = arr[left + (right - left) / 2];
        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (pivot < arr[j]) j--;
            if (i <= j) {
                (arr[i], arr[j]) = (arr[j], arr[i]);
                (ids[i], ids[j]) = (ids[j], ids[i]);
                i++;
                if (j > 0) {
                    j--;
                }

            }
        }
        if (left < j)
            quickSort(arr, ids, left, j);
        if (i < right)
            quickSort(arr, ids, i, right);
    }

    function getUserBorrowInfo(ERC20 _token) public view returns (
        bool isAccountHealthy,
        uint256 maxCanBorrow,
        uint256 collateralPercent,
        uint256 liquidationPercent,
        uint256 totalLiquidityBalanceBase,
        uint256 totalCollateralBalanceBase,
        uint256 totalBorrowBalanceBase,
        uint256 compoundedBorrowBalance,
        uint256 totalAvailableLiquidity,
        uint256 maxBorrowInUSD
    ){
        LendingPool.Pool memory pool = getPool(_token);
        isAccountHealthy = lendingPool.isAccountHealthy(msg.sender);
        (totalLiquidityBalanceBase, totalCollateralBalanceBase, totalBorrowBalanceBase) = lendingPool.getUserAccount(msg.sender);
        liquidationPercent = lendingPool.liquidationPercent();
        collateralPercent = pool.poolConfig.getCollateralPercent();
        if(isAccountHealthy == true){
            maxCanBorrow = totalCollateralBalanceBase.wadMul(liquidationPercent).sub(totalBorrowBalanceBase).mul(UNIT).div(priceOracle.getAssetPrice(address(_token)));
        }
        (, compoundedBorrowBalance,) = lendingPool.getUserPoolData(address(msg.sender), ERC20(_token));
        totalAvailableLiquidity = lendingPool.getTotalAvailableLiquidity(_token);
        maxBorrowInUSD = pool.poolConfig.getMaxBorrowInUSD();
    }

    function getUserWithdrawInfo(ERC20 _token) public view returns (
        uint256 maxWithdraw,
        uint256 maxShareWithdraw,
        uint256 compoundedLiquidityBalance
    ){
        (compoundedLiquidityBalance,,) = lendingPool.getUserPoolData(address(msg.sender), ERC20(_token));
        (, uint256 totalCollateralBalanceBase, uint256 totalBorrowBalanceBase) = lendingPool.getUserAccount(msg.sender);
        uint256 price = priceOracle.getAssetPrice(address(_token));
        uint256 percent = lendingPool.liquidationPercent();
        uint256 totalCollateral = totalCollateralBalanceBase.wadMul(percent);
        if(totalBorrowBalanceBase >= totalCollateral){
            maxWithdraw = 0;
            maxShareWithdraw = 0;
        }else{
            LendingPool.Pool memory pool = getPool(_token);
            uint256 collateralPercent = pool.poolConfig.getCollateralPercent();
            maxWithdraw = totalCollateral.sub(totalBorrowBalanceBase).wadDiv(percent).wadDiv(collateralPercent).wadDiv(price);
            maxWithdraw = maxWithdraw > compoundedLiquidityBalance ? compoundedLiquidityBalance : maxWithdraw;
            maxShareWithdraw = calculateRoundUpLiquidityShareAmount(_token,maxWithdraw);
        }
    }

    function calculateRoundUpLiquidityShareAmount(ERC20 _token, uint256 _amount) public view returns (
        uint256
    ){
        LendingPool.Pool memory pool = getPool(_token);
        uint256 poolTotalLiquidityShares = pool.maToken.totalSupply();
        uint256 poolTotalLiquidity = lendingPool.getTotalLiquidity(_token);
        // liquidity share amount of the first depositing is equal to amount
        if (poolTotalLiquidity == 0 || poolTotalLiquidityShares == 0) {
        return _amount;
        }
        return _amount.mul(poolTotalLiquidityShares).divCeil(poolTotalLiquidity);
    }
    
    function getPoolGain(ERC20 _token) public view returns (
        ERC20 rewardToken,
        uint256 lendersGainMaraPerBlock,
        uint256 lendersGainTokenPerBlock,
        uint256 borrowersGainMaraPerBlock,
        uint256 borrowersGainTokenPerBlock
    ) {
        LendingPool.Pool memory pool = getPool(_token);

        (uint256 borrow, uint256 totalBorrow) = _getBorrowValue(_token);
        if (totalBorrow != 0 && pool.status == LendingPool.PoolStatus.ACTIVE) {
            uint256 maraPerBlock = lendingPoolInfo.tokensPerBlock().mul(borrow).div(totalBorrow);
            uint256 tokenPerBlock = pool.maToken.tokensPerBlock();
            (lendersGainMaraPerBlock) = _splitReward(_token, maraPerBlock, pool.poolConfig, pool.totalBorrows);
            borrowersGainMaraPerBlock = maraPerBlock.sub(lendersGainMaraPerBlock);
            (lendersGainTokenPerBlock) = _splitReward(_token, tokenPerBlock, pool.poolConfig, pool.totalBorrows);
            borrowersGainTokenPerBlock = tokenPerBlock.sub(lendersGainTokenPerBlock);
        }
        rewardToken = pool.maToken.rewardToken();
    }
    function getUserInfo(ERC20 _token) public view returns (
            uint256 compoundedLiquidityBalance,
            uint256 compoundedBorrowBalance,
            bool userUsePoolAsCollateral,
            uint256 pendingMaraBorrow,
            uint256 pendingRewardBorrow,
            uint256 pendingMaraLend,
            uint256 pendingRewardLend
        ) {
            LendingPool.Pool memory pool = getPool(_token);

            (
            uint256 multiplierBorrow,
            uint256 multiplierTokenBorrow,
            uint256 multiplierLend,
            uint256 multiplierTokenLend
            ) = _updateMultiplier(_token);


            (compoundedLiquidityBalance, compoundedBorrowBalance, userUsePoolAsCollateral) = lendingPool.getUserPoolData(address(msg.sender), ERC20(_token));
            pendingMaraBorrow = _calculateRewardBorrow(
                _token,
                address(msg.sender),
                multiplierBorrow
            );

            pendingRewardBorrow = _calculateTokenRewardBorrow(
                _token,
                address(msg.sender),
                multiplierTokenBorrow
            );

            pendingMaraLend = _calculateRewardLend(
                pool.maToken,
                address(msg.sender),
                multiplierLend
            );

            pendingRewardLend = _calculateTokenRewardLend(
                pool.maToken,
                address(msg.sender),
                multiplierTokenLend
            );
        }

    function getUserDebtRatio(address[] calldata users) public view returns (uint256[] memory) {
        uint256[] memory ratios = new uint[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            (, uint256 totalCollateralBalance, uint256 totalBorrowBalance) = lendingPool.getUserAccount(users[i]);
            uint256 ratio = totalBorrowBalance.mul(10000).div(totalCollateralBalance);
            ratios[i] = ratio;
        }
        return ratios;
    }

    function _getBorrowValue(ERC20 _token) public view returns (uint256 borrow, uint256 totalBorrow) {
        borrow = 0;
        totalBorrow = 0;
        uint256 poolLength = lendingPool.poolLength();
        for (uint256 i = 0; i < poolLength; i++) {
            try lendingPool.tokenList(i) returns (ERC20 token) {
                (LendingPool.PoolStatus poolStatus,,,,,,,,) = lendingPool.getPool(token);
                if (poolStatus == LendingPool.PoolStatus.ACTIVE) {
                    uint256 poolBorrow = lendingPool.totalBorrowInUSD(token);
                    totalBorrow = totalBorrow.add(poolBorrow);
                    if (address(token) == address(_token)) {
                        borrow = poolBorrow;
                    }
                }
            } catch Error(string memory /*reason*/) {
                break;
            } catch (bytes memory /*lowLevelData*/) {
                break;
            }
        }
    }

}