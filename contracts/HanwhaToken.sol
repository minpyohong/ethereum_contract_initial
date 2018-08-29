pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "openzeppelin-solidity/contracts/ownership/rbac/RBAC.sol";

/**
 * @title HanwhaToken
 * @dev Mintable, burnable ERC20 Token
 */
contract HanwhaToken is BurnableToken, MintableToken, RBAC {
    /* States */
    string constant ROLE_SWAPPER = "swapper";

    // ERC20
    string public name = "HanwhaToken";
    string public symbol = "HWT";
    uint256 public decimals = 18;

    // Expired date for each levels
    uint256[] public expireDates;
    uint256 public numLevels;

    // Account level
    // 0: normal user
    // 1: franchisee
    mapping (address => uint256) public accountLevel;

    /* Events */
    event Expired(address _addr, uint256 _amount);

    /* Modifier */
    modifier onlyOwnerOrSwapper()
    {
      require(
        msg.sender == owner ||
        hasRole(msg.sender, ROLE_SWAPPER)
        );
      _;
    }

    modifier hasMintPermission() {
      require(
        msg.sender == owner ||
        hasRole(msg.sender, ROLE_SWAPPER)
        );
      _;
    }

    /* Constructor */
    function HanwhaToken(string _name, string _symbol, uint256 _decimals, uint256[] _expireDates) public {
      require(_expireDates.length > 0);

      name = _name;
      symbol = _symbol;
      decimals = _decimals;
      numLevels = _expireDates.length;
      expireDates = _expireDates;
    }

    /* External */
    function burnToken(address burner, uint256 amount) external onlyOwnerOrSwapper returns (bool) {
        super._burn(burner, amount);
        return true;
    }

    function setFranchisee(address _addr) external onlyOwner {
      accountLevel[_addr] = 1;
    }

    function unsetFranchisee(address _addr) external onlyOwner {
      accountLevel[_addr] = 0;
    }

    function setLevel(address _addr, uint256 _level) external onlyOwner returns (bool) {
      require(_level < numLevels);
      accountLevel[_addr] = _level;
      return true;
    }

    function addSwapperRole(address addr) onlyOwner external {
      addRole(addr, ROLE_SWAPPER);
    }

    function removeSwapperRole(address addr) onlyOwner external {
      removeRole(addr, ROLE_SWAPPER);
    }

    function setExpireDates(uint256[] _expireDates) onlyOwner external {
      require(expireDates.length == _expireDates.length);
      for (uint256 i = 0; i < _expireDates.length; i++) {
        expireDates[i] = _expireDates[i];
      }
    }

    /* Public */
    function isExpired(uint8 index) view external returns (bool) {
      require(index < expireDates.length);
      return (expireDates[index] < now);
    }

    function getExpireDates() public view returns (uint256[]) {
      return expireDates;
    }

    function burn(uint256 _value) public {
      revert();
    }

    function finishMinting() public returns (bool) {
      revert();
    }

    function levelCount() public view returns (uint) {
      return expireDates.length;
    }

    event Log(string _msg);

    /**
     * @notice check token is expired before token transfer / transferFrom / approve
     * @param _addr address to check expire
     * @return True if token is expired
     */
    function expire(address _addr) public returns (bool) {
      uint256 balance = balanceOf(_addr);

      if (balance > 0) {
        uint256 level = accountLevel[_addr];
        uint256 expireDate = expireDates[level];

        if (expireDate <= now) {
          super._burn(_addr, balance);
          emit Expired(_addr, balance);

          return true;
        }
      }

      return false;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
      if (!expire(msg.sender)) {
        return super.transfer(_to, _value);
      }
      return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
      if (!expire(_from)) {
        return super.transferFrom(_from, _to, _value);
      }

      return true;
    }


    function approve(address _spender, uint256 _value) public returns (bool) {
      if (!expire(msg.sender)) {
        return super.approve(_spender, _value);
      }

      return true;
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
      if (!expire(msg.sender)) {
        return super.increaseApproval(_spender, _addedValue);
      }

      return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
      if (!expire(msg.sender)) {
        return super.decreaseApproval(_spender, _subtractedValue);
      }

      return true;
    }
}

/**
 * @title HanwhaTokenFactory
 * @dev generate new token
 */
 contract HanwhaTokenFactory {
   /**
    * @dev Create new Hanwha token
    * @param _name Name of the new token
    * @param _symbol Token Symbol for the new token
    * @param _decimals Number of decimals of the new token
    * @param _expireDates Validity period, Settlement period
    * @return The address of the new token contract
    */
   function createHanwhaToken(
        string _name,
        string _symbol,
        uint256 _decimals,
        uint256[] _expireDates
    ) public returns (HanwhaToken) {
        HanwhaToken newToken = new HanwhaToken(
          _name,
          _symbol,
          _decimals,
          _expireDates
          );

        newToken.transferOwnership(msg.sender);
        return newToken;
    }
 }
