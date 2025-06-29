// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleWithdrawalManagerStorage } from "./IMapleWithdrawalManagerStorage.sol";

// TODO: naming of two functions with requests()
// TODO: Add disclaimer about running out of gas on requests() without pagination
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
    event RequestCreated(uint128 indexed requestId, address indexed owner, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is updated.
     *  @param requestId Identifier of the withdrawal request.
     *  @param shares    Amount of shares reduced during a redemption request.
     */
    event RequestDecreased(uint128 indexed requestId, uint256 shares);

    /**
     *  @dev   Emitted when a withdrawal request is processed.
     *  @param requestId Identifier of the withdrawal request.
     *  @param owner     The owner of the shares.
     *  @param shares    Amount of redeemable shares.
     *  @param assets    Amount of withdrawable assets.
     */
    event RequestProcessed(uint128 indexed requestId, address indexed owner, uint256 shares, uint256 assets);

    /**
     *  @dev   Emitted when a withdrawal request is removed.
     *  @param requestId Identifier of the withdrawal request.
     */
    event RequestRemoved(uint128 indexed requestId);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Add shares to the withdrawal manager.
     *  @param shares Amount of shares to add.
     *  @param owner  Address of the owner of shares.
     */
    function addShares(uint256 shares, address owner) external returns (uint128 lastRequestId);

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
     *  @dev   Removes withdrawal requests from the queue.
     *         Can only be called by the pool delegate.
     *  @param owner      Address of the owner of shares.
     *  @param requestIds Array of identifiers of the withdrawal requests to remove.
     */
    function removeRequest(address owner, uint128[] calldata requestIds) external;

    /**
     *  @dev   Defines if an account will withdraw shares manually or automatically.
     *  @param account  Address of the account.
     *  @param isManual `true` if the account withdraws manually, `false` if the withdrawals are performed automatically.
     */
    function setManualWithdrawal(address account, bool isManual) external;


    /**
     *  @dev    Updates the total amount of shares pending redemption.
     *          1. If newSharesTotal is zero then the request will be removed.
     *          2. If newSharesTotal is less than the current shares then the request will be decreased.
     *          3. If newSharesTotal is greater than the current shares then the current request will be cancelled
     *             and a new request will be created at the end of the queue.
     *  @param  requestId        Identifier of the withdrawal request that is being updated.
     *  @param  newSharesTotal   New total amount of shares pending redemption.
     *  @return currentRequestId Identifier of the withdrawal request that was updated or created.
     */
    function updateShares(uint128 requestId, uint256 newSharesTotal) external returns (uint128 currentRequestId);

    /**
     *  @dev    Updates the total amount of shares pending redemption in batch.
     *  @param  requestIds        Array of identifiers of the withdrawal requests that are being updated.
     *  @param  newSharesTotals   Array of new total amounts of shares pending redemption.
     *  @return currentRequestIds Array of identifiers of the withdrawal requests that were updated or created.
     */
    function updateSharesBatch(
        uint128[] calldata requestIds,
        uint256[] calldata newSharesTotals
    ) external returns (uint128[] memory currentRequestIds);

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
     *  @dev    Returns the owner and amount of shares associated with a withdrawal request.
     *  @param  requestId Identifier of the withdrawal request.
     *  @return owner     Address of the share owner.
     *  @return shares    Amount of shares pending redemption.
     */
    function requests(uint128 requestId) external view returns (address owner, uint256 shares);

    /**
     *  @dev    Returns the pending requests by owner.
     *  @param  owner Address of the account to check for pending requests.
     *  @return requestIds Array of request identifiers.
     *  @return shares     Array of shares associated with each request.
     */
    function requests(address owner) external view returns (uint128[] memory requestIds, uint256[] memory shares);

    /**
     *  @dev    Returns the pending requests by owner and request ID range.
     *          Only returns requests that belong to the specified owner.
     *  @param  owner          Address of the account to check for pending requests.
     *  @param  firstRequestId First request ID to include in the result.
     *  @param  lastRequestId  Last request ID to include in the result.
     *  @return requestIds     Array of request identifiers.
     *  @return shares         Array of shares associated with each request.
     */
    function requests(address owner, uint128 firstRequestId, uint128 lastRequestId)
        external view returns (
            uint128[] memory requestIds,
            uint256[] memory shares
        );

    /**
     *  @dev   Returns the address of the security admin.
     *  @param securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

}
