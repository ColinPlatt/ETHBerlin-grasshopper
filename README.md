Grasshopper - Moving factory architecture 

------- !!!!!!THIS CONTRACT HAS BEEN DEVELOPED FOR RESEARCH AND EXPERIMENTATION PURPOSES ONLY AND SHOULD NOT BE COMMITTED TO A PUBLIC BLOCKCHAIN!!!!!! -----

Motivation:
Censorship resistance is a core motivation behind using blockchains and Ethereum. Recent actions by regulatory bodies have demonstrated that, despite the distributed nature of Ethereum and Ethereum based networks, censorship is still a concern. The ability to pinpoint specific resting addresses with undesirable features, and potentially enforce real world retalitory measures on wallets, addresses and tokens that interact with or pass through these addresses proves that the current pattern may not be sufficient for all use cases. 

Grasshopper introduces the concept of iterative, or moving factory contracts, which allow for the core onchain components of a contract and its assets to move with every interaction. 

The normal factory/instance and clone factory "minimal proxy" (EIP-1167) patterns use a deployed instance (Foundation or factory) at a fixed address that is called and which implements a contract to a new address. This means that while an instance can be redeployed as necessary to thwart attempts to censor an individual instance by address, the base factory itself remains a static and easy to identify target for censorship. This also shifts responsbility from users, who may or may not be engaged in actions seen as undesirable, to the deployers of the original or onward deployments.

Grasshopper changes this pattern by using a modified factory/instance pattern following interactions with the contract. This means that a factory has the life of a limited number of interactions, afterwhich previous factories are discarded or abandoned. 

Regulatory bodies seeking to censor Grasshopper deployments can only identify previous, abandoned addresses, and the current location which will only exist until its next called, making the cost of censorhip orders of magnitudes higher than with traditional fixed address pattern.

For the ETHBerlin Hackathon (2022), we demonstrate the Grasshopper technique on a simplified Mixer contract, based on Heiswap (https://github.com/kendricktan/heiswap-dapp.git), Grasshopper Cash (GC). 

GC allows a user to create a receipt with an offchain generated secret, and pass public key of that secret to the latest address of GC along with a deposit (1 ETH). Once five (5) addresses have submitted deposits to the latest GC deposit, the sixth (6th) deposit closes the ring by submitting the public key of their secret and the deployment code, and pushes the contract to a new address to allow withdrawals, a new iteration can then begin. Deployment code for the factory can be saved onchain and/or offchain allowing side channel message passing. This action generates a CREATE2 transaction using the hash of the finalized ring as the salt for the next deployment, thereby creating a tree of all previous contracts which can be calculated and followed from the deployment of GC upto the current location. Withdrawals work in a similar manner, submitting proofs to remove the user's deposit from the finalized ring so that they cannot be double spent. 
