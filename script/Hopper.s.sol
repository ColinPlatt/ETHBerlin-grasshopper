// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hopper.sol";

contract HopperScript is Script {
    bytes deplCode;
    bytes32 depHash;
    
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        deplCode = type(Hopper).creationCode;
        depHash = keccak256(deplCode);
        new Hopper(uint8(0), depHash);

        vm.stopBroadcast();
    }
}

//forge script script/Hopper.s.sol:HopperScript --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv

//forge verify-contract --chain goerli 0x784267675a016f00e032f8112a2779282b506e70 src/Hopper.sol --watch

