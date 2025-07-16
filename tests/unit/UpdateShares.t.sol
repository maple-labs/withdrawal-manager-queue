// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract UpdateSharesFailureTests is TestBase {

    function setUp() public override {
        super.setUp();
        uint256 mintAmount = 200;

        // Simulate LP transfer into PM.
        pool.mint(pm, mintAmount);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), mintAmount);
    }

    function test_updateShares_invalidRequest() external {
        vm.expectRevert("WM:US:INVALID_REQUEST");
        withdrawalManager.updateShares(1, 1);
    }

    function test_updateShares_notOwner() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.prank(address(0x12));
        vm.expectRevert("WM:US:NOT_OWNER");
        withdrawalManager.updateShares(1, 1);
    }

    function test_updateShares_noChange() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.prank(lp);
        vm.expectRevert("WM:US:NO_CHANGE");
        withdrawalManager.updateShares(1, 1);
    }

    function test_updateShares_failed_increase_insufficient_shares() external{
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.expectRevert("WM:AS:FAILED_TRANSFER");
        vm.prank(lp);
        withdrawalManager.updateShares(1, 100);
    }

    function test_updateShares_failed_transfer_insufficient_tokens() external{
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.expectRevert("WM:AS:FAILED_TRANSFER");
        vm.prank(lp);
        withdrawalManager.updateShares(1, 100);
    }

    function test_updateShares_failed_update_request_already_removed() external{
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        uint128[] memory requestIds = new uint128[](1);
        requestIds[0] = 1;

        vm.prank(governor);
        withdrawalManager.removeRequest(lp, requestIds);

        vm.expectRevert("WM:US:INVALID_REQUEST");
        vm.prank(lp);
        withdrawalManager.updateShares(1, 100);
    }
}

