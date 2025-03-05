// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 引入OpenZeppelin的ERC20合约
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 继承OpenZeppelin的ERC20合约
contract MoToken is ERC20 {
    // 构造函数，设置代币名称、符号和初始供应量
    constructor(uint256 initialSupply) ERC20("MoVerse Token", "MO") {
        // 初始供应量，单位是wei（18位小数）
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}