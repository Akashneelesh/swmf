
use starknet::{ContractAddress};
#[starknet::interface]
pub trait IMintable<TContractState> {
    fn mint(ref self: TContractState, tx_hash: ByteArray, chain_id : felt252, user_address: ContractAddress);
}

#[starknet::contract]
mod nft {
    use swmf::bytearray::ByteArrayExtTrait;

    use openzeppelin::introspection::src5::{SRC5Component, SRC5Component::InternalTrait as SRC5InternalTrait};
    use openzeppelin::token::erc721::{
        ERC721Component, interface::IERC721Metadata, interface::IERC721MetadataCamelOnly, interface::IERC721_ID,
        interface::IERC721_METADATA_ID, ERC721HooksEmptyImpl
    };
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess,StorageMapReadAccess, StorageMapWriteAccess
    };
    use starknet::{ContractAddress, get_caller_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,

        // keeps track of the last minted token ID
        latest_token_id: u128,

        txhash_useraddress: Map<ContractAddress,felt252>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        MintEvent: MintEvent
    }

    #[derive(Drop, starknet::Event)]
    struct MintEvent {
      
            tx_hash: ByteArray,
            chain_id: felt252,
            user_address: ContractAddress
        }
    #[constructor]
    fn constructor(ref self: ContractState) {
        // not calling self.erc721.initializer as we implement the metadata interface ourselves,
        // just registering the interface with SRC5 component
        self.src5.register_interface(IERC721_ID);
        self.src5.register_interface(IERC721_METADATA_ID);
    }

    #[abi(embed_v0)]
    impl ERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "Starknet will melt faces"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "SWMF"
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            assert(token_id <= self.latest_token_id.read().into(), 'Token ID does not exist');
            let svg: ByteArray = "SWMF URI";
            svg
          
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelMetadataImpl of IERC721MetadataCamelOnly<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.token_uri(tokenId)
        }
    }

    #[abi(embed_v0)]
    impl IMintableImpl of super::IMintable<ContractState> {
        fn mint(ref self: ContractState, tx_hash: ByteArray, chain_id : felt252, user_address: ContractAddress) {

            let recorded_txhash = self.txhash_useraddress.read(user_address);
            let pedersen_hash = tx_hash.hash();
            assert(recorded_txhash == pedersen_hash, 'Transaction already recorded');

     
            let token_id = self.latest_token_id.read() + 1;
            self.latest_token_id.write(token_id);
        
            let minter = get_caller_address();
            
            self.txhash_useraddress.write(user_address, pedersen_hash);
        
            self.erc721.mint(minter, token_id.into());
            self.emit(MintEvent { tx_hash, chain_id, user_address });
        
        
        }
    }


}
