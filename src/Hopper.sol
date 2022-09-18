// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.15;

import {CREATE3} from "solmate/utils/CREATE3.sol";

import {AltBn128} from "./AltBn128.sol";
import {LSAG}  from "./LSAG.sol";

contract Hopper {

    event Deposited(address Depositor);
    event Withdrawal(address Receiver);
    event Hop(address NewLocation);

    bytes32 immutable depHash;

    uint8 dParticipantsNo;
    bytes32 public ringHash;
    mapping(uint8 => uint256[2]) public publicKeys;
    mapping(uint8 => uint256[2]) public keyImages;


    function _hop(
        uint256 value,
        bytes calldata deplCode
    ) internal returns (
        address newLocation
    ) {
        require(depHash == keccak256(abi.encodePacked(deplCode)), "INVALID CREATION CODE");

        newLocation = CREATE3.deploy(
            keccak256(abi.encodePacked(msg.sender, block.difficulty)), 
            abi.encodePacked(deplCode, abi.encode(0, depHash)), 
            value
        );

        emit Hop(newLocation);
    }

    // create the overloaded for 5
    function _deposit(uint256[2] memory publicKey) internal {

        if (!AltBn128.onCurve(uint256(publicKey[0]), uint256(publicKey[1]))) {
            revert("Public Key not on Curve");
        }

        unchecked{
            for (uint8 i = 0; i < dParticipantsNo; i++) {
                if (publicKeys[i][0] == publicKey[0] &&
                    publicKeys[i][1] == publicKey[1]) {
                    revert("Address already in current Ring");
                }
            }
        }

        publicKeys[dParticipantsNo] = publicKey;
        dParticipantsNo++;

        // Broadcast Event
        emit Deposited(msg.sender);

    }

    function _processWithdraw(
        address payable _recipient
    ) internal {
        // sanity checks
        require(msg.value == 0, "Message value is supposed to be zero for ETH instance");
        require(_recipient != address(0), "Cannot send to the burn address");

        (bool success, ) = _recipient.call{ value: 1 ether }("");
        require(success, "payment to _recipient did not go thru");
    }

    function deposit(uint256[2] memory publicKey) public payable {
        require(dParticipantsNo < 6, "RING FULL");
        require(dParticipantsNo != 5, "EXPECTED HOP ARGUMENTS");
        require(msg.value == 1 ether, "EXPECTED 1ETH");

        _deposit(publicKey);

    }

    function deposit(uint256[2] memory publicKey, bytes calldata deplCode) public payable returns (address newLocation) {
        require(dParticipantsNo == 5, "HOP ARGUMENTS NOT EXPECTED");
        require(msg.value == 1 ether, "EXPECTED 1ETH");

        _deposit(publicKey);
        ringHash = _createRingHash();
        newLocation = _hop(0, deplCode);

    }

    // Creates ring hash (used for signing)
    function _createRingHash() internal view
        returns (bytes32)
    {
        uint256[2][6] memory _publicKeys;

        

        bytes memory b = abi.encodePacked(
            address(this),
            _publicKeys
        );

        return keccak256(b);
    }

    function getPubKeys() public view returns (uint256[2][] memory) {
        // todo; the order of fixed/dynamic sizes feels weird here
        uint256[2][] memory _publicKeys = new uint256[2][](dParticipantsNo);
        
        unchecked{
            for (uint256 i = 0; i < dParticipantsNo; i++) {
                _publicKeys[i] = [
                    uint256(publicKeys[uint8(i)][0]),
                    uint256(publicKeys[uint8(i)][1])
                ];
            }
        }

        return _publicKeys;
    }

    function withdraw(
        address payable receiver, 
        uint256 c0, 
        uint256[2] memory keyImage, 
        uint256[] memory s
    ) public {
        require(dParticipantsNo == 6, "RING NOT COMPLETE");
        require(address(this).balance >= 1 ether, "WITHDRAWALS COMPLETED");

        // Convert public key to dynamic array
        // Based on number of people who have
        // deposited
        uint256[2][] memory _publicKeys = getPubKeys();

        // Attempts to verify ring signature
        bool signatureVerified = LSAG.verify(
            abi.encodePacked(address(this), receiver), // Convert to bytes
            c0,
            keyImage,
            s,
            _publicKeys
        );

        /*
        if (!signatureVerified) {
            revert("Invalid signature");
        }
        */

        // Checks if Key Image has been used
        // AKA No double withdraw
        uint8 withdrawalCount = uint8(6 - address(this).balance/10**18);

        unchecked{
            for (uint i = 0; i < withdrawalCount; i++) {
                if (keyImages[uint8(i)][0] == keyImage[0] &&
                    keyImages[uint8(i)][1] == keyImage[1]) {
                    revert("Signature has been used!");
                }
            }
        }

        keyImages[withdrawalCount] = keyImage;

        _processWithdraw(receiver);

        emit Withdrawal(receiver);
    }

    constructor(
        uint8 _dParticipantsNo,
        bytes32 _depHash
    ) payable {
        dParticipantsNo = _dParticipantsNo;
        depHash         = _depHash;
    }

}