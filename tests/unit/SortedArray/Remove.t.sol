// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedLinkedListTestBase } from "../../utils/TestBase.sol";

contract RemoveTests is SortedLinkedListTestBase {

    function test_remove_failed_valueNotExists() external {
        vm.expectRevert("SLL:R:VALUE_NOT_EXISTS");
        list.remove(1);
    }

    function test_remove_singleValue() external {
        list.push(1);
        list.remove(1);

        uint256[] memory expectedValues = new uint256[](0);
        assertList(expectedValues);

        assertEq(list.length(), 0);
    }

    function test_remove_multipleValues() external {
        list.push(1);
        list.push(2);
        list.push(3);

        list.remove(2);

        uint256[] memory expectedValues = new uint256[](2);
        expectedValues[0]               = 1;
        expectedValues[1]               = 3;

        assertList(expectedValues);
        assertEq(list.length(), 2);

        list.remove(1);

        expectedValues    = new uint256[](1);
        expectedValues[0] = 3;

        assertList(expectedValues);
        assertEq(list.length(), 1);

        list.remove(3);

        assertList(new uint256[](0));
        assertEq(list.length(), 0);
    }

}
