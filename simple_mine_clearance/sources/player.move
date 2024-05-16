module simple_mine_clearance::player {
    use sui::sui::SUI;
    use sui::coin::Coin;
    use std::ascii::{char, Char};
    use sui::event;
    use std::ascii::{string, String};

    use simple_mine_clearance::admin::GameCap;
    use simple_mine_clearance::task::{Self, TaskList};
    use simple_mine_clearance::game::{Self, max_row, max_list};

    // ====== constant ======

    const MinimumStartBonus: u64 = 666;

    // ====== error code ======

    const ENotEnoughBalanceStart: u64 = 2;
    const ENotCorrectTaskOrCompleted: u64 = 3;
    const ENotCorrectRowOrList: u64 = 5;

    // ====== player struct ======

    public struct GameInfo has key {
        id: UID,
        task_id: ID,
        checkerboard: vector<vector<Char>>,
        hash_code: vector<u8>,
    }

    public struct PlayTooLate has copy, drop {
        loser: String,
    }

    // ====== player function ======

    entry fun start_game(game_cap: &mut GameCap, mut coin: Coin<SUI>, ctx: &mut TxContext) {
        // check the coin value
        assert!(coin.value() >= MinimumStartBonus, ENotEnoughBalanceStart);

        let pay_coin = coin.split(MinimumStartBonus, ctx);

        // deal with the remaining coin
        if (coin.value() > 0) {
            transfer::public_transfer(coin, ctx.sender());
        } else {
            coin.destroy_zero();
        };

        // transfer the exact amount of coin
        let publisher_balance = game_cap.borrow_balance_mut();
        publisher_balance.join(pay_coin.into_balance());
        // if the balance exceeds 10SUI then withdraw it
        if (publisher_balance.value() >= 10000000000) {
            game_cap.withdraw_(ctx);
        };

        // prepare the GameInfo's id and taskid(fake)
        let id = object::new(ctx);
        let task_id = id.uid_to_inner();
        // create GameInfo
        let game_info = GameInfo {
            id,
            task_id,
            checkerboard: game::generate_empty_checkerboard(),
            hash_code: vector<u8>[],
        };
        transfer::transfer(game_info, ctx.sender());
    }

    entry fun start_task(task_id: ID, task_list: &mut TaskList, coin: Coin<SUI>, ctx: &mut TxContext) {
        // check the task id
        assert!(task_list.contains(task_id), ENotCorrectTaskOrCompleted);

        // get task
        let task = task_list.borrow_task_mut(task_id);
        task.add_attempt();

        // update reward and earned
        task.update(coin, ctx);

        // create GameInfo
        let game_info = GameInfo {
            id: object::new(ctx),
            task_id,
            checkerboard: game::generate_empty_checkerboard(),
            hash_code: vector<u8>[],
        };
        transfer::transfer(game_info, ctx.sender());
    }

    fun destroy_game_info(game_info: GameInfo) {
        let GameInfo {
            id,
            task_id: _,
            checkerboard: _,
            hash_code: _,
        } = game_info;
        object::delete(id);
    }

    entry fun game_click(mut r: u64, mut l: u64, mut game_info: GameInfo, ctx: &mut TxContext) {
        // check the r and l
        assert!(r >= 1 && r <= max_row() && l >= 1 && l <= max_list(), ENotCorrectRowOrList);

        // change the r and l to satisfy subscript
        r = r - 1;
        l = l - 1;

        // check the hash code
        if (game_info.hash_code.length() == 0) {
            let seed = ctx.epoch_timestamp_ms() % (l + r + 1);
            game_info.hash_code = game::generate_hash(seed, ctx);
        };

        // get checkerboard and hash
        let mut checkerboard = game_info.checkerboard;
        let hash = game_info.hash_code;

        // check click safe
        if (game::confirm_safe(r, l, &hash)) {
            // update checkerboard
            game::dfs(r, l, &mut checkerboard, &hash);
            // check success
            if (game::success_clear(&checkerboard, &hash)) {
                // emit event and destroy game info
                game::success_emit(0, &checkerboard);
                destroy_game_info(game_info);
            } else {
                // emit event and transfer game info for next click
                game::emit(&checkerboard);
                game_info.checkerboard = checkerboard;
                transfer::transfer(game_info, ctx.sender());
            };
        } else {
            // update checkerboard
            let square = &mut checkerboard[r][l];
            *square = char(b"x"[0]);

            // emit and destroy game info
            game::failure_emit(&checkerboard);
            destroy_game_info(game_info);
        };
    }

    entry fun game_click_task(game_cap: &mut GameCap, mut r: u64, mut l: u64, mut game_info: GameInfo, task_list: &mut TaskList, ctx: &mut TxContext) {
        // check the task
        if (!task_list.contains(game_info.task_id)) {
            destroy_game_info(game_info);
            event::emit(PlayTooLate {loser: string(b"The bounty mission has been completed!!!")});
            return
        };

        // get the task
        let task = task_list.borrow_task_mut(game_info.task_id);

        // check the r and l
        assert!(r >= 1 && r <= max_row() && l >= 1 && l <= max_list(), ENotCorrectRowOrList);

        // change the r and l to satisfy subscript
        r = r - 1;
        l = l - 1;

        // check the hash code
        if (game_info.hash_code.length() == 0) {
            let seed = task.as_seed();
            game_info.hash_code = game::generate_hash(seed, ctx);
        };

        // get checkerboard and hash
        let mut checkerboard = game_info.checkerboard;
        let hash = game_info.hash_code;

        // check click safe
        if (game::confirm_safe(r, l, &hash)) {
            // update checkerboard
            game::dfs(r, l, &mut checkerboard, &hash);
            // check success
            if (game::success_clear(&checkerboard, &hash)) {
                // emit event, complete task and destroy game info
                game::success_emit(task.value(), &checkerboard);
                task::complete_task(game_cap, game_info.task_id, task_list, ctx);
                destroy_game_info(game_info);
            } else {
                // emit event and transfer game info for next click
                game::emit(&checkerboard);
                game_info.checkerboard = checkerboard;
                transfer::transfer(game_info, ctx.sender());
            };
        } else {
            // update checkerboard
            let square = &mut checkerboard[r][l];
            *square = char(b"x"[0]);
            
            // update attempt, emit and destroy game info
            task.failed_attempt();
            game::failure_emit(&checkerboard);
            destroy_game_info(game_info);
        };
    }

    entry fun query_checkerboard(game_info: &GameInfo) {
        game::emit(&game_info.checkerboard);
    }

    entry fun quit_game(game_info: GameInfo, task_list: &mut TaskList) {
        // check the task
        if (!task_list.contains(game_info.task_id)) {
            destroy_game_info(game_info);
            return
        };

        // get the task
        let task = task_list.borrow_task_mut(game_info.task_id);

        // update failure count and then destroy it
        task.failed_attempt();
        destroy_game_info(game_info);
    }
}