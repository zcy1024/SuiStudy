module simple_mine_clearance::game {
    use sui::event;
    use std::ascii::{char, Char, string, String};
    use std::bcs;
    use sui::hmac::hmac_sha3_256;

    // ====== constant ======

    // up down left right(avoid negative numbers)
    const XDirection: vector<u64> = vector<u64>[0, 2, 1, 1];
    const YDirection: vector<u64> = vector<u64>[1, 1, 0, 2];

    const MaxRow: u64 = 5;
    const MaxList: u64 = 10;

    // ====== game event struct ======

    public struct GameEvent has copy, drop {
        checkerboard: vector<String>,
    }

    public struct GameSuccessEvent has copy, drop {
        reward: u64,
    }

    public struct GameOverEvent has copy, drop {
        loser: String,
    }

    // ====== game function ======

    public fun emit(vec: &vector<vector<Char>>) {
        // char => string
        // for ease of reading
        let mut checkerboard = vector<String>[];
        let mut i = 0;
        while (i < MaxRow) {
            let mut row = string(b"");
            let mut j = 0;
            while (j < MaxList) {
                row.push_char(vec[i][j]);
                j = j + 1;
            };
            checkerboard.push_back(row);
            i = i + 1;
        };
        event::emit(GameEvent {checkerboard});
    }

    public fun generate_empty_checkerboard(): vector<vector<Char>> {
        let c = char(b"-"[0]);

        // fill in_v in a loop
        let mut i = 0;
        let mut in_v = vector<Char>[];
        while (i < MaxList) {
            in_v.push_back(c);
            i = i + 1;
        };

        // fill out_v in a loop
        i = 0;
        let mut out_v = vector<vector<Char>>[];
        while (i < MaxRow) {
            out_v.push_back(in_v);
            i = i + 1;
        };

        // emit empty checkerboard and return
        emit(&out_v);
        out_v
    }

    public fun generate_hash(seed: u64, ctx: &mut TxContext): vector<u8> {
        hmac_sha3_256(&bcs::to_bytes(&seed), &ctx.fresh_object_address().to_bytes())
    }

    public fun confirm_safe(r: u64, l: u64, hash: &vector<u8>): bool {
        let pos = r * MaxList + l;
        // pos % 30 + 1 => between 1 ~ 30
        let byte = hash[pos % 30 + 1] as u64;
        // unused is hash[0] and hash[31]
        let p1 = hash[0] as u64;
        let p2 = hash[31] as u64;
        // + 2 to avoid divisor < 2
        // divisor can't be 0
        // if divisor = 1 then (0, 0) must be safe
        (byte * p1 * p2) % (pos + 2) % 2 == 0
    }

    public fun success_emit(reward: u64, vec: &vector<vector<Char>>) {
        event::emit(GameSuccessEvent {reward});
        emit(vec);
    }

    public fun success_clear(checkerboard: &vector<vector<Char>>, hash: &vector<u8>): bool {
        let mut i = 0;
        while (i < MaxRow) {
            let mut j = 0;
            while (j < MaxList) {
                if (checkerboard[i][j] == char(b"-"[0]) && confirm_safe(i, j, hash)) {
                    return false
                };
                j = j + 1;
            };
            i = i + 1;
        };
        return true
    }

    public fun failure_emit(vec: &vector<vector<Char>>) {
        event::emit(GameOverEvent {loser: string(b"Game Over")});
        emit(vec);
    }

    #[allow(implicit_const_copy)]
    public fun dfs(r: u64, l: u64, checkerboard: &mut vector<vector<Char>>, hash: &vector<u8>) {
        // have be clicked
        if (checkerboard[r][l] != char(b"-"[0])) {
            return
        };

        // find mines in around
        let mut cur_byte = b"0"[0];
        let mut i = 0;
        while (i <= 2) {
            let mut j = 0;
            while (j <= 2) {
                let x = r + i;
                let y = l + j;
                // out of range
                if (x <= 0 || x > MaxRow || y <= 0 || y > MaxList) {
                    j = j + 1;
                    continue
                };
                // add the mine number
                if (!confirm_safe(x - 1, y - 1, hash)) {
                    cur_byte = cur_byte + 1;
                };
                j = j + 1;
            };
            i = i + 1;
        };

        // set checkerboard
        let square = &mut checkerboard[r][l];
        *square = char(cur_byte);

        // have mines in around
        if (cur_byte != b"0"[0]) {
            return
        };

        // expand around
        i = 0;
        while (i < 4) {
            let x = r + XDirection[i];
            let y = l + YDirection[i];
            // out of range
            if (x <= 0 || x > MaxRow || y <= 0 || y > MaxList) {
                i = i + 1;
                continue
            };
            dfs(x - 1, y - 1, checkerboard, hash);
            i = i + 1;
        };
    }

    public fun max_row(): u64 {
        MaxRow
    }

    public fun max_list(): u64 {
        MaxList
    }
}