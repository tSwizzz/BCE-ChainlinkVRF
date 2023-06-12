// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

interface IFortuneSeeker {
    function fulfillFortune(string memory _fortune) external;
}

contract FortuneTeller is VRFConsumerBaseV2, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    string[] fortunes = [
        "A beautiful, smart, and loving person will be coming into your life.",
        "A faithful friend is a strong defense.",
        "You are going to be a blockchain developer.",
        "A golden egg of opportunity falls into your lap this month.",
        "A hunch is creativity trying to tell you something.",
        "All EVM error messages are designed to build your character.",
        "A short pencil is usually better than a long memory any day.",
        "A soft voice may be awfully persuasive.",
        "All your hard work will soon pay off.",
        "Because you demand more from yourself, others respect you deeply.",
        "Better ask twice than lose yourself once.",
        "You will learn patience from Smart Contracts."
    ];

    string public lastReturnedFortune;

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    mapping(uint => RequestStatus) public s_requests;
    VRFCoordinatorV2Interface COORDINATOR; //address

    uint64 s_subscriptionId;

    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash =
        0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;

    uint32 callBackGasLimit = 100000;
    uint16 requestConfirmations = 1;

    uint32 numWords = 1;

    constructor(
        uint64 subscriptionId,
        address VRFCoordinator
    ) VRFConsumerBaseV2(VRFCoordinator) ConfirmedOwner(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(VRFCoordinator);
        s_subscriptionId = subscriptionId;
    }

    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callBackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function seekFortune() external payable {
        require(
            msg.value >= 0.001 ether,
            "insufficient payment to the fortune teller"
        );
        require(lastRequestId != 0, "no request fulfilled yet");

        string memory fortune = getFortune();
        IFortuneSeeker seeker = IFortuneSeeker(msg.sender);
        seeker.fulfillFortune(fortune);
    }

    function getFortune() public returns (string memory) {
        string memory fortune = fortunes[
            s_requests[lastRequestId].randomWords[0] % fortunes.length
        ];
        lastReturnedFortune = fortune;
        return fortune;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawBalance() public payable onlyOwner {
        (bool sent, ) = payable(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(sent, "failed to sent Ether in withdraw");
    }
}
