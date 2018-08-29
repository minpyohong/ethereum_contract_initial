pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract RegisterAsset is Ownable {

    struct Asset {
    /*
     * to save date , we can use this format :  yyyymmdd e.g)20180604
     */
        bytes32 assetId;   // unique key
       // uint8  reqDate;
        bytes32 assetName;
       // string register;
        //uint32 dealPrice;
        uint32 appraisalPrice;
        //string appraisaler; 
        //uint8  appraisalDate;
        //bool isValid;
        bool isToken;
    }

    Asset public asset;
    address public owner;
    
    mapping (bytes32 => Asset) public assetmapping;
    
    // 동일한 asset인지 여부를 판단하는 logic은 app에서 확인 필요.
    function setRegisterAsset( bytes32 assetId, bytes32 assetName, uint32 appraisalPrice) public {
        require(assetId != "");
        asset = Asset(assetId, assetName, appraisalPrice, false);
        assetmapping[assetId] = asset;
    } 

    function getAsset(bytes32 assetId) external view returns(bytes32, uint32, bool) {
        require(assetmapping[assetId].assetId != "");
        return (assetmapping[assetId].assetName, assetmapping[assetId].appraisalPrice, assetmapping[assetId].isToken);
        //return assetmapping[assetId];
    } 

    function setAssetTokenization(bytes32 assetId) public {
        require(assetmapping[assetId].assetId != "");
        assetmapping[assetId].isToken = true;
        //return assetmapping[assetId];
    } 

}
