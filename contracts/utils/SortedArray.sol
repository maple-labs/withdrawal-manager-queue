// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

// TODO: How to best handle library interfaces?
library SortedArray {

    struct Array {
        uint128[] values;

        mapping(uint128 => uint256) valueToIndex;
    }

    /**************************************************************************************************************************************/
    /*** Write Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     * @dev   Pushes a value to the array.
     *        It is expected that the value is biggest so far so it will be added at the end of the array.
     * @param array_ The array to push the value to.
     * @param value_ The value to push to the array.
     */
    function push(Array storage array_, uint128 value_) internal {
        require(getLast(array_) < value_, "SA:P:NOT_LARGEST");

        array_.values.push(value_);
        array_.valueToIndex[value_] = length(array_) - 1;
    }

    /**
     * @dev   Removes a value from the array.
     *        It shifts the rest of the array to the left.
     *        It is expected by contract that uses this library to check that the value is present in the array before call of the function.
     * @param array_ The array to remove the value from.
     * @param value_ The value to remove from the array.
     */
    function remove(Array storage array_, uint128 value_) internal {
        uint256 length_ = length(array_);

        if (length_ == 1) {
            _deleteValue(array_, value_);
            return;
        }

        uint256 index_ = array_.valueToIndex[value_];

        for (uint256 i = index_; i <= length_ - 2; i++) {
            uint128 nextValue_              = array_.values[i + 1];
            array_.values[i]                = nextValue_;
            array_.valueToIndex[nextValue_] = i;
        }

        _deleteValue(array_, value_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     * @dev    Gets a value from the array at given index.
     * @param  array_ The array to get the value from.
     * @param  index_ The index of the value to get from the array.
     * @return value_ The value at the given index.
     */
    function get(Array storage array_, uint256 index_) internal view returns (uint128 value_) {
        require(index_ < length(array_), "SA:G:OUT_OF_BOUNDS");
        value_ = array_.values[index_];
    }

    /**
     * @dev    Gets the length of the array.
     * @param  array_  The array to get the length of.
     * @return length_ The length of the array.
     */
    function length(Array storage array_) internal view returns (uint256 length_) {
        length_ = array_.values.length;
    }

    /**
     * @dev    Gets all values from the array.
     * @param  array_  The array to get the values from.
     * @return values_ All values from the array.
     */
    function getAllValues(Array storage array_) internal view returns (uint128[] memory values_) {
        values_ = array_.values;
    }

    /**
     * @dev    Gets the last value in the array.
     * @param  array_  The array to get the last value from.
     * @return value_  The last value in the array.
     */
    function getLast(Array storage array_) internal view returns (uint128 value_) {
        uint256 length_ = length(array_);
        return length_ > 0 ? array_.values[length_ - 1] : 0;
    }

    /**************************************************************************************************************************************/
    /*** Private Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    /**
     * @dev    Deletes a value from the array.
     *         It is expected that array is already shifted so this will just pop the last and flag given value as not present.
     * @param  array_  The array to delete the value from.
     * @param  value_  The value to delete from the array.
     */
    function _deleteValue(Array storage array_, uint128 value_) private {
        array_.values.pop();
        delete array_.valueToIndex[value_];
    }

}
