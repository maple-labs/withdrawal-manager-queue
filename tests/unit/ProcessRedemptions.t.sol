// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

// TODO: Add ManualSharesIncreased event to tests
// TODO: Add test case for reentrancy check
contract ProcessRedemptionsTests is TestBase {

    event RequestDecreased(uint128 indexed requestId, uint256 shares);
    event RequestProcessed(uint128 indexed requestId, address indexed owner, uint256 shares, uint256 assets);
    event RequestRemoved(uint128 indexed requestId);

    uint256 assetsDeposited = 100e18;
    uint256 sharesLocked    = 250e18;

    function setUp() public override {
        super.setUp();

        asset.mint(address(pool), assetsDeposited);
        pool.mint(wm, sharesLocked);

        poolManager.__setTotalAssets(assetsDeposited);
        withdrawalManager.__setTotalShares(sharesLocked);
    }

    function test_processRedemptions_protocolPaused() external {
        globals.__setFunctionPaused(true);

        vm.expectRevert("WM:PAUSED");
        withdrawalManager.processRedemptions(sharesLocked);
    }

    function test_processRedemptions_notRedeemer() external {
        globals.__setIsInstanceOf(false);

        vm.expectRevert("WM:NOT_REDEEMER");
        withdrawalManager.processRedemptions(sharesLocked);
    }

    function test_processRedemptions_zeroShares() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:ZERO_SHARES");
        withdrawalManager.processRedemptions(0);
    }

    function test_processRedemptions_lowLiquidity() external {
        asset.burn(address(pool), 1);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        withdrawalManager.processRedemptions(sharesLocked);
    }

    function test_processRedemptions_poolDelegate() external {
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_governor() external {
        vm.prank(governor);
        withdrawalManager.processRedemptions(sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_operationalAdmin() external {
        vm.prank(operationalAdmin);
        withdrawalManager.processRedemptions(sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_bot() external {
        globals.__setIsInstanceOf(true);

        vm.prank(redeemer);
        withdrawalManager.processRedemptions(sharesLocked);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processRedemptions_manual_complete() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        ( uint256 requestCount_, uint256 escrowedSharesTotal_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCount_,        1);
        assertEq(escrowedSharesTotal_, sharesLocked);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(),             sharesLocked);
        assertEq(withdrawalManager.manualSharesAvailable(lp), sharesLocked);
        assertEq(requestIdsLp_.length,                        0);
        assertEq(sharesLp_.length,                            0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        ( requestCount_, escrowedSharesTotal_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCount_,        0);
        assertEq(escrowedSharesTotal_, 0);
    }

   function test_processRedemptions_manual_multiple_requests() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked / 2);
        withdrawalManager.__setRequest(2, lp, sharesLocked / 2);
        withdrawalManager.__setQueue(1, 2);
        withdrawalManager.__setUserRequestCount(lp, 2, sharesLocked);

        ( uint256 requestCount_, uint256 escrowedSharesTotal_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCount_,        2);
        assertEq(escrowedSharesTotal_, sharesLocked);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(),             sharesLocked);
        assertEq(withdrawalManager.manualSharesAvailable(lp), sharesLocked);
        assertEq(requestIdsLp_.length,                        0);
        assertEq(sharesLp_.length,                            0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 3, lastRequestId: 2 });

        ( requestCount_, escrowedSharesTotal_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCount_,        0);
        assertEq(escrowedSharesTotal_, 0);
    }

   function test_processRedemptions_manual_multipleLps_multiple_requests() external {

        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3"); 

        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setManualWithdrawal(lp2, true);
        withdrawalManager.__setManualWithdrawal(lp3, true);
        withdrawalManager.__setRequest(1, lp,  sharesLocked / 4);
        withdrawalManager.__setRequest(2, lp2, sharesLocked / 4);
        withdrawalManager.__setRequest(3, lp3, sharesLocked / 4);
        withdrawalManager.__setRequest(4, lp,  sharesLocked / 4);
        withdrawalManager.__setQueue(1, 4);
        withdrawalManager.__setUserRequestCount(lp,  2, sharesLocked / 2);
        withdrawalManager.__setUserRequestCount(lp2, 1, sharesLocked / 4);
        withdrawalManager.__setUserRequestCount(lp3, 1, sharesLocked / 4);

        ( uint256 requestCountLp_,  uint256 escrowedSharesTotalLp_ )  = withdrawalManager.userRequestSummaries(lp);
        ( uint256 requestCountLp2_, uint256 escrowedSharesTotalLp2_ ) = withdrawalManager.userRequestSummaries(lp2);
        ( uint256 requestCountLp3_, uint256 escrowedSharesTotalLp3_ ) = withdrawalManager.userRequestSummaries(lp3);

        assertEq(requestCountLp_,        2);
        assertEq(escrowedSharesTotalLp_, sharesLocked / 2);

        assertEq(requestCountLp2_,        1);
        assertEq(escrowedSharesTotalLp2_, sharesLocked / 4);

        assertEq(requestCountLp3_,        1);
        assertEq(escrowedSharesTotalLp3_, sharesLocked / 4);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(),             sharesLocked);
        assertEq(withdrawalManager.manualSharesAvailable(lp), sharesLocked / 2);
        assertEq(withdrawalManager.manualSharesAvailable(lp2), sharesLocked / 4);
        assertEq(withdrawalManager.manualSharesAvailable(lp3), sharesLocked / 4);
        assertEq(requestIdsLp_.length,                        0);
        assertEq(sharesLp_.length,                            0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ requestId: 4, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 5, lastRequestId: 4 });

        ( requestCountLp_,  escrowedSharesTotalLp_ )  = withdrawalManager.userRequestSummaries(lp);
        ( requestCountLp2_, escrowedSharesTotalLp2_ ) = withdrawalManager.userRequestSummaries(lp2);
        ( requestCountLp3_, escrowedSharesTotalLp3_ ) = withdrawalManager.userRequestSummaries(lp3);

        assertEq(requestCountLp_,        0);
        assertEq(escrowedSharesTotalLp_, 0);

        assertEq(requestCountLp2_,        0);
        assertEq(escrowedSharesTotalLp2_, 0);

        assertEq(requestCountLp3_,        0);
        assertEq(escrowedSharesTotalLp3_, 0);
    }

    function test_processRedemptions_manual_partial() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked);

        // Only half of the liquidity is available.
        asset.burn(address(pool), assetsDeposited / 2);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked / 2);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);
        ( uint128 lastRequestId_, ) = getLastRequestByOwner(lp);

        assertEq(withdrawalManager.totalShares(),             sharesLocked);
        assertEq(lastRequestId_,                              1);
        assertEq(withdrawalManager.manualSharesAvailable(lp), sharesLocked / 2);
        assertEq(requestIdsLp_.length,                        1);
        assertEq(sharesLp_.length,                            1);
        assertEq(requestIdsLp_[0],                            1);
        assertEq(sharesLp_[0],                                sharesLocked / 2);

        assertRequest({ requestId: 1, owner: lp, shares: sharesLocked / 2 });

        assertQueue({ nextRequestId: 1, lastRequestId: 1 });

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked / 2);
    }

    function test_processRedemptions_manual_overkill() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked);

        // Add extra liquidity.
        asset.mint(address(pool), assetsDeposited);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(2 * sharesLocked);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(),             sharesLocked);
        assertEq(withdrawalManager.manualSharesAvailable(lp), sharesLocked);
        assertEq(requestIdsLp_.length,                        0);
        assertEq(sharesLp_.length,                            0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        0);
        assertEq(escrowedSharesTotalLp_, 0);
    }

    function test_processRedemptions_automatic_complete() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked);

        vm.expectEmit();
        emit RequestProcessed(1, lp, sharesLocked, assetsDeposited);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(), 0);
        assertEq(requestIdsLp_.length,            0);
        assertEq(sharesLp_.length,                0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        0);
        assertEq(escrowedSharesTotalLp_, 0);
    }

    function test_processRedemptions_automatic_partial() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked);

        // Only half of the liquidity is available.
        asset.burn(address(pool), assetsDeposited / 2);

        vm.expectEmit();
        emit RequestProcessed(1, lp, sharesLocked / 2, assetsDeposited / 2);

        vm.expectEmit();
        emit RequestDecreased(1, sharesLocked / 2);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked / 2);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);
        ( uint128 lastRequestId_, ) = getLastRequestByOwner(lp);

        assertEq(withdrawalManager.totalShares(), sharesLocked / 2);
        assertEq(lastRequestId_,                  1);
        assertEq(requestIdsLp_.length,            1);
        assertEq(sharesLp_.length,                1);
        assertEq(requestIdsLp_[0],                1);
        assertEq(sharesLp_[0],                    sharesLocked / 2);

        assertRequest({ requestId: 1, owner: lp, shares: sharesLocked / 2 });

        assertQueue({ nextRequestId: 1, lastRequestId: 1 });

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked / 2);
    }

    function test_processRedemptions_automatic_overkill() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1, 1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, sharesLocked);

        // Add extra liquidity.
        asset.mint(address(pool), assetsDeposited);

        vm.expectEmit();
        emit RequestProcessed(1, lp, sharesLocked, assetsDeposited);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(2 * sharesLocked);

        (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(),  0);
        assertEq(requestIdsLp_.length,             0);
        assertEq(sharesLp_.length,                 0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        0);
        assertEq(escrowedSharesTotalLp_, 0);
    }

    function test_processRedemptions_multiple() external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        withdrawalManager.__setRequest(1, lp1, 100e18);
        withdrawalManager.__setRequest(2, lp2, 150e18);
        withdrawalManager.__setQueue(1, 2);
        withdrawalManager.__setUserRequestCount(lp1, 1, 100e18);
        withdrawalManager.__setUserRequestCount(lp2, 1, 150e18);

        ( uint256 requestCountLp1_, uint256 escrowedSharesTotalLp1_ ) = withdrawalManager.userRequestSummaries(lp1);
        ( uint256 requestCountLp2_, uint256 escrowedSharesTotalLp2_ ) = withdrawalManager.userRequestSummaries(lp2);

        assertEq(requestCountLp1_,        1);
        assertEq(escrowedSharesTotalLp1_, 100e18);

        assertEq(requestCountLp2_,        1);
        assertEq(escrowedSharesTotalLp2_, 150e18);

        vm.expectEmit();
        emit RequestProcessed(1, lp1, 100e18, 40e18);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.expectEmit();
        emit RequestProcessed(2, lp2, 150e18, 60e18);

        vm.expectEmit();
        emit RequestRemoved(2);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesLocked);

        (uint128[] memory requestIdsLp1_, uint256[] memory sharesLp1_) = withdrawalManager.requestsByOwner(lp);
        (uint128[] memory requestIdsLp2_, uint256[] memory sharesLp2_) = withdrawalManager.requestsByOwner(lp2);

        assertEq(withdrawalManager.totalShares(), 0);
        assertEq(requestIdsLp1_.length,           0);
        assertEq(sharesLp1_.length,               0);
        assertEq(requestIdsLp2_.length,           0);
        assertEq(sharesLp2_.length,               0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 3, lastRequestId: 2 });

        ( requestCountLp1_, escrowedSharesTotalLp1_ ) = withdrawalManager.userRequestSummaries(lp1);
        ( requestCountLp2_, escrowedSharesTotalLp2_ ) = withdrawalManager.userRequestSummaries(lp2);

        assertEq(requestCountLp1_,        0);
        assertEq(escrowedSharesTotalLp1_, 0);

        assertEq(requestCountLp2_,        0);
        assertEq(escrowedSharesTotalLp2_, 0);
    }

}

