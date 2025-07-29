// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SortedArrayTestBase } from "../../utils/TestBase.sol";

contract GetTests is SortedArrayTestBase {

    function test_get_outOfBounds() external {
        array.push(1);
        vm.expectRevert("SA:G:OUT_OF_BOUNDS");
        array.get(1);
    }

    function test_get_singleValue() external {
        array.push(1);
        assertEq(array.get(0), 1);
    }

    function test_get_multipleValues() external {
        array.push(1);
        array.push(2);
        array.push(3);

        assertEq(array.get(0), 1);
        assertEq(array.get(1), 2);
        assertEq(array.get(2), 3);
    }

}
