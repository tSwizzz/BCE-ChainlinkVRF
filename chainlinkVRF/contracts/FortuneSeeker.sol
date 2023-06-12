// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// AutomationCompatible.sol imports the functions from both ./AutomationBase.sol and
// ./interfaces/AutomationCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

interface IFortuneTeller {
    function seekFortune() external payable;
}

contract FortuneSeeker is AutomationCompatibleInterface {
    event InsufficientFunds(uint256 balance);
    event ReceivedFunding(uint256 amount);

    address public owner;

    address public fortuneTeller;

    string public fortune;

    uint256 public immutable interval;
    uint256 public lastTimeStamp;

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not owner");
        _;
    }

    constructor(address _fortuneTeller, uint256 updateInterval) {
        fortuneTeller = _fortuneTeller;
        lastTimeStamp = block.timestamp;
        interval = updateInterval;
        owner = msg.sender;
    }

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        bool intervalExceeded = (block.timestamp - lastTimeStamp) > interval;
        bool sufficientBalance = address(this).balance >= 1 ether;
        upkeepNeeded = intervalExceeded && sufficientBalance;
    }

    function performUpkeep(bytes calldata) external override {
        bool intervalExceeded = (block.timestamp - lastTimeStamp) > interval;
        bool sufficientBalance = address(this).balance >= 1 ether;
        bool upKeepNeeded = intervalExceeded && sufficientBalance;
        require(upKeepNeeded, "Upkeep conditions are not met");

        lastTimeStamp = block.timestamp;
        seekFortune();
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawBalance() public payable onlyOwner {
        (bool sent, ) = payable(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(sent, "failed to send Ether in withdraw");
    }

    function seekFortune() public {
        if (address(this).balance < 1 ether) {
            emit InsufficientFunds(address(this).balance);
            revert("Not enough balance to call fortune teller");
        }

        IFortuneTeller teller = IFortuneTeller(fortuneTeller);
        teller.seekFortune{value: 0.001 ether}(); //sends ether to seekFortune()
    }

    function fulfillFortune(string memory _fortune) external {
        fortune = _fortune;
    }

    receive() external payable {
        emit ReceivedFunding(msg.value);
    }
}
