pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./HanwhaToken.sol";

/**
 * @title CrowdFunding P2P Loan
 */
contract P2PLoan is Ownable {

    using SafeMath for uint256;

    enum P2P_STATUS {
        FUNDING,
        FUNDING_SUCCESS,
        REPAYING,
        DELAYED,
        COMPLETE,
        TERMINATE,
        FAIL
    } 

    struct Loan {
        P2P_STATUS loanStatus;
        string loanId;
        uint256 loanAmount;
        uint256 repayAmount;
        uint256 loanTerm;
        uint256 loanRate;   // 1% => 100, 1.2% => 120, 1.25% => 125
        uint256 repayOrder;
        uint256 fundingStartDateTime;
        uint256 fundingCloseDateTime;
    }

    struct Invest {
        uint256 investAmount;
        uint256 paidAmount;
        uint256 payOrder;
    }

    struct RepaySchedule {
        uint256 repayAmount;
        bool isRepaid;
    }

    // The token being sold
    HanwhaToken public token;
    // Address where funds are collected
    address public wallet;
    // How many token units a buyer gets per ether
    uint256 public rate;
    // Amount of wei raised
    uint256 public weiRaised;
    // Amount of token minted
    uint256 public tokenAmount;

    // The owner's loan info
    Loan public loan;
    uint256 MULTIPLIER = 10 ** 4;
    // Investor's invest amount limitation
    uint256 INVEST_LIMIT = (10 ether);
    
    mapping(address => Invest) public investors;
    mapping(uint256 => RepaySchedule) public repaySchedules;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event CreateLoan(string loanId, uint256 loanAmount, uint256 burnedTokenAmount, uint256 fundingStartDatetime, uint256 fundingCloseDateTime);
    event AddInvestor(string loanId, address indexed investorAddress, uint256 investAmount, uint256 receivedTokenAmount);
    event WithdrawLoanAmount(string loanId, uint256 loanAmount);
    event RepayLoan(string loanId, uint256 currentRepayAmount, uint256 currentRepayOrder, uint256 totalRepayAmount, uint256 totalRepayOrder);
    event PayToInvestor(
        string loanId, 
        address indexed investorAddress, 
        uint256 currentPayAmount, 
        uint256 currentPayOrder, 
        uint256 totalPayAmount
    );
    event RepayComplete(string loanId);
    event TerminateLoan(string loanId);

    modifier inLoanStatus(P2P_STATUS _loanStatus) {
        require(loan.loanStatus == _loanStatus, "Loan is not profer status");
        _;
    }

    modifier inFundingDuration() {
        require(now >= loan.fundingStartDateTime && now <= loan.fundingCloseDateTime, "Funding expired!");
        _;
    }


    /**
     * @param _rate Number of token units a buyer gets per wei
     * @param _wallet Address where collected funds will be forwarded to
     * @param _token Address of the token being sold
     */
    constructor (uint256 _rate, address _wallet, HanwhaToken _token) public {
        require(_rate > 0);
        require(_wallet != address(0));
        require(_token != address(0));

        rate = _rate;
        wallet = _wallet;
        token = _token;
    }

    

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------

    function createLoan(
        string _loanId, 
        uint256 _loanAmount, 
        uint256 _loanTerm, 
        uint256 _loanRate, 
        uint256 _fundingStartDatetime, 
        uint256 _fundingCloseDatetime
    ) public {
        loan = Loan(P2P_STATUS.FUNDING, _loanId, _loanAmount, 0, _loanTerm, _loanRate, 0, _fundingStartDatetime, _fundingCloseDatetime);
        emit CreateLoan(loan.loanId, loan.loanAmount, _getTokenAmount(_loanAmount), _fundingStartDatetime, _fundingCloseDatetime);        
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary) public payable {

        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        _processPurchase(_beneficiary, tokens);
        emit TokenPurchase(
            msg.sender,
            _beneficiary,
            weiAmount,
            tokens
        );

        _updatePurchasingState(_beneficiary, weiAmount);

        _forwardFunds();
        _postValidatePurchase(_beneficiary, weiAmount);
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        require(_beneficiary != address(0));
        // require(_weiAmount != 0);
        
        // require(checkFundingStatus() == P2P_STATUS.FUNDING);
        // require(_checkProperInvesting(_beneficiary, _weiAmount));
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _postValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        // optional override
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        // token.transfer(_beneficiary, _tokenAmount);
        token.mint(_beneficiary, _tokenAmount);
        tokenAmount = tokenAmount.add(_tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param _beneficiary Address receiving the tokens
     * @param _tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions, etc.)
     * @param _beneficiary Address receiving the tokens
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
        // optional override
        investors[_beneficiary].investAmount = investors[_beneficiary].investAmount.add(_weiAmount);
        investors[_beneficiary].payOrder = 0;

        emit AddInvestor(loan.loanId, _beneficiary, investors[_beneficiary].investAmount, token.balanceOf(_beneficiary));
        
        if (checkFundingStatus() == P2P_STATUS.FUNDING_SUCCESS) {
            // it occurs error
            // token.finishMinting();
        }
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount.mul(rate).div(1 ether);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        // wallet.transfer(msg.value);
    }

    /**
     * @dev checks whether the investor's investing amount is overed specific limit
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Number of tokens to be emitted
     */
    function _checkProperInvesting(address _beneficiary, uint256 _weiAmount) internal view returns (bool isProper) {
        if (investors[_beneficiary].investAmount != 0 && investors[_beneficiary].investAmount.add(_weiAmount) > INVEST_LIMIT) {
            isProper = false;
        } else {
            isProper = true;
        }
    }

    /**
     * @dev checks whether the funding duration is overed. if overed the chang loan status to fail
     * @return loan status
     */
    function checkFundingStatus() public returns (P2P_STATUS) {
        if (loan.loanStatus == P2P_STATUS.FUNDING) {
            if(_isFundingClosed()) {
                loan.loanStatus = P2P_STATUS.FAIL;
            } else if (loan.loanAmount == weiRaised) {
                loan.loanStatus = P2P_STATUS.FUNDING_SUCCESS;
            }
        } else if (loan.loanStatus == P2P_STATUS.REPAYING && loan.repayOrder == loan.loanTerm) {
            loan.loanStatus = P2P_STATUS.COMPLETE;
        } else if (loan.loanStatus == P2P_STATUS.COMPLETE && token.totalSupply() == 0) {
            loan.loanStatus = P2P_STATUS.TERMINATE;
        }

        return loan.loanStatus;
    }

    function _isFundingClosed() internal view returns (bool) {
        return now > loan.fundingCloseDateTime;
    }

    /**
     * @dev Loaner withdraw funding amount
     */
    function withdrawByLoaner() public onlyOwner inLoanStatus(P2P_STATUS.FUNDING_SUCCESS) {
        require(weiRaised == address(this).balance);

        wallet.transfer(weiRaised);
        createRepaySchedule();
        loan.loanStatus = P2P_STATUS.REPAYING;

        emit WithdrawLoanAmount(loan.loanId, weiRaised);
    }

    /**
    * @dev Loaner repay amount and interest what their loan funding
    */
    function repayByLoaner() public onlyOwner payable inLoanStatus(P2P_STATUS.REPAYING) {
        require (repaySchedules[loan.repayOrder.add(1)].repayAmount == msg.value);

        loan.repayOrder = loan.repayOrder.add(1);
        loan.repayAmount = loan.repayAmount.add(msg.value);
        repaySchedules[loan.repayOrder].isRepaid = true;

        emit RepayLoan(loan.loanId, msg.value, loan.repayOrder, loan.repayAmount, loan.loanTerm);

        if (checkFundingStatus() == P2P_STATUS.COMPLETE) {
            emit RepayComplete(loan.loanId);
        }
    }

    /**
    * @dev Investor withdraw funding interest
    */
    function withdrawByInvestor(address _investor) public {
        checkFundingStatus();
        require(loan.loanStatus == P2P_STATUS.REPAYING || loan.loanStatus == P2P_STATUS.COMPLETE);
        require(loan.repayOrder > investors[_investor].payOrder);

        uint256 payOrder = investors[_investor].payOrder.add(1);
        uint256 payAmount = repaySchedules[payOrder].repayAmount.mul(token.balanceOf(_investor)).div(tokenAmount);
        investors[_investor].payOrder = payOrder;
        investors[_investor].paidAmount = investors[_investor].paidAmount.add(payAmount);
        
        _investor.transfer(payAmount);

        emit PayToInvestor(loan.loanId, _investor, payAmount, investors[_investor].payOrder, investors[_investor].paidAmount);

        // complete receiving
        if (payOrder == loan.loanTerm) {
            token.burnToken(_investor, token.balanceOf(_investor));

            if (checkFundingStatus() == P2P_STATUS.TERMINATE) {
                emit TerminateLoan(loan.loanId);
            }
        }  
    }

    function getExpectedNextPayAmount(address _investor) public view returns (uint256){
        uint256 payOrder = investors[_investor].payOrder.add(1);
        uint256 payAmount = repaySchedules[payOrder].repayAmount.mul(token.balanceOf(_investor)).div(tokenAmount);

        return payAmount;
    }

    /**
    * @dev Create loan amount and interest repay schedules per month
    */
    function createRepaySchedule() public {
        // uint256 applyRate = loan.loanRate.div(12).add(1)**loan.loanTerm;
        
        uint256 repayAmountPerMonth = loan.loanAmount.add(loan.loanAmount.div(MULTIPLIER).mul(loan.loanRate));
        repayAmountPerMonth = repayAmountPerMonth.div(12);

        for (uint256 repayOrder = 1; repayOrder <= loan.loanTerm; repayOrder++) {
            repaySchedules[repayOrder] = RepaySchedule(repayAmountPerMonth, false);
        }
    }
}