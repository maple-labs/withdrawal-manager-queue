// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleWithdrawalManagerStorage } from "./IMapleWithdrawalManagerStorage.sol";

interface IMapleWithdrawalManager is IMapleWithdrawalManagerStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when a manual redemption takes place.
     *  @param owner           Address of the account.
     *  @param sharesDecreased Amount of shares redeemed.
     */
    event ManualSharesDecreased(address indexed owner, uint256 sharesDecreased);

    /**
     *  @dev   Emitted when a manual redemption is processed.
     *  @param owner       Address of the account.
     *  @param sharesAdded Amount of shares added to the redeemable amount.
     */
    event ManualSharesIncreased(address indexed owner, uint256 sharesAdded);

    /**
     *  @dev   Emitted when the withdrawal type of an account is updated.
     *  @param owner     Address of the account.
     *  @param isManual `true` if the withdrawal is manual, `false` if it is automatic.
     */
    event ManualWithdrawalSet(address indexed owner, bool isManual);

    /**
     *  @dev   Emitted when a withdrawal request is created.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     Address of the owner of the shares.
     *  @param shares    Amount of shares requested for redemption.
     */
    event RequestCreated(uint256 indexed requestId, address indexed owner, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is updated.
     *  @param requestId Identifier of the withdrawal request.
     *  @param shares    Amount of shares reduced during a redemption request.
     */
    event RequestDecreased(uint256 indexed requestId, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is processed.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     The owner of the shares.
     *  @param shares    Amount of redeemable shares.
     *  @param assets    Amount of withdrawable assets.
     */
    event RequestProcessed(uint256 indexed requestId, address indexed owner, uint256 shares, uint256 assets);

    /**
     *  @dev   Emitted when a withdrawal request is removed.
     *  @param requestId Identifier of the withdrawal request.
     */
    event RequestRemoved(uint256 indexed requestId);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Add shares to the withdrawal manager.
     *  @param shares Amount of shares to add.
     *  @param owner  Address of the owner of shares.
     */
    function addShares(uint256 shares, address owner) external returns (uint256 lastRequestId);

    /**
     *  @dev    Processes a withdrawal request.
     *          Uses the current exchange rate to calculate the amount of assets withdrawn.
     *  @param  shares           Amount of shares that should be redeemed.
     *  @param  owner            Address of the account to process.
     *  @return redeemableShares Amount of shares that will be burned.
     *  @return resultingAssets  Amount of assets that will be withdrawn.
     */
    function processExit(uint256 shares, address owner) external returns (uint256 redeemableShares, uint256 resultingAssets);

    /**
     *  @dev   Processes pending redemption requests.
     *         Requests are processed in the order they were submitted.
     *         Automatic withdrawal requests will be fulfilled atomically.
     *  @param maxSharesToProcess Maximum number of shares that will be processed during the call.
     */
    function processRedemptions(uint256 maxSharesToProcess) external;

    /**
     *  @dev    Removes shares from the withdrawal manager.
     *  @param  shares         Amount of shares to remove.
     *  @param  owner          Address of the owner of shares.
     *  @return sharesReturned Amount of shares that were returned.
     */
    function removeShares(uint256 shares, address owner) external returns (uint256 sharesReturned);

    /**
     *  @dev    Remove shares from a specific withdrawal request.
     *  @param  requestId       Identifier of the withdrawal request that is being updated.
     *  @param  sharesToRemove  Amount of shares to remove from the request.
     *  @return sharesReturned  Amount of shares that were returned.
     *  @return sharesRemaining Amount of shares remaining in the request.
     */
    function removeSharesById(uint256 requestId, uint256 sharesToRemove) external returns (uint256 sharesReturned, uint256 sharesRemaining);

    /**
     *  @dev   Removes withdrawal requests from the queue.
     *         Can only be called by the pool delegate.
     *  @param owner      Address of the owner of shares.
     *  @param requestIds Array of identifiers of the withdrawal requests to remove.
     */
    function removeRequest(address owner, uint256[] calldata requestIds) external;

    /**
     *  @dev   Defines if an account will withdraw shares manually or automatically.
     *  @param account  Address of the account.
     *  @param isManual `true` if the account withdraws manually, `false` if the withdrawals are performed automatically.
     */
    function setManualWithdrawal(address account, bool isManual) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Returns the address of the underlying pool asset.
     *  @param asset Address of the underlying pool asset.
     */
    function asset() external view returns (address asset);

    /**
     *  @dev   Returns the address of the globals contract.
     *  @param globals Address of the globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev   Return the address of the governor.
     *  @param governor Address of the governor contract.
     */
    function governor() external view returns (address governor);

    /**
     *  @dev    Returns if a user is able to withdraw. Required for compatibility with pool managers.
     *          NOTE: Always returns true to fulfil interface requirements.
     *  @param  owner          The account to check if it's in withdraw window.
     *  @return isInExitWindow True if the account is in the withdraw window.
     */
    function isInExitWindow(address owner) external view returns (bool isInExitWindow);

    /**
     *  @dev    Gets the total amount of funds that need to be locked to fulfill exits.
     *          NOTE: Always zero for this implementation.
     *  @return lockedLiquidity The amount of locked liquidity.
     */
    function lockedLiquidity() external view returns (uint256 lockedLiquidity);

    /**
     *  @dev    Gets the amount of locked shares for an account.
     *  @param  owner        The address to check the exit for.
     *  @return lockedShares The amount of manual shares available.
     */
    function lockedShares(address owner) external view returns (uint256 lockedShares);

    /**
     *  @dev   Returns the address of the pool delegate.
     *  @param poolDelegate Address of the pool delegate.
     */
    function poolDelegate() external view returns (address poolDelegate);

    /**
     *  @dev    Returns the amount of shares that can be redeemed.
     *          NOTE: The `shares` value is ignored.
     *  @param  owner            Address of the share owner
     *  @param  shares           Amount of shares to redeem.
     *  @return redeemableShares Amount of shares that can be redeemed.
     *  @return resultingAssets  Amount of assets that can be withdrawn.
     */
    function previewRedeem(address owner, uint256 shares) external view returns (uint256 redeemableShares, uint256 resultingAssets);

    /**
     *  @dev    Gets the amount of shares that can be withdrawn.
     *          NOTE: Values just passed through as withdraw is not implemented.
     *  @param  owner            The address to check the withdrawal for.
     *  @param  assets           The amount of requested shares to withdraw.
     *  @return redeemableAssets The amount of assets that can be withdrawn.
     *  @return resultingShares  The amount of shares that will be burned.
     */
    function previewWithdraw(address owner, uint256 assets) external view returns (uint256 redeemableAssets, uint256 resultingShares);

    /**
     *  @dev    Returns the last request id for a given owner.
     *          Function must exist for backwards compatibility with the old implementation where we supported only one request per owner.
     *  @param  owner          The account to check the last request id for.
     *  @return requestId      The id of the last valid withdrawal request for the account.
     */
    function requestIds(address owner) external view returns (uint256 requestId);

    /**
     *  @dev    Returns the owner and amount of shares associated with a withdrawal request.
     *  @param  requestId Identifier of the withdrawal request.
     *  @return owner     Address of the share owner.
     *  @return shares    Amount of shares pending redemption.
     */
    function requests(uint256 requestId) external view returns (address owner, uint256 shares);

    /**
     *  @dev    Returns the pending requests by owner.
     *          NOTE: This function may run out of gas if there are too many requests. Use the overload with pagination.
     *  @param  owner Address of the account to check for pending requests.
     *  @return requestIds Array of request identifiers.
     *  @return shares     Array of shares associated with each request.
     */
    function requestsByOwner(address owner) external view returns (uint256[] memory requestIds, uint256[] memory shares);

    /**
     *  @dev   Returns the address of the security admin.
     *  @param securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

}
