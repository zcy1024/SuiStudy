module king_knight::interact {
    use sui::tx_context::TxContext;

    use king_knight::warrior::{Self, Warrior};
    use king_knight::king::{Self, King};
    use king_knight::knight::create_knight;

    const ENOTENOUGHABILITY: u64 = 0;

    struct INTERACT has drop {}

    fun init(otw: INTERACT, ctx: &mut TxContext) {
        king::create_king(otw, ctx);
    }

    entry fun rise(warrior: Warrior, king: &King, ctx: &mut TxContext) {
        assert!(warrior::get_ability(&warrior) >= king::get_ability(king), ENOTENOUGHABILITY);
        let (name, ability) = warrior::destroy(warrior);
        create_knight(name, ability, ctx);
    }
}