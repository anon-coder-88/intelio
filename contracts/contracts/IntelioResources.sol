// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Application identities and native ETH budgets for AI/tool usage.
contract IntelioResources is ReentrancyGuard {
    struct Application { address owner; string metadataURI; uint256 balance; }
    uint256 public nextAppId = 1;
    mapping(uint256 => Application) public applications;
    mapping(uint256 => mapping(address => uint256)) public operatorAllowance;
    mapping(uint256 => mapping(address => bool)) public approvedRecipient;

    error UnknownApplication();
    error Unauthorized();
    error InvalidInput();
    error InsufficientResources();
    error TransferFailed();

    event ApplicationCreated(uint256 indexed appId, address indexed owner, string metadataURI);
    event Deposited(uint256 indexed appId, address indexed funder, uint256 amount);
    event OperatorConfigured(uint256 indexed appId, address indexed operator, uint256 allowance);
    event RecipientConfigured(uint256 indexed appId, address indexed recipient, bool approved);
    event UsagePaid(uint256 indexed appId, address indexed operator, address indexed recipient, uint256 amount, bytes32 receiptHash);
    event Withdrawn(uint256 indexed appId, address indexed owner, uint256 amount);

    modifier onlyAppOwner(uint256 appId) {
        _requireApp(appId);
        if (applications[appId].owner != msg.sender) revert Unauthorized();
        _;
    }

    function createApplication(string calldata metadataURI) external returns (uint256 appId) {
        if (bytes(metadataURI).length == 0 || bytes(metadataURI).length > 512) revert InvalidInput();
        appId = nextAppId++;
        applications[appId] = Application(msg.sender, metadataURI, 0);
        emit ApplicationCreated(appId, msg.sender, metadataURI);
    }

    // Anyone may sponsor an existing application; balances stay isolated.
    function deposit(uint256 appId) external payable {
        _requireApp(appId);
        if (msg.value == 0) revert InvalidInput();
        applications[appId].balance += msg.value;
        emit Deposited(appId, msg.sender, msg.value);
    }

    // Allowance is a remaining ETH budget, not a recurring daily limit.
    function setOperator(uint256 appId, address operator, uint256 allowance) external onlyAppOwner(appId) {
        if (operator == address(0)) revert InvalidInput();
        operatorAllowance[appId][operator] = allowance;
        emit OperatorConfigured(appId, operator, allowance);
    }

    function setRecipient(uint256 appId, address recipient, bool approved) external onlyAppOwner(appId) {
        if (recipient == address(0) || recipient == address(this)) revert InvalidInput();
        approvedRecipient[appId][recipient] = approved;
        emit RecipientConfigured(appId, recipient, approved);
    }

    // A receipt is a reference hash; it does not prove an AI service executed.
    function payUsage(uint256 appId, address payable recipient, uint256 amount, bytes32 receiptHash) external nonReentrant {
        _requireApp(appId);
        if (amount == 0 || receiptHash == bytes32(0)) revert InvalidInput();
        if (!approvedRecipient[appId][recipient]) revert Unauthorized();
        uint256 allowance = operatorAllowance[appId][msg.sender];
        if (amount > allowance) revert Unauthorized();
        if (amount > applications[appId].balance) revert InsufficientResources();
        // Update accounting before calling the recipient.
        operatorAllowance[appId][msg.sender] = allowance - amount;
        applications[appId].balance -= amount;
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit UsagePaid(appId, msg.sender, recipient, amount, receiptHash);
    }

    function withdraw(uint256 appId, uint256 amount) external onlyAppOwner(appId) nonReentrant {
        if (amount == 0) revert InvalidInput();
        if (amount > applications[appId].balance) revert InsufficientResources();
        applications[appId].balance -= amount;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Withdrawn(appId, msg.sender, amount);
    }

    function _requireApp(uint256 appId) private view {
        if (applications[appId].owner == address(0)) revert UnknownApplication();
    }
}
