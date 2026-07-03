// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract ProcessRedemptionsTests is TestBase {

    uint256 assetsDeposited = 100e18;
    uint256 sharesLocked    = 250e18;

    function setUp() public override {
        super.setUp();

        asset.mint(address(pool), assetsDeposited);
        pool.mint(wm, sharesLocked);

        poolManager.__setTotalAssets(assetsDeposited);
        withdrawalManager.__setTotalShares(sharesLocked);

        globals.__setIsInstanceOf(false);
    }

    function test_processRedemptions_functionPaused() external {
        globals.__setFunctionPaused(true);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.expectRevert("WM:PAUSED");
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_processRedemptions_reentrancy() external {
        withdrawalManager.__setLocked(2);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.expectRevert("WM:LOCKED");
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_processRedemptions_notRedeemer() external {
        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.expectRevert("WM:NOT_REDEEMER");
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_processRedemptions_zeroRequests() external {
        uint256[] memory requestIds_ = new uint256[](0);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:ZERO_REQUESTS");
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_processRedemptions_lowLiquidity() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        asset.burn(address(pool), 1);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_processRedemptions_manual_complete() external {
        withdrawalManager.__setManualWithdrawal(lp, true);
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        uint256[] memory pendingRequestIds_ = new uint256[](1);
        pendingRequestIds_[0] = 1;

        assertPendingRequestIds(pendingRequestIds_);

        assertEq(withdrawalManager.userEscrowedShares(lp), sharesLocked);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        (uint256[] memory requestIdsLp_, uint256[] memory sharesLp_) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(),             sharesLocked);
        assertEq(withdrawalManager.manualSharesAvailable(lp), sharesLocked);
        assertEq(requestIdsLp_.length,                        0);
        assertEq(sharesLp_.length,                            0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
        assertPendingRequestIds(new uint256[](0));
    }

    function test_processRedemptions_automatic_complete() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        uint256[] memory pendingRequestIds_ = new uint256[](1);
        pendingRequestIds_[0] = 1;

        assertPendingRequestIds(pendingRequestIds_);

        assertEq(withdrawalManager.userEscrowedShares(lp), sharesLocked);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.expectEmit();
        emit RequestProcessed(1, lp, sharesLocked, assetsDeposited);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        ( uint256[] memory requestIdsLp_, uint256[] memory sharesLp_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(), 0);
        assertEq(requestIdsLp_.length,            0);
        assertEq(sharesLp_.length,                0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);

        assertPendingRequestIds(new uint256[](0));
    }

    function test_processRedemptions_automatic_complete_redeemer() external {
        globals.__setIsInstanceOf(true);

        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        uint256[] memory pendingRequestIds_ = new uint256[](1);
        pendingRequestIds_[0] = 1;

        assertPendingRequestIds(pendingRequestIds_);

        assertEq(withdrawalManager.userEscrowedShares(lp), sharesLocked);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.expectEmit();
        emit RequestProcessed(1, lp, sharesLocked, assetsDeposited);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(redeemer);
        withdrawalManager.processRedemptions(requestIds_);

        ( uint256[] memory requestIdsLp_, uint256[] memory sharesLp_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(), 0);
        assertEq(requestIdsLp_.length,            0);
        assertEq(sharesLp_.length,                0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);

        assertPendingRequestIds(new uint256[](0));
    }

    function test_processRedemptions_automatic_complete_operationalAdmin() external {
        withdrawalManager.__setRequest(1, lp, sharesLocked);
        withdrawalManager.__setQueue(1);
        withdrawalManager.__setUserRequestCount(lp, 1, sharesLocked);

        uint256[] memory pendingRequestIds_ = new uint256[](1);
        pendingRequestIds_[0] = 1;

        assertPendingRequestIds(pendingRequestIds_);

        assertEq(withdrawalManager.userEscrowedShares(lp), sharesLocked);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 1;

        vm.expectEmit();
        emit RequestProcessed(1, lp, sharesLocked, assetsDeposited);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(operationalAdmin);
        withdrawalManager.processRedemptions(requestIds_);

        ( uint256[] memory requestIdsLp_, uint256[] memory sharesLp_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(withdrawalManager.totalShares(), 0);
        assertEq(requestIdsLp_.length,            0);
        assertEq(sharesLp_.length,                0);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);

        assertPendingRequestIds(new uint256[](0));
    }

    function test_processRedemptions_duplicate_ids_revert_low_liquidity() external {
        address lp2 = makeAddr("lp2");

        withdrawalManager.__setRequest(1, lp,         sharesLocked / 2);
        withdrawalManager.__setRequest(2, lp2,        sharesLocked / 2);
        withdrawalManager.__setRequest(3, address(0), 0);

        withdrawalManager.__setQueue(3);

        withdrawalManager.__setUserRequestCount(lp,  1, sharesLocked / 2);
        withdrawalManager.__setUserRequestCount(lp2, 1, sharesLocked / 2);

        withdrawalManager.__setTotalShares(sharesLocked);

        asset.mint(address(pool), 150e18);
        poolManager.__setTotalAssets(sharesLocked);

        uint256[] memory requestIds_ = new uint256[](5);
        requestIds_[0] = 2;
        requestIds_[1] = 2;
        requestIds_[2] = 1;
        requestIds_[3] = 1;
        requestIds_[4] = 2;

        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);
    }

    function test_processRedemptions_duplicate_ids_sufficient_liquidity_process_once() external {
        address lp2 = makeAddr("lp2");

        withdrawalManager.__setRequest(1, lp,         sharesLocked / 2);
        withdrawalManager.__setRequest(2, lp2,        sharesLocked / 2);
        withdrawalManager.__setRequest(3, address(0), 0);

        withdrawalManager.__setQueue(3);

        withdrawalManager.__setUserRequestCount(lp,  1, sharesLocked / 2);
        withdrawalManager.__setUserRequestCount(lp2, 1, sharesLocked / 2);

        withdrawalManager.__setTotalShares(sharesLocked);

        asset.mint(address(pool), 5 * sharesLocked / 2);
        poolManager.__setTotalAssets(sharesLocked);

        uint256[] memory pendingRequestIds_ = new uint256[](2);
        pendingRequestIds_[0] = 1;
        pendingRequestIds_[1] = 2;

        assertPendingRequestIds(pendingRequestIds_);

        uint256[] memory requestIds_ = new uint256[](5);
        requestIds_[0] = 2;
        requestIds_[1] = 2;
        requestIds_[2] = 1;
        requestIds_[3] = 1;
        requestIds_[4] = 2;

        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", sharesLocked / 2, lp2, address(withdrawalManager)),
            1
        );
        vm.expectCall(
            address(pool),
            abi.encodeWithSignature("redeem(uint256,address,address)", sharesLocked / 2, lp, address(withdrawalManager)),
            1
        );

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ requestId: 3, owner: address(0), shares: 0 });

        assertQueue({ nextRequestId: 4, lastRequestId: 3 });

        assertEq(withdrawalManager.totalShares(),           0);
        assertEq(withdrawalManager.userEscrowedShares(lp),  0);
        assertEq(withdrawalManager.userEscrowedShares(lp2), 0);

        assertPendingRequestIds(new uint256[](0));
    }

    function test_processRedemptions_preserves_next_request_id() external {
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        withdrawalManager.__setRequest(1, lp,  100e18);
        withdrawalManager.__setRequest(2, lp2, 50e18);
        withdrawalManager.__setRequest(3, lp3, 100e18);
        withdrawalManager.__setQueue(3);
        withdrawalManager.__setUserRequestCount(lp,  1, 100e18);
        withdrawalManager.__setUserRequestCount(lp2, 1, 50e18);
        withdrawalManager.__setUserRequestCount(lp3, 1, 100e18);
        withdrawalManager.__setTotalShares(250e18);

        uint256[] memory pendingRequestIds_ = new uint256[](3);
        pendingRequestIds_[0] = 1;
        pendingRequestIds_[1] = 2;
        pendingRequestIds_[2] = 3;

        assertPendingRequestIds(pendingRequestIds_);

        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 2;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertRequest({ requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ nextRequestId: 1, lastRequestId: 3 });

        pendingRequestIds_ = new uint256[](2);
        pendingRequestIds_[0] = 1;
        pendingRequestIds_[1] = 3;

        assertPendingRequestIds(pendingRequestIds_);
    }

    function test_processRedemptions_skips_fully_processed_ids() external {
        uint256[] memory requestIds_ = new uint256[](1);
        requestIds_[0] = 42;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds_);

        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

}
