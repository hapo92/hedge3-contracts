
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IVault {
    function buyShares(
        uint256 _investmentAmount, 
        uint256 _minSharesQuantity
    ) 
    external 
    returns (uint256 sharesReceived_);

    function buySharesOnBehalf(
        address _buyer, 
        uint256 _investmentAmount, 
        uint256 _minSharesQuantity
    ) 
    external 
    returns (uint256 sharesReceived_);

    function redeemSharesInKind(
        address _recipient,
        uint256 _sharesQuantity,
        address[] calldata _additionalAssets,
        address[] calldata _assetsToSkip
    ) 
    external returns (address[] memory, uint256[] memory);
}

/**
 * @title Hedge3Enzyme Contract
 * @dev A contract to invest in Enzyme vaults and redeem shares.
 * Implements Ownable for administrative control and ReentrancyGuard to prevent reentrancy attacks.
 */
contract Hedge3Enzyme is Ownable, ReentrancyGuard {
    /**
     * @dev Invests in an Enzyme vault using the specified denomination token.
     * @param comptrollerProxyAddress The address of the Enzyme vault's comptroller proxy.
     * @param denominationTokenAddress The address of the token used for investment.
     * @param amount The amount of tokens to invest.
     */
    function investInEnzymeVault(
        address comptrollerProxyAddress, 
        address denominationTokenAddress, 
        uint256 amount
    )
    public nonReentrant 
    {
        require(amount > 0, "Investment amount should be greater than zero");
        require(comptrollerProxyAddress != address(0), "Invalid vault address");
        require(denominationTokenAddress != address(0), "Invalid denomination token address");
        
        IERC20 denominationToken = IERC20(denominationTokenAddress);
        uint256 allowance = denominationToken.allowance(msg.sender, address(this));
        require(allowance >= amount, string(abi.encodePacked("ERC20: transfer amount exceeds allowance. Allowance is: ", Strings.toString(allowance))));
        
        // Transfer the tokens to the contract itself
        require(denominationToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        // Approve the vault to spend the tokens
        require(denominationToken.approve(comptrollerProxyAddress, amount), "Failed to approve token transfer");

        // Buy shares in the Enzyme vault on behalf of the sender
        IVault(comptrollerProxyAddress).buySharesOnBehalf(msg.sender, amount, 1);  
    }

   
    /**
     * @dev Redeems shares from an Enzyme vault in kind. Allows an investor to redeem a specified quantity of shares they hold in vault in the form of the underlying assets held by the vault.
     * @param comptrollerProxyAddress The address of the Enzyme vault's comptroller proxy.
     * @param vaultTokenAddress The address of the vault token.
     * @param sharesQuantity The quantity of shares to redeem.
     */
    function redeemFromEnzymeFundInKind(
        address comptrollerProxyAddress,
        address vaultTokenAddress,
        uint256 sharesQuantity
    ) external {
        IERC20 vaultToken = IERC20(vaultTokenAddress);
        require(vaultToken.allowance(msg.sender, address(this)) >= sharesQuantity, "ERC20: transfer amount exceeds allowance ");
        require(vaultToken.transferFrom(msg.sender, address(this), sharesQuantity), "Token transfer failed");
        require(vaultToken.approve(comptrollerProxyAddress, sharesQuantity), "Token approval failed");

        address[] memory additionalAssets = new address[](0);
        address[] memory assetsToSkip = new address[](0);

        // Redeem shares in kind from the Enzyme vault
        IVault(comptrollerProxyAddress).redeemSharesInKind(
            msg.sender,
            sharesQuantity, 
            additionalAssets, 
            assetsToSkip
        );
       
    }



}