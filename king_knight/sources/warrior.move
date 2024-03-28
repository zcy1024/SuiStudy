module king_knight::warrior {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string::String;

    struct Warrior has key {
        id: UID,
        name: String,
        ability: u64,
    }

    entry fun create_warrior(name: String, ability: u64, ctx: &mut TxContext) {
        transfer::transfer(Warrior {
            id: object::new(ctx),
            name,
            ability,
        }, tx_context::sender(ctx));
    }

    entry fun rise(warrior: &mut Warrior) {
        warrior.ability = warrior.ability + 1;
    }

    public fun get_ability(warrior: &Warrior): u64 {
        warrior.ability
    }

    public fun destroy(warrior: Warrior): (String, u64) {
        let Warrior{id, name, ability} = warrior;
        object::delete(id);
        (name, ability)
    }
}