module a_add_b_move::add {
    use sui::event;

    public struct Result has key {
        id: UID,
        res: u64,
    }

    public struct ResultEvent has copy, drop {
        res: u64,
    }

    entry fun add(a: u64, b: u64, ctx: &mut TxContext) {
        transfer::transfer(Result {
            id: object::new(ctx),
            res: a + b,
        }, ctx.sender());
        event::emit(ResultEvent { res: a + b });
    }
}