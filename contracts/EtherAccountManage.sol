pragma solidity ^0.4.23;

contract EtherAccountManage {

    function() payable {}

    function getEtherAccount(address _addr) external view returns( uint256 ) {
          return _addr.balance;
    }  
    
    function transferEther(address _to, uint256 value) public {
        //require(msg.sender == _from);
        //require(_from.balance >= value);
        _to.transfer(value);
    }

    function sendEtherTo(address addr , uint256 value) public {
       // require(addr != 0x0);
        addr.send(value);
    }

    function callEtherTo(address addr , uint256 value) public {
       // require(addr != 0x0);
        addr.call.value(value).gas(10000000);
    }
}