contract UpdateSharesSuccessTests is TestBase {

    event RequestCreated(uint128 indexed requestId, address indexed owner, uint256 shares);

    event RequestDecreased(uint128 indexed requestId, uint256 shares);

    event RequestRemoved(uint128 indexed requestId);

    function setUp() public override {
        super.setUp();
        uint256 mintAmount = 200;

        pool.mint(pm, mintAmount);  // Simulate LP transfer into PM.
        pool.mint(lp, mintAmount);  // Give LP some shares to use to increase shares.

        vm.prank(pm);
        pool.approve(address(withdrawalManager), mintAmount);

        vm.prank(lp);
        pool.approve(address(withdrawalManager), mintAmount);
    }

    function test_updateShares_increase() external {
        vm.prank(pm);
        uint128 requestIdBefore_ = withdrawalManager.addShares(1, lp);

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdBefore_,         1, "Request ID should be 1");
        assertEq(requestIdsBefore_.length, 1, "Request IDs length should be 1");
        assertEq(sharesBefore_.length,     1, "Shares length should be 1");
        assertEq(requestIdsBefore_[0],     1, "Request ID should be 1");
        assertEq(sharesBefore_[0],         1, "Shares should be 1");

        vm.prank(lp);
        vm.expectEmit();
        emit RequestRemoved(requestIdBefore_);
        emit RequestCreated(requestIdBefore_ + 1, lp, 2);
        // Increase shares from 1 to 2 creates a new request and removes the old one.
        uint128 newRequestId_ = withdrawalManager.updateShares(requestIdBefore_, 2);

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(newRequestId_,      2, "Request ID should be 2");
        assertEq(requestIds_.length, 1, "Request IDs length should be 1");
        assertEq(shares_.length,     1, "Shares length should be 1");
        assertEq(requestIds_[0],     2, "Request ID should be 2");
        assertEq(shares_[0],         2, "Shares should be 2");
    }

    function test_updateShares_remove_request() external{
        vm.prank(pm);
        uint128 requestId_ = withdrawalManager.addShares(1, lp);

        vm.prank(lp);
        vm.expectEmit();
        emit RequestRemoved(requestId_);

        uint128 newRequestId_ = withdrawalManager.updateShares(requestId_, 0);

        assertEq(newRequestId_, 0, "Request ID should be 0");
    }

    function test_updateShares_decrease() external {
        vm.prank(pm);
        uint128 requestIdBefore_ = withdrawalManager.addShares(2, lp);

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdBefore_,         1, "Request ID Before should be 1 (addShares)");
        assertEq(requestIdsBefore_.length, 1, "Request IDs length before should be 1");
        assertEq(sharesBefore_.length,     1, "Shares length before should be 1");
        assertEq(requestIdsBefore_[0],     1, "Request ID before should be 1");
        assertEq(sharesBefore_[0],         2, "Shares before should be 2");

        vm.prank(lp);
        vm.expectEmit();
        emit RequestDecreased(requestIdBefore_, 1);
        // Decrease shares from 2 to 1 keeps the same request ID.
        uint128 newRequestId_ = withdrawalManager.updateShares(requestIdBefore_, 1);

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(newRequestId_,      1, "Request ID should be 1 (addShares)");
        assertEq(requestIds_.length, 1, "Request IDs length should be 1");
        assertEq(shares_.length,     1, "Shares length should be 1");
        assertEq(requestIds_[0],     1, "Request ID should be 1");
        assertEq(shares_[0],         1, "Shares should be 1");
    }

    function test_update_shares_multiple_lps_requestsByOwner() external {
        address lp2_ = makeAddr("lp2");
        address lp3_ = makeAddr("lp3");

        uint256 requestAmount1_ = 10;
        uint256 requestAmount2_ = 20;

        pool.mint(pm,  3000);
        pool.mint(lp,  1000);
        pool.mint(lp2_, 1000);
        pool.mint(lp3_, 1000);

        vm.prank(lp3_);
        pool.approve(address(withdrawalManager), 1000);

        vm.startPrank(pm);

        vm.expectEmit();
        emit RequestCreated(1, lp, requestAmount1_);
        withdrawalManager.addShares(requestAmount1_, lp);
        vm.expectEmit();
        emit RequestCreated(2, lp, requestAmount2_);
        withdrawalManager.addShares(requestAmount2_, lp);

        vm.expectEmit();
        emit RequestCreated(3, lp2_, requestAmount1_);
        withdrawalManager.addShares(requestAmount1_, lp2_);
        vm.expectEmit();
        emit RequestCreated(4, lp2_, requestAmount2_);
        withdrawalManager.addShares(requestAmount2_, lp2_);

        vm.expectEmit();
        emit RequestCreated(5, lp3_, requestAmount1_);
        withdrawalManager.addShares(requestAmount1_, lp3_);
        vm.expectEmit();
        emit RequestCreated(6, lp3_, requestAmount2_);
        withdrawalManager.addShares(requestAmount2_, lp3_);

        vm.stopPrank();

        {
            (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_)   = withdrawalManager.requestsByOwner(lp);
            (uint128[] memory requestIdsLp2_, uint256[] memory sharesLp2_) = withdrawalManager.requestsByOwner(lp2_);
            (uint128[] memory requestIdsLp3_, uint256[] memory sharesLp3_) = withdrawalManager.requestsByOwner(lp3_);

            assertEq(requestIdsLp_.length,  2, "LP request IDs length should be 2");
            assertEq(requestIdsLp2_.length, 2, "LP2 request IDs length should be 2");
            assertEq(requestIdsLp3_.length, 2, "LP3 request IDs length should be 2");

            assertEq(sharesLp_.length,  2, "LP shares length should be 2");
            assertEq(sharesLp2_.length, 2, "LP2 shares length should be 2");
            assertEq(sharesLp3_.length, 2, "LP3 shares length should be 2");

            assertEq(requestIdsLp_[0],  1, "LP request ID index 0 should be 1");
            assertEq(requestIdsLp_[1],  2, "LP request ID index 1 should be 2");
            assertEq(requestIdsLp2_[0], 3, "LP2 request ID index 0 should be 3");
            assertEq(requestIdsLp2_[1], 4, "LP2 request ID index 1 should be 4");
            assertEq(requestIdsLp3_[0], 5, "LP3 request ID index 0 should be 5");
            assertEq(requestIdsLp3_[1], 6, "LP3 request ID index 1 should be 6");

            assertEq(sharesLp_[0],  requestAmount1_, "LP shares index 0 is incorrect");
            assertEq(sharesLp_[1],  requestAmount2_, "LP shares index 1 is incorrect");
            assertEq(sharesLp2_[0], requestAmount1_, "LP2 shares index 0 is incorrect");
            assertEq(sharesLp2_[1], requestAmount2_, "LP2 shares index 1 is incorrect");
            assertEq(sharesLp3_[0], requestAmount1_, "LP3 shares index 0 is incorrect");
            assertEq(sharesLp3_[1], requestAmount2_, "LP3 shares index 1 is incorrect");
        }
        {
            // Decrease a request
            vm.prank(lp);
            uint128 requestIdLp_ = 1;
            vm.expectEmit();
            emit RequestDecreased(requestIdLp_, 1);
            uint128 updatedRequestIdLp_ = withdrawalManager.updateShares(requestIdLp_, requestAmount1_ - 1);
            assertEq(updatedRequestIdLp_, requestIdLp_, "Updated request ID should be 1");

            // Remove a request
            vm.prank(lp2_);
            uint128 requestIdLp2_ = 3;
            vm.expectEmit();
            emit RequestRemoved(requestIdLp2_);
            uint128 updatedRequestIdLp2_ = withdrawalManager.updateShares(requestIdLp2_, 0);
            assertEq(updatedRequestIdLp2_, 0, "Updated request ID should be 0");

            // Increase a request
            vm.prank(lp3_);
            uint128 requestIdLp3_ = 5;
            vm.expectEmit();
            emit RequestRemoved(requestIdLp3_);
            emit RequestCreated(7, lp3_, requestAmount2_ + 10);
            uint128 updatedRequestIdLp3 = withdrawalManager.updateShares(requestIdLp3_, requestAmount2_ + 10);
            assertEq(updatedRequestIdLp3, 7, "Updated request ID should be 7");

            vm.stopPrank();
        }

        {
            (uint128[] memory requestIdsLp_, uint256[] memory sharesLp_)   = withdrawalManager.requestsByOwner(lp);
            (uint128[] memory requestIdsLp2_, uint256[] memory sharesLp2_) = withdrawalManager.requestsByOwner(lp2_);
            (uint128[] memory requestIdsLp3_, uint256[] memory sharesLp3_) = withdrawalManager.requestsByOwner(lp3_);

            assertEq(requestIdsLp_.length,  2, "LP request IDs length should be 2");
            assertEq(requestIdsLp2_.length, 1, "LP2 request IDs length should be 1");
            assertEq(requestIdsLp3_.length, 2, "LP3 request IDs length should be 2");

            assertEq(sharesLp_.length,  2, "LP shares length should be 2");
            assertEq(sharesLp2_.length, 1, "LP2 shares length should be 2");
            assertEq(sharesLp3_.length, 2, "LP3 shares length should be 2");

            assertEq(requestIdsLp_[0],  1, "LP request ID index 0 should be 1");
            assertEq(requestIdsLp_[1],  2, "LP request ID index 1 should be 2");
            assertEq(requestIdsLp2_[0], 4, "LP2 request ID index 1 should be 4");
            assertEq(requestIdsLp3_[0], 6, "LP3 request ID index 0 should be 5");
            assertEq(requestIdsLp3_[1], 7, "LP3 request ID index 1 should be 7");

            assertEq(sharesLp_[0],  requestAmount1_ - 1, "LP shares index 0 is incorrect");
            assertEq(sharesLp_[1],  requestAmount2_, "LP shares index 1 is incorrect");
            assertEq(sharesLp2_[0], requestAmount2_, "LP2 shares index 0 is incorrect");
            assertEq(sharesLp3_[0], requestAmount2_, "LP3 shares index 0 is incorrect");
            assertEq(sharesLp3_[1], requestAmount2_ + 10, "LP3 shares index 1 is incorrect");
        }
    }

}

