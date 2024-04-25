// SPDX-License-Identifier: MIT
// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
pragma solidity ^0.8.19;

// imports
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// interfaces, libraries, contracts
// errors

error DecentralizedStableCoin__MustbeMorethanZero();
error DecentralizedStableCoin__MustbeLessthanBalance();
error DecentralizedStableCoin__CannotMintTo0Address();
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/*
 *@title Decentralized Stable Coin
 *@author Haard Solanki
 *Collateral Exogenous
 *Minting Algorithmic
 *Pegged to USD
 *
 *This contract is governed by DSCEngine
 *This contract is ERC20 implementation of stable coin system
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustbeMorethanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__MustbeLessthanBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__CannotMintTo0Address();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustbeMorethanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
