// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

library SortedArray {

    struct Array {
        uint256[] values;

        mapping(uint256 => uint256) valueToIndex;
    }

    /**************************************************************************************************************************************/
    /*** Write Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     * @dev   Pushes a value to the array.
     *        It is expected that the value is biggest so far so it will be added at the end of the array.
     * @param array  The array to push the value to.
     * @param value_ The value to push to the array.
     */
    function push(Array storage array, uint256 value_) internal {
        require(getLast(array) < value_, "SA:P:NOT_LARGEST");

        array.values.push(value_);
        array.valueToIndex[value_] = length(array) - 1;
    }

    /**
     * @dev   Removes a value from the array.
     *        It shifts the rest of the array to the left.
     *        It is expected by contract that uses this library to check that the value is present in the array before call of the function.
     * @param array  The array to remove the value from.
     * @param value_ The value to remove from the array.
     */
    function remove(Array storage array, uint256 value_) internal {
        uint256 length_ = length(array);

        if (length_ == 1) {
            _deleteValue(array, value_);
            return;
        }

        uint256 index_ = array.valueToIndex[value_];

        for (uint256 i = index_; i <= length_ - 2; i++) {
            uint256 nextValue_             = array.values[i + 1];
            array.values[i]                = nextValue_;
            array.valueToIndex[nextValue_] = i;
        }

        _deleteValue(array, value_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     * @dev    Gets a value from the array at given index.
     * @param  array  The array to get the value from.
     * @param  index_ The index of the value to get from the array.
     * @return value_ The value at the given index.
     */
    function get(Array storage array, uint256 index_) internal view returns (uint256 value_) {
        require(index_ < length(array), "SA:G:OUT_OF_BOUNDS");
        value_ = array.values[index_];
    }

    /**
     * @dev    Gets the length of the array.
     * @param  array   The array to get the length of.
     * @return length_ The length of the array.
     */
    function length(Array storage array) internal view returns (uint256 length_) {
        length_ = array.values.length;
    }

    /**
     * @dev    Gets all values from the array.
     * @param  array   The array to get the values from.
     * @return values_ All values from the array.
     */
    function getAllValues(Array storage array) internal view returns (uint256[] memory values_) {
        values_ = array.values;
    }

    /**
     * @dev    Gets the last value in the array.
     * @param  array   The array to get the last value from.
     * @return value_  The last value in the array.
     */
    function getLast(Array storage array) internal view returns (uint256 value_) {
        uint256 length_ = length(array);
        return length_ > 0 ? array.values[length_ - 1] : 0;
    }

    /**************************************************************************************************************************************/
    /*** Private Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    /**
     * @dev    Deletes a value from the array.
     *         It is expected that array is already shifted so this will just pop the last and flag given value as not present.
     * @param  array   The array to delete the value from.
     * @param  value_  The value to delete from the array.
     */
    function _deleteValue(Array storage array, uint256 value_) private {
        array.values.pop();
        delete array.valueToIndex[value_];
    }

}
