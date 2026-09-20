// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract AddSharesTests is TestBase {

    function setUp() public override {
        super.setUp();

        // Simulate LP transfer into PM.
        pool.mint(pm, 2);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), 2);
    }

    function test_addShares_notPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        withdrawalManager.addShares(1, lp);
    }

    function test_addShares_emptyRequest() external {
        vm.prank(pm);
        vm.expectRevert("WM:AS:ZERO_SHARES");
        withdrawalManager.addShares(0, lp);
    }

    function test_addShares_multiple_requests() external{
        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        ( , uint256 lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 2);

        assertEq(withdrawalManager.userEscrowedShares(lp), 2);

        ( address owner_, uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        assertEq(owner_, lp);
        assertEq(shares_, 1);

        (uint256[] memory requestIds, uint256[] memory requestShares) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds.length, 2);
        assertEq(requestShares.length, 2);
        assertEq(requestIds[0], 1);
        assertEq(requestIds[1], 2);
        assertEq(requestShares[0], 1);
        assertEq(requestShares[1], 1);
    }

    function test_addShares_failedTransfer() external {
        vm.prank(pm);
        vm.expectRevert("WM:AS:FAILED_TRANSFER");
        withdrawalManager.addShares(3, lp);
    }

    function test_addShares_newRequestAddedToQueue() external {
        ( , uint256 lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 0);

        vm.expectEmit();
        emit RequestCreated(1, lp, 1);

        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 1);

        assertEq(withdrawalManager.userEscrowedShares(lp), 1);
    }

    function test_addShares_newRequestAddedToQueue_manual() external {
        withdrawalManager.__setManualWithdrawal(lp, true);

        ( , uint256 lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 0);

        vm.expectEmit();
        emit RequestCreated(1, lp, 1);

        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 1);

        assertEq(withdrawalManager.userEscrowedShares(lp), 1);
    }

    function test_addShares_success() external {
        uint256 requestId_;

        vm.expectEmit();
        emit RequestCreated(1, lp, 1);

        vm.prank(pm);
        withdrawalManager.addShares(1, lp);

        ( , uint256 lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 1);

        assertEq(withdrawalManager.userEscrowedShares(lp), 1);

        ( address owner_, uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);
        ( requestId_,) = getLastRequestByOwner(owner_);

        assertEq(shares_,                         1);
        assertEq(withdrawalManager.totalShares(), 1);
        assertEq(requestId_,                      lastRequestId_);

        address lp2 = makeAddr("lp2");

        vm.expectEmit();
        emit RequestCreated(2, lp2, 1);

        vm.prank(pm);
        withdrawalManager.addShares(1, lp2);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        assertEq(lastRequestId_, 2);

        assertEq(withdrawalManager.userEscrowedShares(lp), 1);

        ( owner_, shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( requestId_,) = getLastRequestByOwner(owner_);

        assertEq(shares_,                         1);
        assertEq(withdrawalManager.totalShares(), 2);
        assertEq(requestId_,                      lastRequestId_);
    }

}