contract UpdateSharesBatchFailureTests is TestBase {

    function setUp() public override {
        super.setUp();
        uint256 mintAmount = 200;

        pool.mint(pm, mintAmount);  // Simulate LP transfer into PM.
        pool.mint(lp, mintAmount);  // Give LP some shares to use to increase shares.

        vm.prank(pm);
        pool.approve(address(withdrawalManager), mintAmount);

        vm.prank(lp);
        pool.approve(address(withdrawalManager), mintAmount);
    }

    function test_updateSharesBatch_invalid_array_lengths() external {
        uint128[] memory requestIdsToUpdate_ = new uint128[](1);
        uint256[] memory sharesToUpdate_     = new uint256[](2);

        vm.expectRevert("WM:USB:ARRAY_LENGTH_MISMATCH");
        withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);
    }

    function test_updateSharesBatch_invalid_request() external {
        uint128[] memory requestIdsToUpdate_ = new uint128[](1);
        uint256[] memory sharesToUpdate_     = new uint256[](1);

        vm.expectRevert("WM:US:INVALID_REQUEST");
        withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);
    }

    function test_updateSharesBatch_invalid_owner() external {
        uint128[] memory requestIdsToUpdate_ = new uint128[](1);
        uint256[] memory sharesToUpdate_     = new uint256[](1);

        vm.prank(pm);
        uint128 requestId_ = withdrawalManager.addShares(1, lp);

        requestIdsToUpdate_[0] = requestId_;
        sharesToUpdate_[0]     = 2;

        vm.prank(address(0x12));
        vm.expectRevert("WM:US:NOT_OWNER");
        withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);
    }

    function test_updateSharesBatch_no_change_in_shares() external {
        uint128[] memory requestIdsToUpdate_ = new uint128[](1);
        uint256[] memory sharesToUpdate_     = new uint256[](1);

        vm.prank(pm);
        uint128 requestId_ = withdrawalManager.addShares(1, lp);

        requestIdsToUpdate_[0] = requestId_;
        sharesToUpdate_[0]     = 1;

        vm.prank(lp);
        vm.expectRevert("WM:US:NO_CHANGE");
        withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);
    }
}

