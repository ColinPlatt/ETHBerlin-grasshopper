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
        (out[0], out[1]) = abi.decode(res, (uint256, uint256));
    }


    function getPK(address targetAddress) public returns (uint256 randSK, uint256 stealthSK, uint256[2] memory out) {
        string[] memory inputs = new string[](4);
        inputs[0] = 'node';
        inputs[1] = 'script/cryptoPK.js';
        inputs[2] = 'haveCake';
        inputs[3] = vm.toString(targetAddress);

        bytes memory res = vm.ffi(inputs);


        (,randSK,stealthSK,out) = abi.decode(res, (address, uint256, uint256, uint256[2]));
        emit log_named_address("target address", targetAddress);
        emit log_named_uint("randSK", randSK);
        emit log_named_uint("stealthSK", stealthSK);
        emit log_named_uint("out[0]", out[0]);
        emit log_named_uint("out[1]", out[1]);

    }

    function signPK(uint256 randSK, address targetAddress, bytes32 ringHash, bytes memory pubKeys) public returns (uint256 c0, uint256[2] memory keyImage, uint256[] memory s) {
        //eatCake(randomSk, targetAddress, ringHash, ringPublicKeys)

        emit log_string("withdrawal attempt");
        emit log_named_address("target address", targetAddress);
        emit log_named_uint("randSK", randSK);
        emit log_named_bytes32("ringHash", ringHash);
        emit log_named_bytes("encoded pubKeys", pubKeys);
        
        string[] memory inputs = new string[](7);
        inputs[0] = 'node';
        inputs[1] = 'script/cryptoPK.js';
        inputs[2] = 'eatCake';
        inputs[3] = vm.toString(randSK);
        inputs[4] = vm.toString(targetAddress);
        inputs[5] = vm.toString(ringHash);
        inputs[6] = vm.toString(pubKeys);

        bytes memory res = vm.ffi(inputs);
        //[targetAddress, c0, keyImage, s];
        (,c0,keyImage,s) = abi.decode(res, (address, uint256, uint256[2], uint256[]));

    }

    function doDeployment() public logs_gas {
        ring = new Hopper(uint8(0), depHash);
    }

    function testDeposit() public {

        vm.deal(msg.sender, 100 ether);

        (,,uint256[2] memory dummypublicKey) = getPK(msg.sender);
        
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
            (,,dummypublicKeys[i]) = getPK(address(uint160(i+1)));
            ring.deposit{value: 1 ether}(dummypublicKeys[i]);
        }      

        assertEq(address(ring).balance, 5 ether);

        (,,dummypublicKeys[5]) = getPK(address(6));
        address newRing = doHopDeposit(dummypublicKeys[5]);

        assertEq(address(ring).balance, 0 ether);
        assertEq(address(newRing).balance, 6 ether);

        
    }

    function testWithdraw() public {

        vm.deal(msg.sender, 100 ether);

        uint256[2][10] memory dummypublicKeys;
        uint256[10] memory randomSKs;
        uint256[10] memory stealthSKs;
        
        for(uint256 i = 0; i<5; i++){
            (randomSKs[i],stealthSKs[i],dummypublicKeys[i]) = getPK(address(uint160(i+1)));
            ring.deposit{value: 1 ether}(dummypublicKeys[i]);
        }      

        (randomSKs[5],stealthSKs[5],dummypublicKeys[5]) = getPK(address(6));
        address newRing = doHopDeposit(dummypublicKeys[5]);

        uint256[2][] memory pubKeys = ring.getPubKeys();



        bytes memory pubKeysBytes = abi.encode(pubKeys);

        emit log_named_uint("stealth_check", stealthSKs[4]);

        //uint256 randSK, address targetAddress, bytes32 ringHash, bytes memory pubKeys
        (uint256 c0, uint256[2] memory keyImage, uint256[] memory s) = signPK(randomSKs[4], address(uint160(5)), ring.ringHash(), pubKeysBytes);

        

        Hopper(newRing).withdraw(
            payable(address(uint160(5))),
            c0, 
            keyImage, 
            s
        );

        assertEq(address(10).balance, 1 ether);


        
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