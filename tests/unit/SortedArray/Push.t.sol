
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedLinkedListTestBase } from "../../utils/TestBase.sol";

contract PushTests is SortedLinkedListTestBase {

    function test_push_failed_zeroValue() external {
        vm.expectRevert("SLL:P:ZERO_VALUE");
        list.push(0);
    }

    function test_push_failed_valueExists() external {
        list.push(1);

        vm.expectRevert("SLL:P:VALUE_EXISTS");
        list.push(1);
    }

    function test_push_failed_outOfOrder() external {
        list.push(3);

        vm.expectRevert("SLL:P:NOT_LARGEST");
        list.push(1);
    }

    function test_push_singleValue() external {
        list.push(3);

        uint256[] memory expectedValues = new uint256[](1);
        expectedValues[0]               = 3;

        assertList(expectedValues);

        assertEq(list.length(), 1);
    }

    function test_push_multipleValues_inOrder() external {
        list.push(1);
        list.push(3);
        list.push(7);

        uint256[] memory expectedValues = new uint256[](3);
        expectedValues[0]               = 1;
        expectedValues[1]               = 3;
        expectedValues[2]               = 7;

        assertList(expectedValues);
        assertEq(list.length(), 3);
    }

}
