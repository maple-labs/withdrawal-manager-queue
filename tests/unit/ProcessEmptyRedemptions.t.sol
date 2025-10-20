// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract ProcessEmptyRedemptionsFailureTests is TestBase {

    function setUp() public override {
        super.setUp();

        globals.__setIsInstanceOf(false);
    }

    function test_processEmptyRedemptions_protocolPaused() external {
        globals.__setFunctionPaused(true);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PAUSED");
        withdrawalManager.processEmptyRedemptions(1);
    }

    function test_processEmptyRedemptions_notRedeemer() external {
        vm.prank(lp);
        vm.expectRevert("WM:NOT_REDEEMER");
        withdrawalManager.processEmptyRedemptions(1);
    }

    function test_processEmptyRedemptions_governorNotAllowed() external {
        vm.prank(governor);
        vm.expectRevert("WM:NOT_REDEEMER");
        withdrawalManager.processEmptyRedemptions(1);
    }

    function test_processEmptyRedemptions_zeroRequests() external {
        vm.prank(poolDelegate);
        vm.expectRevert("WM:PER:ZERO_REQUESTS");
        withdrawalManager.processEmptyRedemptions(0);
    }

}

contract ProcessEmptyRedemptionsSuccessTests is TestBase {

    function setUp() public override {
        super.setUp();

        // Setup pool with assets and shares
        pool.mint(pm, 1000e18);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), 1000e18);
    }

    function test_processEmptyRedemptions_poolDelegate() external {
        // Add a request
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(100, lp);

        assertQueue({ nextRequestId: 1, lastRequestId: 1 });
        assertRequest({ requestId: 1, owner: lp, shares: 100 });

        // Remove the request using removeSharesById
        vm.prank(lp);
        withdrawalManager.removeSharesById(requestId, 100);

        // Request should now be empty
        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ nextRequestId: 1, lastRequestId: 1 });

        // Process empty redemptions as pool delegate
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(1);
        withdrawalManager.processEmptyRedemptions(1);

        // Queue should have moved forward
        assertQueue({ nextRequestId: 2, lastRequestId: 1 });
    }

    function test_processEmptyRedemptions_operationalAdmin() external {
        // Add a request
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(100, lp);

        // Remove the request
        vm.prank(lp);
        withdrawalManager.removeSharesById(requestId, 100);

        // Process empty redemptions as operational admin
        vm.prank(operationalAdmin);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(1);
        withdrawalManager.processEmptyRedemptions(1);

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });
    }

    function test_processEmptyRedemptions_redeemer() external {
        globals.__setIsInstanceOf(true);

        // Add a request
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(100, lp);

        // Remove the request
        vm.prank(lp);
        withdrawalManager.removeSharesById(requestId, 100);

        // Process empty redemptions as redeemer bot
        vm.prank(redeemer);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(1);
        withdrawalManager.processEmptyRedemptions(1);

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });
    }

    function test_processEmptyRedemptions_multipleEmptyRequests() external {
        // Create 5 requests
        vm.startPrank(pm);
        uint256 requestId1 = withdrawalManager.addShares(100, lp);
        uint256 requestId2 = withdrawalManager.addShares(200, lp);
        uint256 requestId3 = withdrawalManager.addShares(300, lp);
        withdrawalManager.addShares(400, lp);  // requestId4
        withdrawalManager.addShares(500, lp);  // requestId5
        vm.stopPrank();

        assertQueue({ nextRequestId: 1, lastRequestId: 5 });

        // Remove first 3 requests
        vm.startPrank(lp);
        withdrawalManager.removeSharesById(requestId1, 100);
        withdrawalManager.removeSharesById(requestId2, 200);
        withdrawalManager.removeSharesById(requestId3, 300);
        vm.stopPrank();

        // All three should now be empty
        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ requestId: 3, owner: address(0), shares: 0 });
        assertRequest({ requestId: 4, owner: lp, shares: 400 });
        assertRequest({ requestId: 5, owner: lp, shares: 500 });

        // Process 3 empty redemptions
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(3);
        withdrawalManager.processEmptyRedemptions(3);

        // Queue should have advanced by 3
        assertQueue({ nextRequestId: 4, lastRequestId: 5 });
    }

    function test_processEmptyRedemptions_stopsAtNonEmptyRequest() external {
        // Create 5 requests
        vm.startPrank(pm);
        uint256 requestId1 = withdrawalManager.addShares(100, lp);
        uint256 requestId2 = withdrawalManager.addShares(200, lp);
        withdrawalManager.addShares(300, lp);  // requestId3 - keep this one
        withdrawalManager.addShares(400, lp);  // requestId4
        withdrawalManager.addShares(500, lp);  // requestId5
        vm.stopPrank();

        assertQueue({ nextRequestId: 1, lastRequestId: 5 });

        // Remove only first 2 requests (leave request 3)
        vm.startPrank(lp);
        withdrawalManager.removeSharesById(requestId1, 100);
        withdrawalManager.removeSharesById(requestId2, 200);
        vm.stopPrank();

        assertRequest({ requestId: 1, owner: address(0), shares: 0 });
        assertRequest({ requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ requestId: 3, owner: lp, shares: 300 });
        assertRequest({ requestId: 4, owner: lp, shares: 400 });
        assertRequest({ requestId: 5, owner: lp, shares: 500 });

        // Try to process 5 empty redemptions, but should stop at request 3
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(2);  // Only 2 were processed
        withdrawalManager.processEmptyRedemptions(5);

        // Queue should only advance by 2 (stopped at non-empty request 3)
        assertQueue({ nextRequestId: 3, lastRequestId: 5 });

        // Now remove requests 3, 4, and 5
        vm.startPrank(lp);
        withdrawalManager.removeSharesById(3, 300);
        withdrawalManager.removeSharesById(4, 400);
        withdrawalManager.removeSharesById(5, 500);
        vm.stopPrank();

        // Process the remaining empty requests
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(3);
        withdrawalManager.processEmptyRedemptions(10);  // Request more than available

        // Queue should now be fully processed
        assertQueue({ nextRequestId: 6, lastRequestId: 5 });
    }

    function test_processEmptyRedemptions_noEmptyRequests() external {
        // Create 3 requests but don't remove any
        vm.startPrank(pm);
        withdrawalManager.addShares(100, lp);
        withdrawalManager.addShares(200, lp);
        withdrawalManager.addShares(300, lp);
        vm.stopPrank();

        assertQueue({ nextRequestId: 1, lastRequestId: 3 });

        // Try to process empty redemptions - should process 0 requests
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(0);
        withdrawalManager.processEmptyRedemptions(5);

        // Queue should not move
        assertQueue({ nextRequestId: 1, lastRequestId: 3 });
    }

    function test_processEmptyRedemptions_emptyQueueNoStateChange() external {
        // Queue is empty initially
        assertQueue({ nextRequestId: 1, lastRequestId: 0 });

        // Try to process empty redemptions on empty queue
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(0);
        withdrawalManager.processEmptyRedemptions(10);

        // Queue should remain unchanged
        assertQueue({ nextRequestId: 1, lastRequestId: 0 });
    }

    function test_processEmptyRedemptions_fullyProcessedQueueNoStateChange() external {
        // Create and remove a request
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(100, lp);

        vm.prank(lp);
        withdrawalManager.removeSharesById(requestId, 100);

        // Process the empty request
        vm.prank(poolDelegate);
        withdrawalManager.processEmptyRedemptions(1);

        assertQueue({ nextRequestId: 2, lastRequestId: 1 });

        // Try to process again - queue is fully processed
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(0);
        withdrawalManager.processEmptyRedemptions(10);

        // Queue should remain unchanged
        assertQueue({ nextRequestId: 2, lastRequestId: 1 });
    }

    function test_processEmptyRedemptions_chunkProcessing() external {
        // Create 10 requests
        vm.startPrank(pm);
        for (uint256 i = 1; i <= 10; i++) {
            withdrawalManager.addShares(i * 100, lp);
        }
        vm.stopPrank();

        // Remove first 5 requests
        vm.startPrank(lp);
        for (uint256 i = 1; i <= 5; i++) {
            withdrawalManager.removeSharesById(i, i * 100);
        }
        vm.stopPrank();

        assertQueue({ nextRequestId: 1, lastRequestId: 10 });

        // Process only 3 empty requests
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(3);
        withdrawalManager.processEmptyRedemptions(3);

        assertQueue({ nextRequestId: 4, lastRequestId: 10 });

        // Process remaining 2 empty requests
        vm.prank(poolDelegate);
        vm.expectEmit();
        emit EmptyRedemptionsProcessed(2);
        withdrawalManager.processEmptyRedemptions(2);

        assertQueue({ nextRequestId: 6, lastRequestId: 10 });

        // Requests 6-10 should still exist
        for (uint256 i = 6; i <= 10; i++) {
            assertRequest({ requestId: i, owner: lp, shares: i * 100 });
        }
    }

}
