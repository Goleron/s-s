// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.7 <0.9.0;

contract SimpleEstateAgency {

    enum PropertyType { House, Apartment, Loft }
    enum ListingStatus { Active, Sold }

    struct User {
        address addr;
        string name;
    }

    struct Property {
        uint id;
        uint size;
        address owner;
        PropertyType propertyType;
        bool isListed;
    }

    struct Listing {
        uint propertyId;
        uint price;
        ListingStatus status;
        address seller;
        address buyer;
        uint listedTime;
    }

    mapping(address => User) public users;
    Property[] public properties;
    Listing[] public listings;
    mapping(address => uint) public accountBalances;

    event UserRegistered(address user);
    event PropertyCreated(uint propertyId);
    event PropertyListed(uint propertyId, uint price);
    event PropertyStatusChanged(uint propertyId, bool isListed);
    event ListingStatusChanged(uint listingId, ListingStatus status);
    event PropertySold(uint listingId, address buyer, uint price);
    event Withdrawal(address user, uint amount);

    modifier isUserRegistered() {
        require(users[msg.sender].addr != address(0), "Polzovatel ne zaregestrirovan");
        _;
    }

    modifier isPropertyOwner(uint propertyId) {
        require(properties[propertyId].owner == msg.sender, "Ne vladelec nedvizki");
        _;
    }

    modifier isPropertyListed(uint propertyId) {
        require(properties[propertyId].isListed, "Nedvizimost nedostupna");
        _;
    }

    function registerUser(string calldata name) external {
        require(users[msg.sender].addr == address(0), "Polzovatel uze zaregestrirovan");
        users[msg.sender] = User(msg.sender, name);
        emit UserRegistered(msg.sender);
    }

    function createProperty(uint id, uint size, PropertyType propertyType) external isUserRegistered {
        properties.push(Property(id, size, msg.sender, propertyType, true));
        emit PropertyCreated(id);
    }

    function createListing(uint propertyId, uint price) external isUserRegistered isPropertyOwner(propertyId) isPropertyListed(propertyId) {
        listings.push(Listing(propertyId, price, ListingStatus.Active, msg.sender, address(0), block.timestamp));
        emit PropertyListed(propertyId, price);
    }

    function changePropertyStatus(uint propertyId, bool isListed) external isUserRegistered isPropertyOwner(propertyId) {
        Property storage property = properties[propertyId];
        property.isListed = isListed;
        if (!isListed) {
            for (uint i = 0; i < listings.length; ++i) {
                if (listings[i].propertyId == propertyId && listings[i].status == ListingStatus.Active) {
                    listings[i].status = ListingStatus.Sold;
                    emit ListingStatusChanged(i, ListingStatus.Sold);
                }
            }
        }
        emit PropertyStatusChanged(propertyId, isListed);
    }

    function changeListingStatus(uint listingId, ListingStatus status) external isUserRegistered isPropertyOwner(listings[listingId].propertyId) {
        Listing storage listing = listings[listingId];
        listing.status = status;
        emit ListingStatusChanged(listingId, status);
    }

    function buyProperty(uint listingId) external payable isUserRegistered {
        Listing storage listing = listings[listingId];
        require(msg.value >= listing.price, "Nedostatochno sredstv");
        require(listing.status == ListingStatus.Active, "Nedvizimost nedostupna");
        
        listing.buyer = msg.sender;
        listing.status = ListingStatus.Sold;
        accountBalances[listing.seller] += msg.value;
        
        Property storage property = properties[listing.propertyId];
        property.owner = msg.sender;
        property.isListed = false;
        
        emit PropertySold(listingId, msg.sender, listing.price);
    }

    function withdrawFunds(uint amount) external isUserRegistered {
        require(amount <= accountBalances[msg.sender], "Nedostatochno sredstv");
        accountBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function getUserBalance() external view isUserRegistered returns (uint) {
        return accountBalances[msg.sender];
    }

    function getAllProperties() external view returns (Property[] memory) {
        return properties;
    }

    function getAllListings() external view returns (Listing[] memory) {
        return listings;
    }
}
