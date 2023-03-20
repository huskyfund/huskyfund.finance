// SPDX-License-Identifier: MIT

/* HuskyFund.Finance */

pragma solidity 0.8.19;

interface IERC20 {
  function decimals() external pure returns (uint8);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
      return msg.sender;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;

    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);

    constructor() {
      address msgSender = _msgSender();
      _owner = msgSender;
      emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
      return _owner;
    }

    modifier onlyOwner() {
      require( _owner == _msgSender());
      _;
    }

    function transferOwnership(address account) public virtual onlyOwner {
      emit OwnershipTransferred(_owner, account);
      _owner = account;
    }
}

contract HuskyFund_Users_V1 is Context, Ownable {
    struct user {
      bool registered;
      address ref;
      address[] directpartner;
    }

    uint256 public participants;
    mapping(address => user) public users;

    mapping(address => uint256) public address2id;
    mapping(uint256 => address) public id2address;

    mapping(address => bool) public permission;

    modifier onlyPermission() {
      require(permission[msg.sender], "revert: have no permit");
      _;
    }

    constructor() {
      _register(msg.sender, address(this));
    }

    function flagePermission(address _addr, bool _flag) public onlyOwner returns (bool) {
      permission[_addr] = _flag;
      return true;
    }

    function registerWithPermit(address _addr, address _ref) public onlyPermission returns (bool) {
      _register(_addr, _ref);
      return true;
    }

    function distributeWithPermit(address _addr,address _token,uint256 _amount) public onlyPermission returns (bool) {
      IERC20 token = IERC20(_token);
      uint256 spender = _amount / 20;
      address[] memory receivers = new address[](20);
      uint256 i;
      do{
        receivers[i] = _safuAddress(users[_addr].ref);
        token.transfer(receivers[i],spender);
        _addr = receivers[i];
        i++;
      }while(i<20);
      return true;
    }

    function isRegistered(address _addr) public view returns (bool) {
      return users[_addr].registered;
    }

    function getReferralAddr(address _addr) public view returns (address) {
      return users[_addr].ref;
    }

    function getDirectPartner(address _addr) public view returns (address[] memory) {
      return users[_addr].directpartner;
    }

    function getReferralAddrs(address _addr) public view returns (address[] memory) {
      address[] memory result = new address[](20);
      uint256 i;
      do{
        result[i] = _safuAddress(users[_addr].ref);
        _addr = result[i];
        i++;
      }while(i<20);
      return result;
    }

    function _register(address _addr, address _ref) internal {
      if (!users[_addr].registered) {
        participants += 1;
        id2address[participants] = _addr;
        address2id[_addr] = participants;
        users[_addr].ref = _ref;
        users[_addr].registered = true;
        users[_ref].directpartner.push(_addr);
      }
    }

    function _safuAddress(address _addr) internal view returns (address) {
      if(_addr==address(0)){ return address(this); }else{ return _addr; }
    }

    function execute(address _token,uint256 _amount) public onlyOwner returns (bool) {
      IERC20(_token).transfer(msg.sender,_amount);
      return true;
    }
}