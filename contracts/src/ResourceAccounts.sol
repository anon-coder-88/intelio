// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice ETH operating accounts with owner-defined service authority and spending limits.
/// @dev Charges settle funds; a request ID is not proof of offchain service delivery.
contract ResourceAccounts is ReentrancyGuard {
    struct Policy {
        uint256 requestLimit;
        uint256 dailyLimit;
        uint256 lifetimeLimit;
    }

    struct Application {
        address owner;
        string metadataURI;
        uint256 balance;
        uint256 lifetimeSpent;
        uint256 dailySpent;
        uint256 day;
        Policy policy;
        bool paused;
        bool closed;
    }

    struct Service {
        address operator;
        address payable recipient;
        bool enabled;
    }

    uint256 public nextAppId = 1;
    uint256 public totalLiabilities;
    mapping(uint256 => Application) private _applications;
    mapping(uint256 => mapping(bytes32 => Service)) public services;
    mapping(uint256 => mapping(bytes32 => bool)) public paidRequests;

    error UnknownApplication();
    error Unauthorized();
    error InvalidInput();
    error InvalidPolicy();
    error AccountPaused();
    error AccountClosed();
    error ServiceDisabled();
    error RequestAlreadyPaid();
    error RequestLimitExceeded();
    error DailyLimitExceeded();
    error LifetimeLimitExceeded();
    error InsufficientBalance();
    error TransferFailed();
    error BalanceNotEmpty();

    event ApplicationCreated(uint256 indexed appId, address indexed owner, string metadataURI);
    event MetadataUpdated(uint256 indexed appId, string metadataURI);
    event PolicyUpdated(
        uint256 indexed appId, uint256 requestLimit, uint256 dailyLimit, uint256 lifetimeLimit
    );
    event ServiceConfigured(
        uint256 indexed appId, bytes32 indexed serviceId, address operator, address recipient, bool enabled
    );
    event Funded(uint256 indexed appId, address indexed sponsor, uint256 amount);
    event UsagePaid(
        uint256 indexed appId,
        bytes32 indexed serviceId,
        bytes32 indexed requestId,
        address operator,
        address recipient,
        uint256 amount
    );
    event Withdrawn(uint256 indexed appId, address indexed recipient, uint256 amount);
    event PauseChanged(uint256 indexed appId, bool paused);
    event ApplicationClosed(uint256 indexed appId);

    modifier onlyOwner(uint256 appId) {
        Application storage app = _requireApplication(appId);
        if (msg.sender != app.owner) revert Unauthorized();
        if (app.closed) revert AccountClosed();
        _;
    }

    function createApplication(string calldata metadataURI, Policy calldata policy)
        external
        nonReentrant
        returns (uint256 appId)
    {
        _validateMetadata(metadataURI);
        _validatePolicy(policy);
        appId = nextAppId++;
        Application storage app = _applications[appId];
        app.owner = msg.sender;
        app.metadataURI = metadataURI;
        app.policy = policy;
        app.day = block.timestamp / 1 days;
        emit ApplicationCreated(appId, msg.sender, metadataURI);
        emit PolicyUpdated(appId, policy.requestLimit, policy.dailyLimit, policy.lifetimeLimit);
    }

    function application(uint256 appId) external view returns (Application memory) {
        return _requireApplication(appId);
    }

    /// @notice Policy updates never reset usage; limits may temporarily be below today's spend.
    function setPolicy(uint256 appId, Policy calldata policy) external onlyOwner(appId) nonReentrant {
        _validatePolicy(policy);
        Application storage app = _applications[appId];
        if (policy.lifetimeLimit < app.lifetimeSpent) revert InvalidPolicy();
        app.policy = policy;
        emit PolicyUpdated(appId, policy.requestLimit, policy.dailyLimit, policy.lifetimeLimit);
    }

    function setMetadata(uint256 appId, string calldata metadataURI) external onlyOwner(appId) nonReentrant {
        _validateMetadata(metadataURI);
        _applications[appId].metadataURI = metadataURI;
        emit MetadataUpdated(appId, metadataURI);
    }

    /// @notice An operator can charge only the configured service, to its fixed recipient.
    function configureService(
        uint256 appId,
        bytes32 serviceId,
        address operator,
        address payable recipient,
        bool enabled
    ) external onlyOwner(appId) nonReentrant {
        if (serviceId == bytes32(0) || operator == address(0)) {
            revert InvalidInput();
        }
        _validateRecipient(recipient);
        services[appId][serviceId] = Service(operator, recipient, enabled);
        emit ServiceConfigured(appId, serviceId, operator, recipient, enabled);
    }

    /// @notice Anyone can sponsor a known open account; funding grants no permissions.
    function fund(uint256 appId) external payable nonReentrant {
        Application storage app = _requireApplication(appId);
        if (app.closed) revert AccountClosed();
        if (msg.value == 0) revert InvalidInput();
        app.balance += msg.value;
        totalLiabilities += msg.value;
        emit Funded(appId, msg.sender, msg.value);
    }

    /// @notice An authorized operator submits each charge. No task scheduler runs onchain.
    function payUsage(uint256 appId, bytes32 serviceId, bytes32 requestId, uint256 amount)
        external
        nonReentrant
    {
        Application storage app = _requireApplication(appId);
        if (app.closed) revert AccountClosed();
        if (app.paused) revert AccountPaused();
        Service memory service = services[appId][serviceId];
        if (!service.enabled) revert ServiceDisabled();
        if (msg.sender != service.operator) revert Unauthorized();
        if (amount == 0 || requestId == bytes32(0)) revert InvalidInput();
        if (paidRequests[appId][requestId]) revert RequestAlreadyPaid();
        if (amount > app.policy.requestLimit) revert RequestLimitExceeded();
        uint256 day = block.timestamp / 1 days;
        uint256 dailySpent = day == app.day ? app.dailySpent : 0;
        // Subtraction avoids overflow and also handles a lowered daily limit.
        if (dailySpent > app.policy.dailyLimit || amount > app.policy.dailyLimit - dailySpent) {
            revert DailyLimitExceeded();
        }
        if (amount > app.policy.lifetimeLimit - app.lifetimeSpent) revert LifetimeLimitExceeded();
        if (amount > app.balance) revert InsufficientBalance();
        app.day = day;
        app.dailySpent = dailySpent + amount;
        app.lifetimeSpent += amount;
        app.balance -= amount;
        totalLiabilities -= amount;
        paidRequests[appId][requestId] = true;
        _send(service.recipient, amount);
        emit UsagePaid(appId, serviceId, requestId, msg.sender, service.recipient, amount);
    }

    /// @notice Withdrawals remain available during pause; they do not reset spending counters.
    function withdraw(uint256 appId, address payable recipient, uint256 amount)
        external
        onlyOwner(appId)
        nonReentrant
    {
        _validateRecipient(recipient);
        Application storage app = _applications[appId];
        if (amount == 0) revert InvalidInput();
        if (amount > app.balance) revert InsufficientBalance();
        app.balance -= amount;
        totalLiabilities -= amount;
        _send(recipient, amount);
        emit Withdrawn(appId, recipient, amount);
    }

    function setPaused(uint256 appId, bool paused) external onlyOwner(appId) nonReentrant {
        _applications[appId].paused = paused;
        emit PauseChanged(appId, paused);
    }

    /// @notice Permanent retirement requires withdrawal of all credited funds first.
    function closeApplication(uint256 appId) external onlyOwner(appId) nonReentrant {
        Application storage app = _applications[appId];
        if (app.balance != 0) revert BalanceNotEmpty();
        app.closed = true;
        emit ApplicationClosed(appId);
    }

    function _requireApplication(uint256 appId) private view returns (Application storage app) {
        app = _applications[appId];
        if (app.owner == address(0)) revert UnknownApplication();
    }

    function _validatePolicy(Policy calldata policy) private pure {
        if (
            policy.requestLimit == 0 || policy.requestLimit > policy.dailyLimit
                || policy.dailyLimit > policy.lifetimeLimit
        ) {
            revert InvalidPolicy();
        }
    }

    function _validateMetadata(string calldata metadataURI) private pure {
        if (bytes(metadataURI).length == 0 || bytes(metadataURI).length > 512) revert InvalidInput();
    }

    function _validateRecipient(address recipient) private view {
        if (recipient == address(0) || recipient == address(this)) revert InvalidInput();
    }

    function _send(address payable recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
