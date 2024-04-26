// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol
/**
 * @title DSC Engine
 * @author Haard Solanki
 * This contract is the engine of the Decentralized Stable Coin
 * This contract is the governance contract of the Decentralized Stable Coin
 * This System is designed to be as minimal as possible and have tokens maintain a 1$ token==$1 peg
 * This stable coin has the properties
 * 1. Exogenous Collateral
 * 2. Decentralized
 * 3. Anchored (pegged) to USD
 * 4. Algorithmically Stable
 * It is similar to DAI if DAI had no governance and was fully decentralized and backed by weth and wbtc
 * @notice this contract is the heart of the Decentralized Stable Coin. It handles all the logic for the Decentralized Stable Coin minting
 * Our System should always be Over collateral ie more collateral than DSC minted
 * and burning(redeeming)
 * @notice this contract is very loosely based upon MakerDAO's DAI stable coin system
 */

contract DSCEngine is ReentrancyGuard {
    //////////
    //Errors//
    //////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesandPriceFeedAddressesMustbeSameLength();
    error DSCEngine__TokenNotSupported();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__MintFailed(); 
    /////////////
    //State Variables
    /////////////
    uint256 private constant LIQUIDAION_THRESHOLD = 50;//200% collateralization ratio
    mapping(address token => address pricefeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        private s_userCollateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_userDscMinted;
    uint256 private constant ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    address[] private s_collateralTokens;
    uint256 private constant LIQUIDATION_PRECISION=100;
    uint256 private constant MIN_HEALTH_FACTOR=1;
    DecentralizedStableCoin private immutable i_dsc;

    /////////////
    //Events
    /////////////
    event CollateralDeposited(
        address indexed user,
        address indexed tokenCollateralAddress,
        uint256 amountCollateral
    );

    //////////
    //Modifier
    //////////

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotSupported();
        }
        _;
    }

    //////////
    //Functions
    //////////
    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesandPriceFeedAddressesMustbeSameLength();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////
    //External Functions
    /////////////
    function depositCollateralandMintDsc() external {}

    /*
     * @param tokenCollateralAddress the address of the token to be deposited as collateral
     * @param amountCollateral the amount of the token to be deposited as collateral
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
    //make this non-reentrant
    {
        s_userCollateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralforDsc() external {}

    function redeemCollateral() external {}

    /** 
    /// @param amountDscToMint the amount of DSC to mint
    /// @notice this function is used to mint DSC
    /// @notice this function is only callable by the owner of the contract
    * @notice they must have more collateral than the DSC they are minting
    **/
    function mintDsc(
        uint256 amountDscToMint
    ) external moreThanZero(amountDscToMint) nonReentrant {
        s_userDscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorBroken(msg.sender);
        bool minted=i_dsc.mint(msg.sender,amountDscToMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /////////////
    //Internal Functions
    /////////////
    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueinUSD
        ) = _getAccountInfo(user);

        //1000$ eth/100DSC
        //1000*50/100=500/100>1

        uint256 collateralAdjustedforThreshold=(collateralValueinUSD*LIQUIDAION_THRESHOLD)/LIQUIDATION_PRECISION;
        return (collateralAdjustedforThreshold * PRECISION) / totalDscMinted;
    }

    function _getAccountInfo(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueinUSD)
    {
        //get the total DSC minted by the user
        //get the total collateral value in USD
        totalDscMinted = s_userDscMinted[user];
        collateralValueinUSD = getCollateralValue(user);
    }

        //check if the health factor is broken
        //if it is revert
    function _revertIfHealthFactorBroken(address user) internal view {
        uint256 userhealthFactor = _healthFactor(user);
        if(userhealthFactor<MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor();
        }
    }

    /////////////
    //External & Public functions
    /////////////
    function getCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValue) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_userCollateralDeposited[user][token];
            totalCollateralValue += getUSDValue(token, amount);
        }
        return totalCollateralValue;
    }

    function getUSDValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        //get the total value of the collateral in USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEE_PRECISION) * amount) / PRECISION;
    }
}
