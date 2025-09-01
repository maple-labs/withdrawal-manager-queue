// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../utils/TestBase.sol";

contract RemoveSharesTests is TestBase {

    event RequestDecreased(uint256 indexed requestId, uint256 shares);
    event RequestRemoved(uint256 indexed requestId);

    function setUp() public override {
        super.setUp();

        // Simulate LP transfer into PM.
        pool.mint(pm, 7);

        vm.prank(pm);
        pool.approve(address(withdrawalManager), 7);
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
        ( uint256 lastRequestId_,) = getLastRequestByOwner(pm);

        assertEq(lastRequestId_, 0);

        vm.prank(pm);
        vm.expectRevert("WM:RS:INSUFFICIENT_SHARES");
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
        uint256 lastRequestId_;

        vm.prank(pm);
        withdrawalManager.addShares(2, lp);

        assertEq(withdrawalManager.userEscrowedShares(lp), 2);

        vm.expectEmit();
        emit RequestDecreased(1, 1);

        vm.prank(pm);
        uint256 sharesReturned_ = withdrawalManager.removeShares(1, lp);

        assertEq(sharesReturned_                         , 1);
        assertEq(withdrawalManager.userEscrowedShares(lp), 1);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( address owner_ , uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestId_, ) = getLastRequestByOwner(owner_);

        assertEq(shares_,                         1);
        assertEq(withdrawalManager.totalShares(), 1);
        assertEq(lastRequestId_,                  1);
    }

    function test_removeShares_success_cancelRequest() external {
        uint256 lastRequestId_;

        vm.prank(pm);
        withdrawalManager.addShares(2, lp);

        assertEq(withdrawalManager.userEscrowedShares(lp), 2);

        vm.expectEmit();
        emit RequestRemoved(1);

        vm.prank(pm);
        uint256 sharesReturned_ = withdrawalManager.removeShares(2, lp);

        assertEq(sharesReturned_, 2);

        ( , lastRequestId_ ) = withdrawalManager.queue();

        ( address owner_ , uint256 shares_ ) = withdrawalManager.requests(lastRequestId_);

        ( lastRequestId_, ) = getLastRequestByOwner(owner_);

        assertEq(lastRequestId_,                  0);
        assertEq(owner_,                          address(0));
        assertEq(shares_,                         0);
        assertEq(withdrawalManager.totalShares(), 0);

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
    }

    function test_removeShares_success_partial_multipleRequests() external {
        vm.startPrank(pm);
        withdrawalManager.addShares(2, lp);
        withdrawalManager.addShares(4, lp);
        withdrawalManager.addShares(1, lp);
        vm.stopPrank();

        assertEq(withdrawalManager.userEscrowedShares(lp), 7);
        assertEq(withdrawalManager.totalShares()         , 7);

        ( uint256[] memory requestIds_, uint256[] memory shares_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 3);
        assertEq(shares_.length    , 3);

        ( uint256 lastRequestId_, uint256 lastShares_ ) = getLastRequestByOwner(lp);

        assertEq(lastRequestId_, 3);
        assertEq(lastShares_   , 1);

        vm.prank(pm);
        uint256 sharesReturned_ = withdrawalManager.removeShares(3, lp);

        assertEq(sharesReturned_,                          3);
        assertEq(withdrawalManager.userEscrowedShares(lp), 4);
        assertEq(withdrawalManager.totalShares()         , 4);

        ( lastRequestId_, lastShares_ ) = getLastRequestByOwner(lp);

        assertEq(lastRequestId_, 2);
        assertEq(lastShares_   , 2);

        ( requestIds_, shares_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 2);
        assertEq(shares_.length    , 2);

        assertRequest(1, lp, 2);
        assertRequest(2, lp, 2);

        vm.prank(pm);
        sharesReturned_ = withdrawalManager.removeShares(2, lp);

        assertEq(sharesReturned_,                          2);
        assertEq(withdrawalManager.userEscrowedShares(lp), 2);
        assertEq(withdrawalManager.totalShares()         , 2);

        ( requestIds_, shares_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 1);
        assertEq(shares_.length    , 1);

        assertRequest(1, lp, 2);
    }

    function test_removeShares_success_cancelAllRequests() external {
        vm.startPrank(pm);
        withdrawalManager.addShares(2, lp);
        withdrawalManager.addShares(4, lp);
        withdrawalManager.addShares(1, lp);
        vm.stopPrank();

        assertEq(withdrawalManager.userEscrowedShares(lp), 7);
        assertEq(withdrawalManager.totalShares()         , 7);

        ( uint256[] memory requestIds_, uint256[] memory shares_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 3);
        assertEq(shares_.length    , 3);

        ( uint256 lastRequestId_, uint256 lastShares_ ) = getLastRequestByOwner(lp);

        assertEq(lastRequestId_, 3);
        assertEq(lastShares_   , 1);

        vm.prank(pm);
        uint256 sharesReturned_ = withdrawalManager.removeShares(7, lp);

        assertEq(sharesReturned_,                          7);
        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
        assertEq(withdrawalManager.totalShares()         , 0);

        ( requestIds_, shares_ ) = withdrawalManager.requestsByOwner(lp);

        assertEq(requestIds_.length, 0);
        assertEq(shares_.length    , 0);

        assertEq(withdrawalManager.userEscrowedShares(lp), 0);
        assertEq(withdrawalManager.totalShares()         , 0);

        ( lastRequestId_, lastShares_ ) = getLastRequestByOwner(lp);

        assertEq(lastRequestId_, 0);
        assertEq(lastShares_   , 0);
    }
    
}
