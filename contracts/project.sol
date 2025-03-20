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
        uint256 releaseDate;
        uint256 streamCount;
        bool isActive;
        string genre;
    }
    
    struct Artist {
        uint256 id;
        address payable wallet;
        string name;
        string profileIpfsHash;
        bool isVerified;
        uint256 registrationDate;
        uint256[] trackIds;
        uint256 totalEarnings;
    }
    
    struct StreamRecord {
        uint256 id;
        uint256 trackId;
        address listener;
        uint256 timestamp;
        uint256 amountPaid;
    }
    
    // Mappings
    mapping(uint256 => Track) public tracks;
    mapping(uint256 => Artist) public artists;
    mapping(address => uint256) public addressToArtistId;
    mapping(uint256 => StreamRecord) public streamRecords;
    mapping(address => uint256[]) public listenerHistory;
    
    uint256 public streamRecordCount;
    
    // Events
    event ArtistRegistered(uint256 indexed artistId, address indexed artistAddress, string name);
    event TrackUploaded(uint256 indexed trackId, string title, address indexed artist, uint256 price);
    event TrackStreamed(uint256 indexed trackId, address indexed listener, uint256 amount);
    event RoyaltyPaid(address indexed artist, uint256 amount, uint256 indexed trackId);
    event ArtistVerified(uint256 indexed artistId);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyArtist() {
        require(addressToArtistId[msg.sender] != 0, "Only registered artists can call this function");
        _;
    }
    
    modifier trackExists(uint256 _trackId) {
        require(_trackId > 0 && _trackId <= totalTracks, "Track does not exist");
        _;
    }
    
    modifier onlyTrackOwner(uint256 _trackId) {
        require(tracks[_trackId].artist == msg.sender, "Only track owner can call this function");
        _;
    }
    
    /**
     * @dev Initialize the contract with owner address and platform fee
     */
    constructor() {
        owner = msg.sender;
        platformFeePercent = 10; // Default 10%
        totalTracks = 0;
        totalArtists = 0;
        streamRecordCount = 0;
    }
    
    /**
     * @dev Change platform fee percentage
     * @param _newFeePercent New fee percentage (0-30)
     */
    function setPlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 30, "Fee cannot exceed 30%");
        platformFeePercent = _newFeePercent;
    }
    
    /**
     * @dev Register as an artist on the platform
     * @param _name Artist name
     * @param _profileIpfsHash IPFS hash of artist profile image
     */
    function registerArtist(string memory _name, string memory _profileIpfsHash) external {
        require(addressToArtistId[msg.sender] == 0, "Artist already registered");
        
        totalArtists++;
        uint256 artistId = totalArtists;
        
        uint256[] memory emptyArray = new uint256[](0);
        
        artists[artistId] = Artist({
            id: artistId,
            wallet: payable(msg.sender),
            name: _name,
            profileIpfsHash: _profileIpfsHash,
            isVerified: false,
            registrationDate: block.timestamp,
            trackIds: emptyArray,
            totalEarnings: 0
        });
        
        addressToArtistId[msg.sender] = artistId;
        
        emit ArtistRegistered(artistId, msg.sender, _name);
    }
    
    /**
     * @dev Upload a new track to the platform
     * @param _title Track title
     * @param _ipfsHash IPFS hash of audio file
     * @param _metadataHash IPFS hash of track metadata
     * @param _price Price per stream in wei
     * @param _genre Music genre
     */
    function uploadTrack(
        string memory _title,
        string memory _ipfsHash,
        string memory _metadataHash,
        uint256 _price,
        string memory _genre
    ) external onlyArtist {
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        totalTracks++;
        uint256 trackId = totalTracks;
        
        tracks[trackId] = Track({
            id: trackId,
            title: _title,
            ipfsHash: _ipfsHash,
            metadataHash: _metadataHash,
            price: _price,
            artist: payable(msg.sender),
            releaseDate: block.timestamp,
            streamCount: 0,
            isActive: true,
            genre: _genre
        });
        
        // Add track to artist's collection
        uint256 artistId = addressToArtistId[msg.sender];
        artists[artistId].trackIds.push(trackId);
        
        emit TrackUploaded(trackId, _title, msg.sender, _price);
    }
    
    /**
     * @dev Stream a track and pay royalties to artist
     * @param _trackId ID of track to stream
     */
    function streamTrack(uint256 _trackId) external payable trackExists(_trackId) {
        Track storage track = tracks[_trackId];
        require(track.isActive, "Track is not available for streaming");
        require(msg.value >= track.price, "Insufficient payment for streaming");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformFeePercent) / 100;
        uint256 artistRoyalty = msg.value - platformFee;
        
        // Update track and artist statistics
        track.streamCount++;
        
        uint256 artistId = addressToArtistId[track.artist];
        artists[artistId].totalEarnings += artistRoyalty;
        
        // Record stream history
        streamRecordCount++;
        streamRecords[streamRecordCount] = StreamRecord({
            id: streamRecordCount,
            trackId: _trackId,
            listener: msg.sender,
            timestamp: block.timestamp,
            amountPaid: msg.value
        });
        
        // Add to listener history
        listenerHistory[msg.sender].push(_trackId);
        
        // Pay royalties directly to artist
        (bool success, ) = track.artist.call{value: artistRoyalty}("");
        require(success, "Payment to artist failed");
        
        emit TrackStreamed(_trackId, msg.sender, msg.value);
        emit RoyaltyPaid(track.artist, artistRoyalty, _trackId);
    }
    
    /**
     * @dev Toggle track availability
     * @param _trackId ID of track to update
     * @param _isActive New active status
     */
    function setTrackActive(uint256 _trackId, bool _isActive) external trackExists(_trackId) onlyTrackOwner(_trackId) {
        tracks[_trackId].isActive = _isActive;
    }
    
    /**
     * @dev Update track price
     * @param _trackId ID of track to update
     * @param _newPrice New price in wei
     */
    function updateTrackPrice(uint256 _trackId, uint256 _newPrice) external trackExists(_trackId) onlyTrackOwner(_trackId) {
        tracks[_trackId].price = _newPrice;
    }
    
    /**
     * @dev Verify an artist (platform owner only)
     * @param _artistId ID of artist to verify
     */
    function verifyArtist(uint256 _artistId) external onlyOwner {
        require(_artistId > 0 && _artistId <= totalArtists, "Artist does not exist");
        artists[_artistId].isVerified = true;
        emit ArtistVerified(_artistId);
    }
    
    /**
     * @dev Withdraw platform fees (owner only)
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Get all tracks by an artist
     * @param _artistId ID of artist
     * @return Array of track IDs
     */
    function getArtistTracks(uint256 _artistId) external view returns (uint256[] memory) {
        require(_artistId > 0 && _artistId <= totalArtists, "Artist does not exist");
        return artists[_artistId].trackIds;
    }
    
    /**
     * @dev Get listener's streaming history
     * @param _listener Address of listener
     * @return Array of track IDs
     */
    function getListenerHistory(address _listener) external view returns (uint256[] memory) {
        return listenerHistory[_listener];
    }
    
    /**
     * @dev Get tracks by genre
     * @param _genre Genre to search for
     * @param _limit Maximum number of results
     * @return Array of track IDs
     */
    function getTracksByGenre(string memory _genre, uint256 _limit) external view returns (uint256[] memory) {
        uint256 count = 0;
        uint256 resultCount = 0;
        
        // Count matching tracks
        for (uint256 i = 1; i <= totalTracks && count < _limit; i++) {
            if (keccak256(bytes(tracks[i].genre)) == keccak256(bytes(_genre)) && tracks[i].isActive) {
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        
        // Fill result array
        for (uint256 i = 1; i <= totalTracks && resultCount < count; i++) {
            if (keccak256(bytes(tracks[i].genre)) == keccak256(bytes(_genre)) && tracks[i].isActive) {
                result[resultCount] = i;
                resultCount++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get most streamed tracks
     * @param _limit Maximum number of results
     * @return Array of track IDs
     */
    function getTopTracks(uint256 _limit) external view returns (uint256[] memory) {
        uint256 resultCount = _limit > totalTracks ? totalTracks : _limit;
        uint256[] memory result = new uint256[](resultCount);
        uint256[] memory streamCounts = new uint256[](resultCount);
        
        // Initialize with first tracks
        for (uint256 i = 0; i < resultCount; i++) {
            if (i < totalTracks) {
                result[i] = i + 1;
                streamCounts[i] = tracks[i + 1].streamCount;
            }
        }
        
        // Sort to find top tracks (simple insertion sort)
        for (uint256 i = resultCount + 1; i <= totalTracks; i++) {
            uint256 currentStreamCount = tracks[i].streamCount;
            
            // Check if this track has more streams than any in our current top list
            for (uint256 j = 0; j < resultCount; j++) {
                if (currentStreamCount > streamCounts[j]) {
                    // Shift everything down to make room
                    for (uint256 k = resultCount - 1; k > j; k--) {
                        result[k] = result[k - 1];
                        streamCounts[k] = streamCounts[k - 1];
                    }
                    
                    // Insert this track
                    result[j] = i;
                    streamCounts[j] = currentStreamCount;
                    break;
                }
            }
        }
        
        return result;
    }
    
  
    function getTrackDetails(uint256 _trackId) external view trackExists(_trackId) returns (
        string memory title,
        string memory ipfsHash,
        string memory metadataHash,
        uint256 price,
        address artist,
        uint256 releaseDate,
        uint256 streamCount,
        bool isActive,
        string memory genre
    ) {
        Track memory track = tracks[_trackId];
        
        return (
            track.title,
            track.ipfsHash,
            track.metadataHash,
            track.price,
            track.artist,
            track.releaseDate,
            track.streamCount,
            track.isActive,
            track.genre
        );
    }
}
