// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract RemoveSharesByIdFailureTests is TestBase {

    function setUp() public override {
        super.setUp();
        uint256 mintAmount = 200;

        // Simulate LP transfer into PM.
        pool.mint(pm, mintAmount);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), mintAmount);
    }

    function test_removeSharesById_protocolPaused() external {
        globals.__setFunctionPaused(true);

        vm.prank(lp);
        vm.expectRevert("WM:PAUSED");
        withdrawalManager.removeSharesById(1, 1);
    }

    function test_removeSharesById_maxUint128Exceeded() external {
        vm.prank(lp);
        vm.expectRevert("WM:TU:UINT256_CAST");
        withdrawalManager.removeSharesById(type(uint256).max, 1);
    }

    function test_removeSharesById_invalidRequest() external {
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        withdrawalManager.removeSharesById(1, 1);
    }

    function test_removeSharesById_requestAlreadyRemoved() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = 1;

        vm.prank(governor);
        withdrawalManager.removeRequest(lp, requestIds);

        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        vm.prank(lp);
        withdrawalManager.removeSharesById(1, 100);
    }

    function test_removeSharesById_zeroRequestId() external {
        vm.prank(lp);
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        withdrawalManager.removeSharesById(0, 1); // Request ID 0 should be invalid
    }

    function test_removeSharesById_notOwner() external {
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(1, lp);

        vm.prank(address(0x12));
        vm.expectRevert("WM:RSBI:NOT_OWNER");
        withdrawalManager.removeSharesById(requestId, 1);
    }

    function test_removeSharesById_noChange() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.prank(lp);
        vm.expectRevert("WM:RSBI:NO_CHANGE");
        withdrawalManager.removeSharesById(1, 0);
    }

    function test_removeSharesById_insufficientShares() external {
        vm.prank(pm);
        withdrawalManager.addShares(5, lp);

        // Try to remove 10 shares (more than the 5 available)
        vm.prank(lp);
        vm.expectRevert("WM:RSBI:INSUFFICIENT_SHARES");
        withdrawalManager.removeSharesById(1, 10);
    }

    function test_removeSharesById_transferFail() external {
        vm.prank(pm);
        withdrawalManager.addShares(5, lp);

        // Burn the tokens from the withdrawal manager to simulate transfer failure
        pool.burn(address(withdrawalManager), 5);

        vm.prank(lp);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        withdrawalManager.removeSharesById(1, 1);
    }

}

