// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleWithdrawalManagerMigratorV200 } from "../../contracts/proxy/MapleWithdrawalManagerMigratorV200.sol";
import { TestBase }                      from "../utils/TestBase.sol";

contract WithdrawalManagerMigrateTests is TestBase {

    address internal migrator;

    function setUp() public override {
        super.setUp();

        migrator = address(new MapleWithdrawalManagerMigratorV200());
    }

    function test_migrate_notFactory() external {
        vm.expectRevert("WM:M:NOT_FACTORY");
        withdrawalManager.migrate(migrator, "");
    }

    function test_migrate_protocolPaused() external {
        globals.__setFunctionPaused(true);

        vm.expectRevert("WM:PAUSED");
        withdrawalManager.migrate(migrator, "");
    }

    function test_migrate_success_xxx() external {
        withdrawalManager.__setRequestLegacy(10, address(0x01), 1);
        withdrawalManager.__setRequestLegacy(12, address(0x01), 2);
        withdrawalManager.__setRequestLegacy(13, address(0x02), 4);
        withdrawalManager.__setRequestLegacy(15, address(0x03), 5);

        withdrawalManager.__setQueue(10, 15);

        vm.prank(address(factory));
        withdrawalManager.migrate(migrator,"");

        ( uint128 nextRequestId_, uint128 lastRequestId_ ) = withdrawalManager.queue();

        assert(nextRequestId_ == 10);
        assert(lastRequestId_ == 15);

        assertEq(withdrawalManager.userEscrowedShares(address(0x01)), 3);
        assertEq(withdrawalManager.userEscrowedShares(address(0x02)), 4);
        assertEq(withdrawalManager.userEscrowedShares(address(0x03)), 5);

        address owner_;
        uint256 shares_;

        ( owner_, shares_ ) = withdrawalManager.requests(10);
        assertEq(owner_, address(0x01));
        assertEq(shares_, 1);

        ( owner_, shares_ ) = withdrawalManager.requests(11);
        assertEq(owner_, address(0));
        assertEq(shares_, 0);

        ( owner_, shares_ ) = withdrawalManager.requests(12);
        assertEq(owner_, address(0x01));
        assertEq(shares_, 2);    

        ( owner_, shares_ ) = withdrawalManager.requests(13);
        assertEq(owner_, address(0x02));
        assertEq(shares_, 4);    

        ( owner_, shares_ ) = withdrawalManager.requests(14);
        assertEq(owner_, address(0));
        assertEq(shares_, 0);    

        ( owner_, shares_ ) = withdrawalManager.requests(15);
        assertEq(owner_, address(0x03));
        assertEq(shares_, 5);   
    }

}
