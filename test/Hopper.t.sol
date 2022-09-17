// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Hopper} from "src/Hopper.sol";

contract HopperTest is Test {

    Hopper ring;
    bytes deplCode;
    bytes32 depHash;

    function setUp() public {
        deplCode = type(Hopper).creationCode;
        depHash = keccak256(deplCode);
        doDeployment();

        emit log_uint(deplCode.length);
    }

    function getPK() public returns (uint256[2] memory out) {
        string[] memory inputs = new string[](2);
        inputs[0] = 'node';
        inputs[1] = 'script/generatePK.js';

        bytes memory res = vm.ffi(inputs);
        (uint256 raw1, uint256 raw2) = abi.decode(res, (uint256, uint256));

        out[0] = uint256(raw1);
        out[1] = uint256(raw2);
    }

    function doDeployment() public logs_gas {
        ring = new Hopper(uint8(0), depHash);
    }

    function testDeposit() public {

        vm.deal(msg.sender, 100 ether);

        uint256[2] memory dummypublicKey = getPK();
        
        ring.deposit{value: 1 ether}(dummypublicKey);

        assertEq(address(ring).balance, 1 ether);
        
    }

    function doHopDeposit(uint256[2] memory pk) public logs_gas returns (address newLoc) {
        newLoc = ring.deposit{value: 1 ether}(pk, deplCode);
    }

    function testMultiDeposit() public {

        vm.deal(msg.sender, 100 ether);

        uint256[2][10] memory dummypublicKeys;
        
        for(uint256 i = 0; i<5; i++){
            dummypublicKeys[i] = getPK();
            ring.deposit{value: 1 ether}(dummypublicKeys[i]);
        }      

        assertEq(address(ring).balance, 5 ether);

        dummypublicKeys[5] = getPK();
        address newRing = doHopDeposit(dummypublicKeys[5]);

        assertEq(address(ring).balance, 0 ether);
        assertEq(address(newRing).balance, 6 ether);

        
    }

    function testFailDeposit() public {

        vm.deal(msg.sender, 100 ether);

        uint256[2] memory dummypublicKey;
        
        dummypublicKey[0] = uint256(bytes32(hex'1b9cb2fc90f228217cfa82dd1dcacba8bcadb442c09b7ac74465a35efc2717a2'));
        dummypublicKey[1] = uint256(bytes32(hex'27a2a66e6d01578cb59e747bc8d61e2bc9463eaa0cd79d850ee143fd6e3324c0'));

        ring.deposit{value: 1 ether}(dummypublicKey);

        assertEq(address(ring).balance, 1 ether);

        ring.deposit{value: 1 ether}(dummypublicKey);

        assertEq(address(ring).balance, 1 ether);
        
    }


}