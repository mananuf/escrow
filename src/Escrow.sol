// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {
    enum EscrowStatus { NOT_STARTED, AWAITING_DEPOSIT, DEPOSITED, RELEASED, CANCELLED }

    struct EscrowAgreement {
        address sender;
        address receiver;
        uint256 amount;
        EscrowStatus status;
    }

    mapping(uint256 => EscrowAgreement) public agreements;
    uint256 public agreementCounter;
    address public arbitrator;

    event EscrowCreated(uint256 agreementId, address sender, address receiver, uint256 amount);
    event DepositMade(uint256 agreementId, uint256 amount);
    event FundsReleased(uint256 agreementId, address to);
    event EscrowCancelled(uint256 agreementId);

    modifier onlySender(uint256 agreementId) {
        require(msg.sender == agreements[agreementId].sender, "Only sender can call this");
        _;
    }

    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "Only arbitrator can call this");
        _;
    }

    modifier inStatus(uint256 agreementId, EscrowStatus requiredStatus) {
        require(agreements[agreementId].status == requiredStatus, "Invalid escrow status");
        _;
    }

    constructor(address _arbitrator) {
        arbitrator = _arbitrator;
    }

    function createEscrow(address _receiver, uint256 _amount) external returns (uint256) {
        require(_receiver != address(0), "Invalid receiver address");
        require(_amount > 0, "Amount must be greater than zero");

        uint256 agreementId = agreementCounter++;
        agreements[agreementId] = EscrowAgreement({
            sender: msg.sender,
            receiver: _receiver,
            amount: _amount,
            status: EscrowStatus.AWAITING_DEPOSIT
        });

        emit EscrowCreated(agreementId, msg.sender, _receiver, _amount);
        return agreementId;
    }

    function deposit(uint256 agreementId)
        external
        payable
        onlySender(agreementId)
        inStatus(agreementId, EscrowStatus.AWAITING_DEPOSIT)
    {
        EscrowAgreement storage agreement = agreements[agreementId];
        require(msg.value == agreement.amount, "Deposit amount must match escrow amount");

        agreement.status = EscrowStatus.DEPOSITED;

        emit DepositMade(agreementId, msg.value);
    }

    function releaseFunds(uint256 agreementId)
        external
        onlySender(agreementId)
        inStatus(agreementId, EscrowStatus.DEPOSITED)
    {
        EscrowAgreement storage agreement = agreements[agreementId];
        agreement.status = EscrowStatus.RELEASED;

        payable(agreement.receiver).transfer(agreement.amount);
        emit FundsReleased(agreementId, agreement.receiver);
    }

    function cancelEscrow(uint256 agreementId)
        external
        onlySender(agreementId)
        inStatus(agreementId, EscrowStatus.DEPOSITED)
    {
        EscrowAgreement storage agreement = agreements[agreementId];
        agreement.status = EscrowStatus.CANCELLED;

        payable(agreement.sender).transfer(agreement.amount);
        emit EscrowCancelled(agreementId);
    }

    function arbitrate(uint256 agreementId, address to)
        external
        onlyArbitrator
        inStatus(agreementId, EscrowStatus.DEPOSITED)
    {
        EscrowAgreement storage agreement = agreements[agreementId];
        agreement.status = EscrowStatus.RELEASED;

        payable(to).transfer(agreement.amount);
        emit FundsReleased(agreementId, to);
    }

    function getAgreement(uint256 agreementId)
        external
        view
        returns (address, address, uint256, EscrowStatus)
    {
        EscrowAgreement storage agreement = agreements[agreementId];
        return (agreement.sender, agreement.receiver, agreement.amount, agreement.status);
    }
}
