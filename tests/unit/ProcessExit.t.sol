// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase, console } from "../utils/TestBase.sol";

// TODO: Add ManualSharesDecreased event to tests
contract ProcessExitTests is TestBase {

    event RequestRemoved(uint128 indexed requestId);

    uint256 assetsDeposited = 100e18;
    uint256 sharesToRedeem  = 250e18;

    function setUp() public override {
        super.setUp();

        asset.mint(address(pool), assetsDeposited);
        pool.mint(wm, sharesToRedeem);

        poolManager.__setTotalAssets(assetsDeposited);
    }

    function test_processExit_notPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        withdrawalManager.processExit(sharesToRedeem, lp);
    }

    function test_processExit_noShares() external {
        withdrawalManager.__setManualWithdrawal(lp, true);

        vm.prank(pm);
        vm.expectRevert("WM:PE:NO_SHARES");
        withdrawalManager.processExit(0, lp);
    }

    function test_processExit_tooManyShares() external {
        withdrawalManager.__setManualWithdrawal(lp, true);

        vm.prank(pm);
        vm.expectRevert("WM:PE:TOO_MANY_SHARES");
        withdrawalManager.processExit(sharesToRedeem, lp);
    }

    function test_processExit_tooManyShares_notProcessed() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1);

        vm.prank(pm);
        vm.expectRevert("WM:PE:TOO_MANY_SHARES");
        withdrawalManager.processExit(sharesToRedeem, lp);
    }

    function test_processExit_notEnoughLiquidity() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);
        withdrawalManager.__setTotalShares(sharesToRedeem);
        withdrawalManager.__setManualSharesAvailable(lp, sharesToRedeem);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1);

        asset.burn(address(pool), assetsDeposited);

        vm.prank(pm);
        vm.expectRevert("WM:PE:NOT_ENOUGH_LIQUIDITY");
        withdrawalManager.processExit(sharesToRedeem, lp);
    }

    function test_processExit_transferFail() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);
        withdrawalManager.__setTotalShares(sharesToRedeem);
        withdrawalManager.__setManualSharesAvailable(lp, sharesToRedeem);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1);

        pool.burn(wm, 1);

        vm.prank(pm);
        vm.expectRevert("WM:PE:TRANSFER_FAIL");
        withdrawalManager.processExit(sharesToRedeem, lp);
    }

    function test_processExit_manual_complete() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem);
        withdrawalManager.__setTotalShares(sharesToRedeem);
        withdrawalManager.__setLastRequest(lp, 0);
        withdrawalManager.__setManualSharesAvailable(lp, sharesToRedeem);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), sharesToRedeem);

        vm.prank(pm);
        withdrawalManager.processExit(sharesToRedeem, lp);

        assertEq(pool.balanceOf(lp), sharesToRedeem);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.totalShares(),             0);
        assertEq(withdrawalManager.lastRequestIds(lp),        0);
        assertEq(withdrawalManager.manualSharesAvailable(lp), 0);

        assertRequest({ requestId: 1, owner: lp, shares: sharesToRedeem });
    }

    function test_processExit_manual_partial() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesToRedeem / 2);
        withdrawalManager.__setTotalShares(sharesToRedeem);
        withdrawalManager.__setManualSharesAvailable(lp, sharesToRedeem / 2);
        
        // Only half of the liquidity is available.
        asset.burn(address(pool), assetsDeposited / 2);

        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), sharesToRedeem);

        vm.prank(pm);
        withdrawalManager.processExit(sharesToRedeem / 2, lp);

        assertEq(pool.balanceOf(lp), sharesToRedeem / 2);
        assertEq(pool.balanceOf(wm), sharesToRedeem / 2);

        assertEq(withdrawalManager.totalShares(), sharesToRedeem / 2);

        assertEq(withdrawalManager.lastRequestIds(lp), 1);

        assertRequest({ requestId: 1, owner: lp, shares: sharesToRedeem / 2 });
    }

    function test_processExit_automatic() external {
        vm.prank(pm);
        ( uint256 redeemableShares_, uint256 resultingAssets_ ) = withdrawalManager.processExit(sharesToRedeem, wm);

        assertEq(redeemableShares_, sharesToRedeem);
        assertEq(resultingAssets_,  assetsDeposited);
    }

}
