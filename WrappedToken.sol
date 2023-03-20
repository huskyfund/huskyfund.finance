// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract permission {
    mapping(address => mapping(string => bytes32)) private permit;
    function newpermit(address _addr,string memory str) internal { permit[_addr][str] = bytes32(keccak256(abi.encode(_addr,str))); }
    function clearpermit(address _addr,string memory str) internal { permit[_addr][str] = bytes32(keccak256(abi.encode("null"))); }
    function checkpermit(address _addr,string memory str) public view returns (bool) {
        if(permit[_addr][str]==bytes32(keccak256(abi.encode(_addr,str)))){ return true; }else{ return false; }
    }
}

contract HuskyFund_Wrapped_V1 is permission {

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed from, address indexed to, uint256 amount);

    string public name = "HuskyFund USD";
    string public symbol = "HFUSD";
    uint256 public decimals = 0;
    uint256 public totalSupply = 0 * (10**decimals);

    address public wrapped;
    address public owner;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public minted;
    mapping(address => uint256) public burnt;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(address _wrapped,uint256 _decimals) {
        wrapped = _wrapped;
        decimals = _decimals;
        owner = msg.sender;
        newpermit(msg.sender,"owner");
    }
    
    function balanceOf(address _addr) public view returns(uint256) { return balances[_addr]; }

    function wrapping(uint256 _amount,address _receiver) public returns (bool) {
        IERC20(wrapped).transferFrom(msg.sender,address(this),_amount);
        minted[_receiver] += _amount;
        balances[_receiver] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _receiver, _amount);
        return true;
    }

    function unwrapped(uint256 _amount,address _receiver) public returns (bool) {
        burnt[msg.sender] += _amount;
        balances[msg.sender] -= _amount;
        totalSupply -= _amount;
        IERC20(wrapped).transfer(_receiver,_amount);
        emit Transfer(msg.sender, address(0), _amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender,to,amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns(bool) {
        allowance[from][msg.sender] -= amount;
        _transfer(from,to,amount);
        return true;
    }
    
    function approve(address to, uint256 amount) public returns (bool) {
        require(to != address(0));
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }

    function implement(address _wrapped,uint256 _decimals) public returns (bool) {
        require(checkpermit(msg.sender,"owner"),"Revert: Not Allow With Permit");
        wrapped = _wrapped;
        decimals = _decimals;
        return true;
    }

    function transferOwnership(address _addr) public returns (bool) {
        require(checkpermit(msg.sender,"owner"),"Revert: Not Allow With Permit");
        owner = _addr;
        newpermit(_addr,"owner");
        clearpermit(msg.sender,"owner");   
        return true;
    }

    function _transfer(address from,address to, uint256 amount) internal {
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
    }

}