contract UpdateSharesBatchSuccessTests is TestBase {

    event RequestCreated(uint128 indexed requestId, address indexed owner, uint256 shares);

    event RequestDecreased(uint128 indexed requestId, uint256 shares);

    event RequestRemoved(uint128 indexed requestId);

    function setUp() public override {
        super.setUp();
        uint256 mintAmount = 200;

        pool.mint(pm, mintAmount);  // Simulate LP transfer into PM.
        pool.mint(lp, mintAmount);  // Give LP some shares to use to increase shares.

        vm.prank(pm);
        pool.approve(address(withdrawalManager), mintAmount);

        vm.prank(lp);
        pool.approve(address(withdrawalManager), mintAmount);
    }


    function test_updateSharesBatch_increase_single_request() external {
        vm.prank(pm);
        uint128 requestIdBefore_ = withdrawalManager.addShares(1, lp);

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdBefore_,         1, "Request ID should be 1");
        assertEq(requestIdsBefore_.length, 1, "Request IDs length should be 1");
        assertEq(sharesBefore_.length,     1, "Shares length should be 1");
        assertEq(requestIdsBefore_[0],     1, "Request ID should be 1");
        assertEq(sharesBefore_[0],         1, "Shares should be 1");

        uint128[] memory requestIdsToUpdate_ = new uint128[](1);
        requestIdsToUpdate_[0] = requestIdBefore_;

        uint256[] memory sharesToUpdate_ = new uint256[](1);
        sharesToUpdate_[0] = 2;

        vm.prank(lp);
        vm.expectEmit();
        emit RequestRemoved(requestIdBefore_);
        emit RequestCreated(requestIdBefore_ + 1, lp, 2);

        // Increase shares creates a new request and removes the old one.
        uint128[] memory newRequestIds_ = withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);

        assertEq(newRequestIds_.length, 1, "New request IDs length should be 1");
        assertEq(newRequestIds_[0],     2, "New request ID should be 2");

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 1, "Request IDs length should be 1");
        assertEq(shares_.length,     1, "Shares length should be 1");
        assertEq(requestIds_[0],     2, "Request ID should be 2");
        assertEq(shares_[0],         2, "Shares should be 2");
    }

    function test_updateSharesBatch_increase_multiple_requests() external {
        vm.startPrank(pm);
        uint128 requestId1Before_ = withdrawalManager.addShares(1, lp);
        uint128 requestId2Before_ = withdrawalManager.addShares(1, lp);
        vm.stopPrank();

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestId1Before_,        1, "Request ID should be 1");
        assertEq(requestId2Before_,        2, "Request ID should be 1");
        assertEq(requestIdsBefore_.length, 2, "Request IDs length should be 2");
        assertEq(sharesBefore_.length,     2, "Shares length should be 2");
        assertEq(requestIdsBefore_[0],     1, "Request ID should be 1");
        assertEq(sharesBefore_[0],         1, "Shares should be 1");
        assertEq(requestIdsBefore_[1],     2, "Request ID should be 2");
        assertEq(sharesBefore_[1],         1, "Shares should be 1");

        uint128[] memory requestIdsToUpdate_ = new uint128[](2);
        requestIdsToUpdate_[0] = requestId1Before_;
        requestIdsToUpdate_[1] = requestId2Before_;

        uint256[] memory sharesToUpdate_ = new uint256[](2);
        sharesToUpdate_[0] = 2;
        sharesToUpdate_[1] = 3;

        vm.prank(lp);
        vm.expectEmit();
        emit RequestRemoved(requestId1Before_);
        emit RequestCreated(3, lp, 2);

        vm.expectEmit();
        emit RequestRemoved(requestId2Before_);
        emit RequestCreated(4, lp, 3);

        // Increase shares creates a new request and removes the old one.
        uint128[] memory newRequestIds_ = withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);

        assertEq(newRequestIds_.length, 2, "New request IDs length should be 2");
        assertEq(newRequestIds_[0],     3, "New request ID should be 3");
        assertEq(newRequestIds_[1],     4, "New request ID should be 4");

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 2, "Request IDs length should be 1");
        assertEq(shares_.length,     2, "Shares length should be 1");
        assertEq(requestIds_[0],     3, "Request ID should be 2");
        assertEq(shares_[0],         2, "Shares should be 2");
        assertEq(requestIds_[1],     4, "Request ID should be 3");
        assertEq(shares_[1],         3, "Shares should be 3");
    }

    function test_updateSharesBatch_decrease_single_request() external {
        vm.prank(pm);
        uint128 requestIdBefore_ = withdrawalManager.addShares(2, lp);

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdBefore_,         1, "Request ID should be 1");
        assertEq(requestIdsBefore_.length, 1, "Request IDs length should be 1");
        assertEq(sharesBefore_.length,     1, "Shares length should be 1");
        assertEq(requestIdsBefore_[0],     1, "Request ID should be 1");
        assertEq(sharesBefore_[0],         2, "Shares should be 2");

        uint128[] memory requestIdsToUpdate_ = new uint128[](1);
        requestIdsToUpdate_[0] = requestIdBefore_;

        uint256[] memory sharesToUpdate_ = new uint256[](1);
        sharesToUpdate_[0] = 1;

        vm.prank(lp);
        vm.expectEmit();
        emit RequestDecreased(requestIdBefore_, 1);

        // Decrease in shares updates the existing request.
        uint128[] memory newRequestIds_ = withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);

        assertEq(newRequestIds_.length, 1, "New request IDs length should be 1");
        assertEq(newRequestIds_[0],     1, "New request ID should be 1");

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 1, "Request IDs length should be 1");
        assertEq(shares_.length,     1, "Shares length should be 1");
        assertEq(requestIds_[0],     1, "Request ID should be 1");
        assertEq(shares_[0],         1, "Shares should be 1");
    }

    function test_updateSharesBatch_decrease_multiple_requests() external {
        vm.startPrank(pm);
        uint128 requestId1Before_ = withdrawalManager.addShares(2, lp);
        uint128 requestId2Before_ = withdrawalManager.addShares(2, lp);
        vm.stopPrank();

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestId1Before_,        1, "Request ID should be 1");
        assertEq(requestId2Before_,        2, "Request ID should be 1");
        assertEq(requestIdsBefore_.length, 2, "Request IDs length should be 2");
        assertEq(sharesBefore_.length,     2, "Shares length should be 2");
        assertEq(requestIdsBefore_[0],     1, "Request ID should be 1");
        assertEq(sharesBefore_[0],         2, "Shares should be 2");
        assertEq(requestIdsBefore_[1],     2, "Request ID should be 2");
        assertEq(sharesBefore_[1],         2, "Shares should be 2");

        uint128[] memory requestIdsToUpdate_ = new uint128[](2);
        requestIdsToUpdate_[0] = requestId1Before_;
        requestIdsToUpdate_[1] = requestId2Before_;

        uint256[] memory sharesToUpdate_ = new uint256[](2);
        sharesToUpdate_[0] = 1;
        sharesToUpdate_[1] = 1;

        vm.prank(lp);
        vm.expectEmit();
        emit RequestDecreased(requestId1Before_, 1);

        vm.expectEmit();
        emit RequestDecreased(requestId2Before_, 1);

        // Decrease in shares updates the existing requests.
        uint128[] memory newRequestIds_ = withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);

        assertEq(newRequestIds_.length, 2, "New request IDs length should be 2");
        assertEq(newRequestIds_[0],     1, "New request ID should be 1");
        assertEq(newRequestIds_[1],     2, "New request ID should be 2");

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 2, "Request IDs length should be 1");
        assertEq(shares_.length,     2, "Shares length should be 1");
        assertEq(requestIds_[0],     1, "Request ID should be 1");
        assertEq(shares_[0],         1, "Shares should be 1");
        assertEq(requestIds_[1],     2, "Request ID should be 2");
        assertEq(shares_[1],         1, "Shares should be 1");
    }

    function test_updateSharesBatch_increase_and_decrease_multiple_requests() external {
        vm.startPrank(pm);
        uint128 requestId1Before_ = withdrawalManager.addShares(1, lp);
        uint128 requestId2Before_ = withdrawalManager.addShares(2, lp);
        vm.stopPrank();

        (uint128[] memory requestIdsBefore_, uint256[] memory sharesBefore_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestId1Before_,        1, "Request ID should be 1");
        assertEq(requestId2Before_,        2, "Request ID should be 1");
        assertEq(requestIdsBefore_.length, 2, "Request IDs length should be 2");
        assertEq(sharesBefore_.length,     2, "Shares length should be 2");
        assertEq(requestIdsBefore_[0],     1, "Request ID should be 1");
        assertEq(sharesBefore_[0],         1, "Shares should be 1");
        assertEq(requestIdsBefore_[1],     2, "Request ID should be 2");
        assertEq(sharesBefore_[1],         2, "Shares should be 2");

        uint128[] memory requestIdsToUpdate_ = new uint128[](2);
        requestIdsToUpdate_[0] = requestId1Before_;
        requestIdsToUpdate_[1] = requestId2Before_;

        uint256[] memory sharesToUpdate_ = new uint256[](2);
        sharesToUpdate_[0] = 2;
        sharesToUpdate_[1] = 1;

        vm.prank(lp);
        vm.expectEmit();
        emit RequestRemoved(requestId1Before_);
        emit RequestCreated(3, lp, 2);

        vm.expectEmit();
        emit RequestDecreased(requestId2Before_, 1);

        // Decrease in shares updates the existing requests.
        uint128[] memory newRequestIds_ = withdrawalManager.updateSharesBatch(requestIdsToUpdate_, sharesToUpdate_);

        assertEq(newRequestIds_.length, 2, "New request IDs length should be 2");
        assertEq(newRequestIds_[0],     3, "New request ID should be 3");
        assertEq(newRequestIds_[1],     2, "New request ID should be 2");

        (uint128[] memory requestIds_, uint256[] memory shares_) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 2, "Request IDs length should be 1");
        assertEq(shares_.length,     2, "Shares length should be 1");
        assertEq(requestIds_[0],     2, "Request ID should be 2");
        assertEq(shares_[0],         1, "Shares should be 1");
        assertEq(requestIds_[1],     3, "Request ID should be 3");
        assertEq(shares_[1],         2, "Shares should be 2");
    }

}
