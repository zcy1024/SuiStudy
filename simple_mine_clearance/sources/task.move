module simple_mine_clearance::task {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::event;

    use simple_mine_clearance::admin::GameCap;

    // ====== constant ======

    const MinimumBonus: u64 = 1998;

    // ====== error code ======
    
    const ENotEnoughBalance: u64 = 1;
    const ENotEnoughBalanceStart: u64 = 4;
    const ENotCorrectTaskOrCompleted: u64 = 6;

    // ====== task struct ======

    public struct TaskList has key {
        id: UID,
        task_ids: vector<ID>,
        tasks: Table<ID, Task>,
    }

    public struct Task has store {
        in_task: u64,
        total_attempts: u64,
        reward: Balance<SUI>,
        earned: Balance<SUI>,
        task_publisher_address: address,
    }

    public struct QueryTaskEvent has copy, drop {
        task_id: ID,
        in_task: u64,
        total_attempts: u64,
        cur_reward: u64,
    }

    // ====== task function ======

    fun init(ctx: &mut TxContext) {
        // create and transfer task list
        let task_list = TaskList {
            id: object::new(ctx),
            task_ids: vector<ID>[],
            tasks: table::new<ID, Task>(ctx),
        };
        transfer::share_object(task_list);
    }

    entry fun create_task(task_list: &mut TaskList, mut coin: Coin<SUI>, amount: u64, ctx: &mut TxContext) {
        // check the balance number
        assert!(coin.value() >= amount && amount >= MinimumBonus, ENotEnoughBalance);

        // split coin
        let reward_coin = coin.split(amount, ctx);
        let reward_balance = reward_coin.into_balance();

        // deal with the remaining coin
        if (coin.value() > 0) {
            transfer::public_transfer(coin, ctx.sender());
        } else {
            coin.destroy_zero();
        };

        // generate ID
        let id = object::id_from_address(ctx.fresh_object_address());
        // create task
        let task = Task {
            in_task: 0,
            total_attempts: 0,
            reward: reward_balance,
            earned: balance::zero(),
            task_publisher_address: ctx.sender(),
        };
        // store it
        task_list.task_ids.push_back(id);
        task_list.tasks.add(id, task);
    }

    #[allow(lint(self_transfer))]
    public fun complete_task(game_cap: &mut GameCap, task_id: ID, task_list: &mut TaskList, ctx: &mut TxContext) {
        // get task_ids
        let task_ids = &mut task_list.task_ids;
        // get index
        let (_, idx) = task_ids.index_of(&task_id);
        // remove it
        task_ids.remove(idx);

        // remove and get task
        let task = task_list.tasks.remove(task_id);
        // get task details
        let Task {
            in_task: _,
            total_attempts: _,
            reward,
            mut earned,
            task_publisher_address,
        } = task;

        // player reward
        transfer::public_transfer(coin::from_balance(reward, ctx), ctx.sender());

        // package publisher earned
        let amount = earned.value();
        let publisher_earned = earned.split(amount / 3);
        let publisher_balance = game_cap.borrow_balance_mut();
        publisher_balance.join(publisher_earned);
        // if the balance exceeds 10SUI then withdraw it
        if (publisher_balance.value() >= 10000000000) {
            game_cap.withdraw_(ctx);
        };

        // task publisher earned
        transfer::public_transfer(coin::from_balance(earned, ctx), task_publisher_address);
    }

    public fun contains(task_list: &TaskList, task_id: ID): bool {
        task_list.tasks.contains(task_id)
    }

    public fun borrow_task_mut(task_list: &mut TaskList, task_id: ID): &mut Task {
        task_list.tasks.borrow_mut(task_id)
    }

    public fun add_attempt(task: &mut Task) {
        task.in_task = task.in_task + 1;
        task.total_attempts = task.total_attempts + 1;
    }

    public fun failed_attempt(task: &mut Task) {
        task.in_task = task.in_task - 1;
    }

    #[allow(lint(self_transfer))]
    public fun update(task: &mut Task, mut coin: Coin<SUI>, ctx: &mut TxContext) {
        // get reward and earned
        let reward = &mut task.reward;
        let earned = &mut task.earned;

        // check the coin value
        let amount = reward.value() / 2;
        assert!(coin.value() >= amount, ENotEnoughBalanceStart);

        let mut pay_coin = coin.split(amount, ctx);

        // deal with the remaining coin
        if (coin.value() > 0) {
            transfer::public_transfer(coin, ctx.sender());
        } else {
            coin.destroy_zero();
        };

        // update reward and earned
        let earned_amount = amount / 2;
        let earned_coin = pay_coin.split(earned_amount, ctx);
        earned.join(earned_coin.into_balance());
        reward.join(pay_coin.into_balance());
    }

    public fun as_seed(task: &Task): u64 {
        task.in_task + task.total_attempts
    }

    entry fun query_task(task_id: ID, task_list: &TaskList) {
        // check id
        assert!(task_list.tasks.contains(task_id), ENotCorrectTaskOrCompleted);

        // get task and emit event
        let task = &task_list.tasks[task_id];
        event::emit(QueryTaskEvent {
            task_id,
            in_task: task.in_task,
            total_attempts: task.total_attempts,
            cur_reward: task.reward.value(),
        });
    }

    public fun value(task: &Task): u64 {
        task.reward.value()
    }
}