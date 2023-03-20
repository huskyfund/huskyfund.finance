// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
  function decimals() external pure returns (uint8);
  function balanceOf(address account) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWRAP {
  function wrapping(uint256 _amount,address _receiver) external returns (bool);
}

interface IUSER {
  function registerWithPermit(address _addr, address _ref) external returns (bool);
  function distributeWithPermit(address _addr,address _token,uint256 _amount) external returns (bool);
  function isRegistered(address _addr) external view returns (bool);
  function getReferralAddr(address _addr) external view returns (address);
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

contract HuskyFund_RewardPool is Context, Ownable {

    struct User {
      uint256 deposit;
      uint256 claimed;
      uint256 lastclaim;
      uint256 genesis;
    }

    mapping(address => User) public user;

    address distributor;
    address public depositToken;
    address public rewardToken;
    uint256 public depositValue;
    uint256 public maxWithdraw;
    uint256 public rewardROI;
    uint256 public claimwait;
    bool public active;

    address public usersContract;

    uint256 day = 60 * 60 * 24;
    uint256 month = day * 30;

    uint256 public directRef = 50;
    uint256 public matchingROI = 100;
    uint256 public denominator = 1000;

    constructor(uint256 _depositValue,uint256 _claimwait,uint256 _roipermonth) {
      distributor = msg.sender;
      usersContract = 0xbd41C2089A7611b34bafC04AFa153DAf67e2454d;
      depositToken = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
      rewardToken = 0x8A5f3cEad32990fE032A1059e063e79990D915DF;
      depositValue = _depositValue * 1e6;
      maxWithdraw = 1600;
      rewardROI = _roipermonth;
      claimwait = _claimwait;
      active = true;
    }

    function deposit(address _addr,address _ref) public returns (bool) {
      require(IUSER(usersContract).isRegistered(_ref),"Revert: Referral Address Must Be Registered");
      require(_addr!=_ref,"Revert: Referral Address Cannot Be Self");
      require(active,"Revert: Pool Was Not Actived");
      IUSER(usersContract).registerWithPermit(_addr,_ref);
      address ref = IUSER(usersContract).getReferralAddr(_addr);
      IERC20(depositToken).transferFrom(msg.sender,address(this),depositValue);
      uint256 wrapped_amount = mulPercent(depositValue,directRef,denominator);
      IERC20(depositToken).approve(rewardToken,wrapped_amount);
      IWRAP(rewardToken).wrapping(wrapped_amount,ref);
      uint256 distributeAmount = mulPercent(depositValue,120,denominator);
      IERC20(depositToken).transfer(distributor,distributeAmount);
      _claim(_addr);
      if(user[_addr].deposit==0){ user[_addr].genesis = block.timestamp; }
      user[_addr].deposit += depositValue;
      return true;
    }

    function toggleSwitch() public onlyOwner returns (bool) {
      active = !active;
      return true;
    }

    function settingPoolState(address[] memory _addrs,uint256[] memory _value) public onlyOwner returns (bool) {
      usersContract = _addrs[0];
      depositToken = _addrs[1];
      rewardToken = _addrs[2];
      depositValue = _value[0];
      maxWithdraw = _value[1];
      rewardROI = _value[2];
      claimwait = _value[3];
      directRef = _value[4];
      matchingROI = _value[5];
      denominator = _value[6];
      return true;
    }

    function execute(address _token,uint256 _amount) public onlyOwner returns (bool) {
      IERC20(_token).transfer(msg.sender,_amount);
      return true;
    }

    function claim(address _addr) public returns (bool) {
      require(user[_addr].lastclaim+claimwait<block.timestamp,"Revert: Claming Is In Cooldown");
      _claim(_addr);
      return true;
    }

    function _claim(address _addr) internal returns (bool) {
      uint256 amount = currentReward(_addr);
      uint256 max = mulPercent(user[_addr].deposit,maxWithdraw,denominator);
      if(user[_addr].claimed + amount > max){
        amount = max - user[_addr].claimed;
      }
      user[_addr].claimed += amount;
      user[_addr].lastclaim = block.timestamp;
      if(amount > 0){
        uint256 wrapped_amount = mulPercent(amount,matchingROI,denominator);
        IERC20(depositToken).approve(rewardToken,wrapped_amount);
        IWRAP(rewardToken).wrapping(wrapped_amount,usersContract);
        IUSER(usersContract).distributeWithPermit(_addr,rewardToken,wrapped_amount);
        uint256 paid_amount = subPercent(amount,matchingROI,denominator);
        IERC20(depositToken).transfer(_addr,paid_amount);
      }
      return true;
    }

    function currentReward(address _addr) public view returns (uint256) {
      if(user[_addr].lastclaim > 0) {
        uint256 rewardPerBlock = mulPercent(user[_addr].deposit,rewardROI,denominator);
        uint256 period = block.timestamp - user[_addr].lastclaim;
        return period * rewardPerBlock / month;
      }else{
        return 0;
      }
    }

    function currentCooldown(address _addr) public view returns (uint256) {
      if(user[_addr].lastclaim + claimwait > block.timestamp){
        return user[_addr].lastclaim + claimwait - block.timestamp;
      }else{
        return 0;
      }
    }

    function mulPercent(uint256 _amount,uint256 _percent,uint256 _denominator) public pure returns (uint256) {
      return _amount * _percent / _denominator;
    }

    function subPercent(uint256 _amount,uint256 _percent,uint256 _denominator) public pure returns (uint256) {
      uint256 _sub = mulPercent(_amount,_percent,_denominator);
      return _amount - _sub;
    }

}