contract RemoveSharesByIdSuccessTests is TestBase {

    address lp2 = makeAddr("lp2");

    address ownerForRequest1;
    address ownerForRequest2;
    address ownerForRequest3;
    address ownerForRequest4;

    uint256 requestAmount1;
    uint256 requestAmount2;

    uint256 sharesForRequest1;
    uint256 sharesForRequest2;
    uint256 sharesForRequest3;
    uint256 sharesForRequest4;

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

    function test_removeSharesById_remove_request() external{
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(1, lp);

        ( address ownerBefore, uint256 sharesBefore ) = withdrawalManager.requests(requestId);

        assertEq(ownerBefore,  lp);
        assertEq(sharesBefore, 1);

        ( uint256[] memory requestIdsBefore, uint256[] memory sharesPerRequestBefore ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdsBefore.length,       1);
        assertEq(sharesPerRequestBefore.length, 1);
        assertEq(requestIdsBefore[0],           requestId);
        assertEq(sharesPerRequestBefore[0],     1);

        assertEq(withdrawalManager.userEscrowedShares(lp), 1);

        vm.prank(lp);
        vm.expectEmit();
        emit RequestRemoved(requestId);

        ( uint256 sharesReturned_, uint256 sharesRemaining_ ) = withdrawalManager.removeSharesById(requestId, 1);

        assertEq(sharesReturned_,  1);
        assertEq(sharesRemaining_, 0);

        ( address ownerAfter, uint256 sharesAfter ) = withdrawalManager.requests(requestId);

        assertEq(ownerAfter,  address(0));
        assertEq(sharesAfter, 0);

        ( uint256[] memory requestIdsAfter, uint256[] memory sharesPerRequestAfter ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdsAfter.length,       0);
        assertEq(sharesPerRequestAfter.length, 0);

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
    }

    function test_removeSharesById_decrease() external {
        vm.prank(pm);
        uint256 requestId = withdrawalManager.addShares(2, lp);

        ( address ownerBefore, uint256 sharesBefore ) = withdrawalManager.requests(requestId);

        assertEq(ownerBefore,  lp);
        assertEq(sharesBefore, 2);

        ( uint256[] memory requestIdsBefore, uint256[] memory sharesPerRequestBefore ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdsBefore.length,       1);
        assertEq(sharesPerRequestBefore.length, 1);
        assertEq(requestIdsBefore[0],           requestId);
        assertEq(sharesPerRequestBefore[0],     2);

        assertEq(withdrawalManager.userEscrowedShares(lp), 2);

        vm.prank(lp);
        vm.expectEmit();
        emit RequestDecreased(requestId, 1);

        ( uint256 sharesReturned_, uint256 sharesRemaining_ ) = withdrawalManager.removeSharesById(requestId, 1);

        assertEq(sharesReturned_,  1);
        assertEq(sharesRemaining_, 1);

        ( address ownerAfter, uint256 sharesAfter ) = withdrawalManager.requests(requestId);

        assertEq(ownerAfter,  lp);
        assertEq(sharesAfter, 1);

        ( uint256[] memory requestIdsAfter, uint256[] memory sharesPerRequestAfter ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIdsAfter.length,       1);
        assertEq(sharesPerRequestAfter.length, 1);
        assertEq(requestIdsAfter[0],           requestId);
        assertEq(sharesPerRequestAfter[0],     1);

        assertEq(withdrawalManager.userEscrowedShares(lp), 1);
    }

    function test_removeSharesById_multipleLPsWithMultipleRequests() external {
        requestAmount1 = 10;
        requestAmount2 = 20;

        pool.mint(pm,  3000);
        pool.mint(lp,  1000);
        pool.mint(lp2, 1000);

        // Create multiple requests for both LPs
        vm.startPrank(pm);

        vm.expectEmit();
        emit RequestCreated(1, lp, requestAmount1);
        withdrawalManager.addShares(requestAmount1, lp);

        vm.expectEmit();
        emit RequestCreated(2, lp, requestAmount2);
        withdrawalManager.addShares(requestAmount2, lp);

        vm.expectEmit();
        emit RequestCreated(3, lp2, requestAmount1);
        withdrawalManager.addShares(requestAmount1, lp2);

        vm.expectEmit();
        emit RequestCreated(4, lp2, requestAmount2);
        withdrawalManager.addShares(requestAmount2, lp2);

        vm.stopPrank();

        assertEq(withdrawalManager.userEscrowedShares(lp),  requestAmount1 + requestAmount2);
        assertEq(withdrawalManager.userEscrowedShares(lp2), requestAmount1 + requestAmount2);

        ( ownerForRequest1, sharesForRequest1 ) = withdrawalManager.requests(1);
        ( ownerForRequest2, sharesForRequest2 ) = withdrawalManager.requests(2);
        ( ownerForRequest3, sharesForRequest3 ) = withdrawalManager.requests(3);
        ( ownerForRequest4, sharesForRequest4 ) = withdrawalManager.requests(4);

        assertEq(ownerForRequest1, lp);
        assertEq(ownerForRequest2, lp);
        assertEq(ownerForRequest3, lp2);
        assertEq(ownerForRequest4, lp2);

        assertEq(sharesForRequest1, requestAmount1);
        assertEq(sharesForRequest2, requestAmount2);
        assertEq(sharesForRequest3, requestAmount1);
        assertEq(sharesForRequest4, requestAmount2);

        ( uint256[] memory requestIdsLp1Before, uint256[] memory sharesLp1Before )   = withdrawalManager.requestsByOwner(lp);
        ( uint256[] memory requestIdsLp2Before, uint256[] memory sharesLp2Before ) = withdrawalManager.requestsByOwner(lp2);

        assertEq(requestIdsLp1Before.length,  2);
        assertEq(sharesLp1Before.length,      2);

        assertEq(requestIdsLp2Before.length, 2);
        assertEq(sharesLp2Before.length,     2);

        assertEq(requestIdsLp1Before[0],  1);
        assertEq(requestIdsLp1Before[1],  2);

        assertEq(requestIdsLp2Before[0], 3);
        assertEq(requestIdsLp2Before[1], 4);

        assertEq(sharesLp1Before[0],  requestAmount1);
        assertEq(sharesLp1Before[1],  requestAmount2);

        assertEq(sharesLp2Before[0], requestAmount1);
        assertEq(sharesLp2Before[1], requestAmount2);

        // Decrease LP1's first request
        vm.prank(lp);
        vm.expectEmit();
        emit RequestDecreased(1, 1);
        ( uint256 sharesReturnedLp, uint256 sharesRemainingLp ) = withdrawalManager.removeSharesById(1, 1);

        assertEq(sharesReturnedLp,  1);
        assertEq(sharesRemainingLp, requestAmount1 - 1);

        // Remove LP2's first request completely
        vm.prank(lp2);
        vm.expectEmit();
        emit RequestRemoved(3);
        ( uint256 sharesReturnedLp2, uint256 sharesRemainingLp2 ) = withdrawalManager.removeSharesById(3, requestAmount1);

        assertEq(sharesReturnedLp2,  requestAmount1);
        assertEq(sharesRemainingLp2, 0);

        assertEq(withdrawalManager.userEscrowedShares(lp),  requestAmount1 - 1 + requestAmount2);
        assertEq(withdrawalManager.userEscrowedShares(lp2), requestAmount2);

        ( ownerForRequest1, sharesForRequest1 ) = withdrawalManager.requests(1);
        ( ownerForRequest2, sharesForRequest2 ) = withdrawalManager.requests(2);
        ( ownerForRequest3, sharesForRequest3 ) = withdrawalManager.requests(3);
        ( ownerForRequest4, sharesForRequest4 ) = withdrawalManager.requests(4);

        assertEq(ownerForRequest1, lp);          // LP's first request should be decreased but still exist
        assertEq(ownerForRequest2, lp);          // LP's second request should be unchanged
        assertEq(ownerForRequest3, address(0));  // LP2's first request should be removed
        assertEq(ownerForRequest4, lp2);         // LP2's second request should be unchanged

        assertEq(sharesForRequest1, requestAmount1 - 1);  // LP's first request decreased
        assertEq(sharesForRequest2, requestAmount2);      // LP's second request unchanged
        assertEq(sharesForRequest3, 0);                   // LP2's first request removed
        assertEq(sharesForRequest4, requestAmount2);      // LP2's second request unchanged

        ( uint256[] memory requestIdsLp1After, uint256[] memory sharesLp1After )   = withdrawalManager.requestsByOwner(lp);
        ( uint256[] memory requestIdsLp2After, uint256[] memory sharesLp2After ) = withdrawalManager.requestsByOwner(lp2);

        assertEq(requestIdsLp1After.length, 2);
        assertEq(sharesLp1After.length,     2);

        assertEq(requestIdsLp2After.length, 1);
        assertEq(sharesLp2After.length,     1);

        assertEq(requestIdsLp1After[0], 1);
        assertEq(requestIdsLp1After[1], 2);

        assertEq(requestIdsLp2After[0], 4);

        assertEq(sharesLp1After[0], requestAmount1 - 1);
        assertEq(sharesLp1After[1], requestAmount2);

        assertEq(sharesLp2After[0], requestAmount2);
    }

}
