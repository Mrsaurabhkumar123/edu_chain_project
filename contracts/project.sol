// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DecentralizedMusicStreaming
 * @dev A smart contract for a decentralized music streaming platform with instant royalty payments
 */
contract DecentralizedMusicStreaming {
    address public owner;
    uint256 public platformFeePercent;
    uint256 public totalTracks;
    uint256 public totalArtists;
    
    struct Track {
        uint256 id;
        string title;
        string ipfsHash;
        string metadataHash;
        uint256 price;
        address payable artist;
