// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./Interfaces/IERC5095.sol";
import "./Interfaces/IERC20.sol";

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
contract ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event Redeemed(address indexed owner, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    address public immutable principalToken;

    uint256 public immutable principalAmount;

    address public immutable admin;

    string public startingURI = "https://api.jsonbin.io/b/61ca61efc277c467cb37523b";

    string public redeemedURI = "https://api.jsonbin.io/b/61ca61efc277c467cb37523b";

    uint256 public totalSupply;

    /*//////////////////////////////////////////////////////////////
                      ERC721 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    mapping(uint256 => bool) public redeemed;

    function ownerOf(uint256 id) public view returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol, address principal, uint256 amount, address administrator) {
        name = _name;
        symbol = _symbol;
        principalToken = principal;
        principalAmount = amount;
        admin = administrator;
    }


    /*//////////////////////////////////////////////////////////////
                              CUSTOM LOGIC
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 id) public view returns (string memory){
        require(_ownerOf[id] != address(0), "URI Does not exist");

        if (redeemed[id] == true) {
            return redeemedURI;
        }
        else {
            return startingURI;
        }
    }

    function redeem(uint256 id) public returns (uint256 amount) {
        address owner = _ownerOf[id];

        require(msg.sender == owner, "NOT_AUTHORIZED");
        
        require(owner != address(0), "URI Does not exist");

        require(redeemed[id] == false, "Already redeemed");

        redeemed[id] = true;

        emit Redeemed(owner, id);

        return IERC5095(principalToken).redeem(principalAmount, address(this), owner);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN METHODS
    //////////////////////////////////////////////////////////////*/

    function mint(address[] memory owners) public onlyAdmin {
        for (uint256 i; i != owners.length;) {
            _mint(owners[i], (totalSupply + 1));
            unchecked {
                ++i;
            }
            totalSupply = totalSupply + 1;
        }
        IERC20(principalToken).transferFrom(msg.sender, address(this), (principalAmount * owners.length));
    }

    // Sets the pre-redemption token URI
    // @param _startingURI - the URI to set
    function setStartingURI(string memory _startingURI) public onlyAdmin {
        startingURI = _startingURI;
    }

    // Sets the post-redemption token URI
    // @param _redeemedURI - the URI to set
    function setRedeemedURI(string memory _redeemedURI) public onlyAdmin {
        redeemedURI = _redeemedURI;
    }

    // Allows the admin to withdraw any erc20 tokens from the contract
    // @param token - the token to withdraw
    function adminWithdraw(address token) public onlyAdmin {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(redeemed[id] == false, "Cannot transfer after redeeming.");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        transferFrom(from, to, id);

        if (to.code.length != 0)
            require(
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if (to.code.length != 0)
            require(
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal {
        require(to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal {
        address owner = _ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal {
        _mint(to, id);

        if (to.code.length != 0)
            require(
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal {
        _mint(to, id);

        if (to.code.length != 0)
            require(
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this method");
        _;
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
