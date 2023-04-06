// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/*
Piccole note: se l'address non esiste in blockchain non si può fare il mapping e il contratto resistuisce un errore.
le map sono automaticamente inizializzate a valori di default, quindi non si può fare il check se esiste un mapping o no, ma bisogna fare come è stato fatto sotto.
*/

contract Trustify {
    using SafeERC20 for IERC20;

    IERC20 private token;

    struct Review {
        string review;
        uint8 stars;
        bool havePayed;
    }

    // MAPPING STUFF
    struct Company {
        address[] allCustomerAddress; //tiene tutti gli address degli utenti che hanno fatto una review a questa azienda (serve per la funzione che restituisce tutte le review di un'azienda)
        mapping(address => Review) reviewMap; //map con address di ogni utente e la review che ha fatto a questa azienda
    }

    struct Customer {
        address[] allCompanyAddress; //tiene tutti gli address delle aziende che hanno ricevuto una review da questo utente (serve per la funzione che restituisce tutte le review di un utente)
        mapping(address => Review) reviewMap; //map con address di ogni azienda/e-shop e la review che ha fatto l'utente
    }

    mapping(address => Company) companyMap; //map con address di ogni azienda/e-shop
    mapping(address => Customer) customerMap; //map con address di ogni utente

    constructor(address coinAddress) {
        token = IERC20(coinAddress);
    }

    //TRANSACTION STUFF
    modifier CheckTransaction(address companyWalletAddress) {
        require(
            companyMap[companyWalletAddress].reviewMap[msg.sender].havePayed,
            "You dont have a translaction from your address to this address"
        );
        _;
    }

    modifier CheckAllowance(uint amount) {
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Error with token allowance"
        );
        _;
    }

    function DepositTokens(
        address addressToDeposit,
        uint _amount
    ) public CheckAllowance(_amount) {
        companyMap[addressToDeposit].reviewMap[msg.sender] = Review(
            "",
            0,
            true
        );
        token.safeTransferFrom(msg.sender, addressToDeposit, _amount);
    }

    //REVIEW STUFF
    /*
        La funzione che scrive la review si accorge se l'utente ha già scritto una review per quella 
        azienda (guarda se le stelle sono a 0, valore impossibile da mettere al di fuori dal contratto),
        in tal caso sovrascrive la vecchia review con la nuova, altrimenti crea una nuova review.
    */
    function WriteAReview(
        address addressToReview,
        string memory review,
        uint8 stars
    ) public CheckTransaction(addressToReview) {
        require(
            stars > 0 && stars <= 5,
            "Error, stars must be a value between 0 and 5"
        );

        Review memory tmpReview = companyMap[addressToReview].reviewMap[
            msg.sender
        ];

        if (tmpReview.stars == 0 && bytes(tmpReview.review).length == 0) {
            Review memory _review = Review(review, stars, true);
            companyMap[addressToReview].reviewMap[msg.sender] = _review;
            companyMap[addressToReview].allCustomerAddress.push(msg.sender);
            customerMap[msg.sender].reviewMap[addressToReview] = _review;
            customerMap[msg.sender].allCompanyAddress.push(addressToReview);
        } else {
            Review memory _review = Review(review, stars, true);
            companyMap[addressToReview].reviewMap[msg.sender] = _review;
            customerMap[msg.sender].reviewMap[addressToReview] = _review;
        }
    }

    function DeleteReview(address addressToReview) public returns (bool) {
        uint allCustomerAddressSize = companyMap[addressToReview].allCustomerAddress.length;
        uint allCompanyAddressSize = customerMap[msg.sender].allCompanyAddress.length;

        require(
            allCustomerAddressSize > 0,
            "Error, you don't have review to delete"
        );

        require(
            allCompanyAddressSize > 0,
            "Error, you don't have review to delete"
        );

        Review memory _review = Review("", 0, true);
        companyMap[addressToReview].reviewMap[msg.sender] = _review;
        customerMap[msg.sender].reviewMap[addressToReview] = _review;

        allCustomerAddressSize--;
        allCompanyAddressSize--;

        uint i = 0;
        if(allCustomerAddressSize > 0) {
            for (; i <= allCustomerAddressSize; i++) {
                if (msg.sender == companyMap[addressToReview].allCustomerAddress[i]) {
                    for (uint index = i; index <= allCustomerAddressSize - 1; index++) {
                        companyMap[addressToReview].allCustomerAddress[index] = companyMap[addressToReview].allCustomerAddress[index + 1];
                    }
                    companyMap[addressToReview].allCustomerAddress.pop();
                    break;
                }
            }
        }else{
            companyMap[addressToReview].allCustomerAddress.pop();
        }

        require(
            i <= allCustomerAddressSize,
            "Unknow error during deletion of customer address review"
        );

        uint i2 = 0;
        if(allCompanyAddressSize > 0) {
            for (; i2 <= allCompanyAddressSize; i2++) {
                if (addressToReview == customerMap[msg.sender].allCompanyAddress[i2]) {
                    for (uint index = i2; index <= allCompanyAddressSize - 1; index++) {
                        customerMap[msg.sender].allCompanyAddress[index] = customerMap[msg.sender].allCompanyAddress[index + 1];
                    }
                    customerMap[msg.sender].allCompanyAddress.pop();
                    break;
                }
            }
        }else{
            customerMap[msg.sender].allCompanyAddress.pop();
        }

        require(
            i2 <= allCompanyAddressSize,
            "Unknow error during deletion of company address review"
        );

        return true;
  
    }


    function GetNCompanyReview(
        uint start,
        uint end,
        address companyAddress
    ) public view returns (string[] memory, uint8[] memory) {
        uint totalLength = companyMap[companyAddress].allCustomerAddress.length;
        require(totalLength > 0, "This company have not received any reviews");
        totalLength--;
        require(
            start <= totalLength,
            "Start must be less than the length of the array"
        );
        require(start <= end, "Start number must be less than end");
        require(end - start <= 25, "You can get max 25 reviews per call");

        if (end > totalLength) {
            end = totalLength;
        }

        uint length = end - start + 1;
        string[] memory reviews = new string[](length);
        uint8[] memory stars = new uint8[](length);

        uint index = 0;
        for (uint i = totalLength - start + 1; i >= totalLength - end + 1; i--) {
            Company storage company = companyMap[companyAddress];
            reviews[index] = company.reviewMap[company.allCustomerAddress[i - 1]].review;
            stars[index] = company.reviewMap[company.allCustomerAddress[i - 1]].stars;
            index++;
        }

        return (reviews, stars);
    }

    function GetSpecificReview(
        address addressReviewed
    ) public view returns (string memory, uint8) {
        uint8 stars = companyMap[addressReviewed].reviewMap[msg.sender].stars;
        require(
            stars != 0,
            "You have not released any reviews to this address"
        );
        string memory review = companyMap[addressReviewed]
            .reviewMap[msg.sender]
            .review;
        return (review, stars);
    }

    //This return N review of the user with [start, end] included, start start from 0
    function GetNMyReview(
        uint start,
        uint end
    ) public view returns (string[] memory, uint8[] memory, address[] memory) {
        uint totalLength = customerMap[msg.sender].allCompanyAddress.length;
        require(totalLength > 0, "You have not released any reviews");
        totalLength--;
        require(
            start <= totalLength,
            "Start must be less than the length of the array"
        );

        require(start <= end, "Start number must be less than end");
        require(end - start <= 25, "You can get max 25 reviews per call");

        if (end > totalLength) {
            end = totalLength;
        }

        uint length = end - start + 1;
        string[] memory reviews = new string[](length);
        uint8[] memory stars = new uint8[](length);
        address[] memory addresses = new address[](length);

        uint index = 0;
        for (uint i = totalLength - start + 1; i >= totalLength - end + 1; i--) {
            Customer storage customer = customerMap[msg.sender];
            reviews[index] = customer
                .reviewMap[customer.allCompanyAddress[i - 1]]
                .review;
            stars[index] = customer
                .reviewMap[customer.allCompanyAddress[i - 1]]
                .stars;
            addresses[index] = customer.allCompanyAddress[i - 1];
            index++;
        }
        return (reviews, stars, addresses);
    }

    function GetAverageStars(
        address addressReviewed
    ) public view returns (uint[] memory) {
        uint length = companyMap[addressReviewed].allCustomerAddress.length;
        require(
            length != 0,
            "This company has not received any reviews, cannot calculate average stars"
        );

        uint[] memory stars = new uint[](length);
        for (uint i = 0; i < length; i++) {
            stars[i] = companyMap[addressReviewed]
                .reviewMap[companyMap[addressReviewed].allCustomerAddress[i]]
                .stars;
        }

        return stars;
    }
}
