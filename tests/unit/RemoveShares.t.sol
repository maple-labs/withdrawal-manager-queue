// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract RemoveSharesTests is TestBase {

    event RequestDecreased(uint128 indexed requestId, uint256 shares);
    event RequestRemoved(uint128 indexed requestId);

    function setUp() public override {
        super.setUp();

        // Simulate LP transfer into PM.
        pool.mint(pm, 2);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), 2);
    }

    function test_removeShares_notPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        withdrawalManager.removeShares(1, lp);
    }

    function test_removeShares_emptyRequest() external {
        vm.prank(pm);
        vm.expectRevert("WM:RS:ZERO_SHARES");
        withdrawalManager.removeShares(0, lp);
    }

    function test_removeShares_notInQueue() external {
        ( uint128 lastRequestId_,) = getLastRequestByOwner(pm);

        assertEq(lastRequestId_, 0);

        vm.prank(pm);
        vm.expectRevert("WM:RS:NO_REQUESTS");
        withdrawalManager.removeShares(1, lp);
    }

    function test_removeShares_decreaseOnly() external {
        vm.prank(pm);
        withdrawalManager.addShares(2, lp);

        vm.prank(pm);
        vm.expectRevert("WM:RS:INSUFFICIENT_SHARES");
        withdrawalManager.removeShares(3, lp);
    }

    function test_removeShares_failedTransfer() external {
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        pool.burn(address(withdrawalManager), 1);

        vm.prank(pm);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        withdrawalManager.removeShares(1, lp);
    }

    function test_removeShares_success_decreaseRequest() external {
        uint128 lastRequestId_;

        vm.prank(pm);
        withdrawalManager.addShares(2, lp);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, 2);

        vm.expectEmit();
        emit RequestDecreased(1, 1);

        vm.prank(pm);
        withdrawalManager.removeShares(1, lp);

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, 1);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( address owner_ , uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestId_, ) = getLastRequestByOwner(owner_);

        assertEq(shares_,                         1);
        assertEq(withdrawalManager.totalShares(), 1);
        assertEq(lastRequestId_,                  1);
    }

    function test_removeShares_success_cancelRequest() external {
        uint128 lastRequestId_;

        vm.prank(pm);
        withdrawalManager.addShares(2, lp);

        ( uint256 requestCountLp_, uint256 escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        1);
        assertEq(escrowedSharesTotalLp_, 2);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(pm);
        withdrawalManager.removeShares(2, lp);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( address owner_ , uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestId_, ) = getLastRequestByOwner(owner_);

        assertEq(lastRequestId_,                  0);
        assertEq(owner_,                          address(0));
        assertEq(shares_,                         0);
        assertEq(withdrawalManager.totalShares(), 0);

        ( requestCountLp_, escrowedSharesTotalLp_ ) = withdrawalManager.userRequestSummaries(lp);

        assertEq(requestCountLp_,        0);
        assertEq(escrowedSharesTotalLp_, 0);
    }

}