contract ComplexRedemptionTests is TestBase {

    event RequestDecreased(uint128 indexed requestId, uint256 shares);
    event RequestProcessed(uint128 indexed requestId, address indexed owner, uint256 shares, uint256 assets);
    event RequestRemoved(uint128 indexed requestId);

    function test_processRedemptions_complex() external {
        uint256 totalAssets_     = 100e18;
        uint256 totalShares_     = 250e18;
        uint256 sharesToProcess_ = 200e18;

        asset.mint(address(pool), totalShares_);
        pool.mint(wm, totalShares_);

        poolManager.__setTotalAssets(totalAssets_);

        withdrawalManager.__setRequest(1, address(0), 0);       // Already processed
        withdrawalManager.__setRequest(2, address(2), 100e18);  // Fully processed
        withdrawalManager.__setRequest(3, address(3), 50e18);   // Manual
        withdrawalManager.__setRequest(4, address(0), 0);       // Cancelled
        withdrawalManager.__setRequest(5, address(5), 75e18);   // Partially processed
        withdrawalManager.__setRequest(6, address(6), 25e18);   // Out of shares

        withdrawalManager.__setManualWithdrawal(address(3), true);
        withdrawalManager.__setTotalShares(totalShares_);
        withdrawalManager.__setQueue(2, 6);

        withdrawalManager.__setUserRequestCount(address(2), 1, 100e18);
        withdrawalManager.__setUserRequestCount(address(3), 1, 50e18);
        withdrawalManager.__setUserRequestCount(address(5), 1, 75e18);
        withdrawalManager.__setUserRequestCount(address(6), 1, 25e18);

        vm.expectEmit();
        emit RequestProcessed(2, address(2), 100e18, 40e18);

        vm.expectEmit();
        emit RequestRemoved(2);

        vm.expectEmit();
        emit RequestProcessed(5, address(5), 50e18, 20e18);

        vm.expectEmit();
        emit RequestDecreased(5, 50e18);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesToProcess_);

        (uint128[] memory requestIds2_, uint256[] memory shares2_) = withdrawalManager.requestsByOwner(address(2));
        (uint128[] memory requestIds3_, uint256[] memory shares3_) = withdrawalManager.requestsByOwner(address(3));
        (uint128[] memory requestIds5_, uint256[] memory shares5_) = withdrawalManager.requestsByOwner(address(5));
        (uint128[] memory requestIds6_, uint256[] memory shares6_) = withdrawalManager.requestsByOwner(address(6));

        assertEq(requestIds2_.length, 0);
        assertEq(shares2_.length,     0);
        assertEq(requestIds3_.length, 0);
        assertEq(shares3_.length,     0);

        assertEq(requestIds5_.length, 1);
        assertEq(shares5_.length,     1);
        assertEq(requestIds5_[0],     5);
        assertEq(shares5_[0],         25e18);
        
        assertEq(requestIds6_.length, 1);
        assertEq(shares6_.length,     1);
        assertEq(requestIds6_[0],     6);
        assertEq(shares6_[0],         25e18);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ requestId: 4, owner: address(0), shares: 0 });
        assertRequest({ requestId: 5, owner: address(5), shares: 25e18 });
        assertRequest({ requestId: 6, owner: address(6), shares: 25e18 });

        assertEq(withdrawalManager.manualSharesAvailable(address(3)), 50e18);

        // Shares from the manual request are not redeemed.
        assertEq(withdrawalManager.totalShares(), totalShares_ - sharesToProcess_ + 50e18);

        // Request `5` is partially processed and becomes the next request.
        assertQueue({ nextRequestId: 5, lastRequestId: 6 });
    }

}
