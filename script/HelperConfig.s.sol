//SPDX License Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "forge-std/Script.sol";
contract HelperConfig is Script{
    struct NetworkConfig{
        address[] wethUSDPriceFeed;
        address[] wbtcUSDPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }
    NetworkConfig public activeNetworkConfig;
    constructor (){}
    
}