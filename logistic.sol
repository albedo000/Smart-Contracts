//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

contract logistic {
    address public seller;
    address payable public buyer;
    address public transport;

    struct Product {
        string id;
        string description;
        uint256 price;
        uint256 quantity;
    }

    Product[] public product;
    uint256 public total;
    uint256 public toPay;
    uint256 public funds;
    uint256 public pendingReturns;

    enum stateOfShipping {
        ORDER,
        PAY,
        HANDOVER,
        REFUND,
        RECEIVED,
        CLOSED
    }

    stateOfShipping state;

    event Paid(address _buyer, uint256 _total);
    event Shipping(address _transport);
    event Delegation(address delegate);
    event Refund(address _buyer, uint256 _total);
    event Closed();

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only customer can use this function.");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only dealer can use this function.");
        _;
    }

    modifier onlyTransport() {
        require(msg.sender == transport, "Only vector can delegate.");
        _;
    }

    modifier withdrawable() {
        require(state != stateOfShipping.REFUND, "Checking refund!");
        require(state != stateOfShipping.CLOSED, "Not callable!");
        _;
    }

    constructor(address payable _buyer) {
        seller = msg.sender;
        buyer = _buyer;
        total = 0;
    }

    function insertProduct(
        string memory _id,
        string memory _description,
        uint256 _price,
        uint256 _quantity
    ) public onlyBuyer {
        Product memory p = Product({
            id: _id,
            description: _description,
            price: _price,
            quantity: _quantity
        });

        product.push(p);
        state = stateOfShipping.ORDER;
        calculateTotal();
    }

    function calculateTotal() public {
        for (uint256 i = 0; i < product.length; i++) {
            total += (product[i].price * product[i].quantity);
        }
        toPay = total;
    }

    function pay(uint256 _pay) external payable {
        require(total > 0, "Calculate total before!");
        require(state == stateOfShipping.ORDER, "Already paid!");
        funds += _pay;
        toPay -= _pay;
        if (toPay == 0) {
            state = stateOfShipping.PAY;
            emit Paid(buyer, funds);
        }
    }

    function transportation(address _transport) public onlySeller {
        require(state == stateOfShipping.PAY, "Not paid!");
        transport = _transport;
        state = stateOfShipping.HANDOVER;
        emit Shipping(transport);
    }

    function delegate(address _delegate) public onlyTransport {
        transport = _delegate;
        emit Delegation(transport);
    }

    function received() public onlyTransport {
        state = stateOfShipping.RECEIVED;
    }

    function refund() public withdrawable {
        require(funds > 0, "Not callable");
        if (msg.sender == seller) {
            pendingReturns = funds;
            funds = 0;
            emit Refund(buyer, pendingReturns);
            state = stateOfShipping.REFUND;
        }
    }

    function withdraw() public onlyBuyer {
        require(pendingReturns > 0, "Cannot withdraw");
        pendingReturns = 0;
        payable(buyer).transfer(address(this).balance);
    }

    function gain() public onlySeller withdrawable {
        require(state == stateOfShipping.RECEIVED);
        state = stateOfShipping.CLOSED;
        require(funds > 0);
        funds = 0;
        payable(seller).transfer(address(this).balance);
    }
}