module king_knight::king {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::types;
    use sui::package::{Self, Publisher};

    const ENOTWITNESS: u64 = 0;
    const ENOTPACKAGE: u64 = 1;

    struct King has key {
        id: UID,
        ability: u64,
    }

    public fun create_king<T: drop>(witness: T, ctx: &mut TxContext) {
        assert!(types::is_one_time_witness(&witness), ENOTWITNESS);
        transfer::transfer(King {
            id: object::new(ctx),
            ability: 66,
        }, tx_context::sender(ctx));
    }

    entry fun rise(publisher: &Publisher, king: &mut King) {
        assert!(package::from_package<King>(publisher), ENOTPACKAGE);
        king.ability = king.ability + 1;
    }

    public fun get_ability(king: &King): u64 {
        king.ability
    }
}