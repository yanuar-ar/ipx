// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IPX} from "../src/IPX.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {RoyaltyTokenFactory} from "../src/RoyaltyTokenFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RoyaltyToken} from "../src/RoyaltyToken.sol";

contract IPXTest is Test, IERC721Receiver {
    IPX public ipX;
    RoyaltyTokenFactory public royaltyTokenFactory;
    MockUSDC public mockUSDC;

    function setUp() public {
        mockUSDC = new MockUSDC();
        royaltyTokenFactory = new RoyaltyTokenFactory(address(mockUSDC));
        ipX = new IPX(address(royaltyTokenFactory));
    }

    function test_registerIP() public {
        ipX.registerIP("test", "test", "test");
        assertEq(ipX.nextTokenId(), 2);
    }

    function test_rentIP() public {
        deal(address(this), 1000 ether);
        ipX.registerIP("test", "test", "test");
        ipX.rentIP{value: 1000}(2);
        (uint256 expiredAt, address renter) = ipX.rents(2, address(this));
        assertEq(expiredAt, block.timestamp + 30 days);
    }

    function test_buyIP() public {
        deal(address(this), 1000 ether);
        uint256 tokenId = ipX.registerIP("test", "test", "test");
        ipX.buyIP{value: 1000}(tokenId);
        assertEq(ipX.ownerOf(tokenId), address(this));
    }

    function test_remixIP() public {
        ipX.registerIP("parent", "parent", "parent");
        ipX.remixIP("child", "child", "child", 1);
        assertEq(ipX.ownerOf(2), address(this));
        address parentRoyaltyToken = ipX.royaltyTokens(1);
        address childRoyaltyToken = ipX.royaltyTokens(2);

        // parent should have 20% of the child royalty token
        assertEq(IERC20(childRoyaltyToken).balanceOf(parentRoyaltyToken), 20_000_000e18);

        // creator should have 80% of the child royalty token
        assertEq(IERC20(childRoyaltyToken).balanceOf(address(this)), 80_000_000e18);
    }

    function test_deposit_claim_royalty() public {
        // royalty reward token is USDC
        mockUSDC.mint(address(this), 1000e6);
        ipX.registerIP("parent", "parent", "parent");

        // deposit royalty
        address rt = ipX.royaltyTokens(1);
        IERC20(mockUSDC).approve(rt, 1000e6);
        uint256 blockNumber = RoyaltyToken(rt).depositRoyalty(1000e6);

        // advance 1 block
        vm.roll(block.number + 1);
        RoyaltyToken(rt).claimRoyalty(blockNumber);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
